package com.nexa.assistant

import android.annotation.SuppressLint
import android.content.Context
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import com.nexa.assistant.engine.ClipExpectation
import com.nexa.assistant.engine.ClipMetrics
import com.nexa.assistant.engine.ClipQuality
import com.nexa.assistant.engine.FilterBank
import com.nexa.assistant.engine.SpeakerCalibration
import com.nexa.assistant.engine.SpeakerProfile
import com.nexa.assistant.engine.SpeechSegmenter
import com.nexa.assistant.engine.WakePhraseModel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.concurrent.thread

/**
 * Guided voice setup: the owner's explicit consent, a protocol of recorded
 * prompts (wake phrase under many conditions, separate identity sentences,
 * negatives, background, consented guests), objective quality checks, and a
 * calibrated owner profile.
 *
 * Privacy rules enforced here:
 * - nothing records before [setConsent] with `accepted = true`;
 * - raw clips are written ONLY when the owner chose "keep recordings"; they
 *   stay in the app's own folder (USB-readable for offline training) and
 *   [deleteAll] removes them, the profile, its key and the consent;
 * - embeddings are held in memory until [finish] and then only inside the
 *   encrypted profile; nothing biometric is logged (counts and levels only).
 */
internal class VoiceSetup(
    private val context: Context,
    private val prefs: AssistantPrefs,
    private val store: VoiceProfileStore,
    private val micGranted: () -> Boolean,
    private val emit: (Map<String, Any?>) -> Unit,
    private val main: Handler,
) {
    private val sp = context.getSharedPreferences("nexa_voice_setup", Context.MODE_PRIVATE)
    private val root get() = File(context.getExternalFilesDir(null), "voice_setup")
    private val manifestFile get() = File(root, "manifest.json")

    private class Staged(val id: String, val speaker: String, val kind: String, val tags: List<String>, val embedding: FloatArray)

    private val staged = mutableListOf<Staged>()
    @Volatile private var busy = false
    private var embedder: OnnxSpeakerEmbedder? = null

    // ------------------------------------------------------------ consent

    val consented: Boolean get() = sp.getInt("consent_version", 0) >= CONSENT_VERSION
    private val keepClips: Boolean get() = sp.getBoolean("keep_clips", false)

    fun setConsent(accepted: Boolean, keepClips: Boolean): Map<String, Any?> {
        if (!accepted) return deleteAll()
        sp.edit()
            .putInt("consent_version", CONSENT_VERSION)
            .putLong("consent_at", System.currentTimeMillis())
            .putBoolean("keep_clips", keepClips)
            .apply()
        return status()
    }

    // ------------------------------------------------------------- status

    fun status(): Map<String, Any?> {
        val m = manifest()
        val counts = HashMap<String, Int>()
        for (i in 0 until m.length()) {
            val o = m.getJSONObject(i)
            val k = "${o.getString("speaker")}:${o.getString("kind")}"
            counts[k] = (counts[k] ?: 0) + 1
        }
        return mapOf(
            "consented" to consented,
            "consentVersion" to sp.getInt("consent_version", 0),
            "keepClips" to keepClips,
            "clips" to counts,
            "stagedEmbeddings" to staged.size,
            "calibration" to (sp.getString("calibration", null)?.let { JSONObject(it).toMap() }),
            "modelAvailable" to OnnxSpeakerEmbedder.available(context),
            "profileExists" to store.exists,
        )
    }

    fun begin() = WakeListenerService.pause(context, "enrollment")
    fun end() = WakeListenerService.resume(context)

    // ---------------------------------------------------------- recording

    /**
     * Records one prompt. [kind]: `wake`, `identity`, `negative`, `background`
     * (fixed length, no speech needed). [speaker]: `owner` or `guest_N`.
     */
    @SuppressLint("MissingPermission")
    fun record(
        kind: String,
        promptId: String,
        tags: List<String>,
        speaker: String,
        maxMs: Int,
        result: MethodChannel.Result,
    ) {
        if (!consented) return result.success(mapOf("ok" to false, "reason" to "consent_required"))
        if (!micGranted()) return result.success(mapOf("ok" to false, "reason" to "permission_denied"))
        if (busy) return result.success(mapOf("ok" to false, "reason" to "busy"))
        busy = true
        thread(name = "nexa-voice-setup") {
            val out = try {
                capture(kind, promptId, tags, speaker, maxMs)
            } catch (e: Exception) {
                mapOf("ok" to false, "reason" to "microphone_unavailable")
            }
            busy = false
            main.post { result.success(out) }
        }
    }

    @SuppressLint("MissingPermission")
    private fun capture(kind: String, promptId: String, tags: List<String>, speaker: String, maxMs: Int): Map<String, Any?> {
        val rate = FilterBank.SAMPLE_RATE
        val fixed = kind == "background"
        val limit = rate * (maxMs.coerceIn(1000, 65_000)) / 1000
        val all = FloatArray(limit)
        var filled = 0
        var endedAt = -1
        val seg = SpeechSegmenter(onSegment = { if (endedAt < 0) endedAt = filled })
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val rec = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(min, rate),
        )
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release(); return mapOf("ok" to false, "reason" to "microphone_unavailable")
        }
        val buf = ShortArray(rate / 10)
        val chunk = FloatArray(buf.size)
        try {
            rec.startRecording()
            emit(mapOf("type" to "recording", "active" to true))
            while (filled < limit) {
                val n = rec.read(buf, 0, minOf(buf.size, limit - filled))
                if (n <= 0) return mapOf("ok" to false, "reason" to "microphone_unavailable")
                for (i in 0 until n) { chunk[i] = buf[i] / 32768f; all[filled + i] = chunk[i] }
                filled += n
                if (!fixed) {
                    seg.accept(chunk, n)
                    // 0.5 s of room after the utterance, then stop.
                    if (endedAt >= 0 && filled - endedAt >= rate / 2) break
                }
            }
        } finally {
            runCatching { rec.stop() }
            rec.release()
            emit(mapOf("type" to "recording", "active" to false))
        }
        val samples = all.copyOf(filled)
        val metrics = ClipQuality.analyze(samples)
        if (!fixed) {
            ClipQuality.problem(metrics, expectation(kind, tags))?.let {
                return mapOf("ok" to false, "reason" to it, "metrics" to metricsMap(metrics))
            }
        }
        val clip = if (fixed) samples else ClipQuality.trim(samples, metrics)
        val id = "${speaker}_${kind}_${System.currentTimeMillis()}"
        var saved = false
        if (keepClips) {
            writeWav(File(root, "clips/$kind/$id.wav"), clip)
            addManifest(id, kind, promptId, tags, speaker, metrics)
            saved = true
        } else {
            addManifest(id, kind, promptId, tags, speaker, metrics, file = false)
        }
        var embedded = false
        if (kind == "wake" || kind == "identity") {
            embedder().let { e ->
                val v = e?.embed(ClipQuality.normalizeLevel(clip))
                if (v != null) { staged += Staged(id, speaker, kind, tags, v); embedded = true }
            }
        }
        return mapOf(
            "ok" to true, "id" to id, "saved" to saved, "embedded" to embedded,
            "metrics" to metricsMap(metrics), "status" to status(),
        )
    }

    private fun expectation(kind: String, tags: List<String>): ClipExpectation {
        var e = when (kind) {
            "identity" -> ClipExpectation(minSpeechMs = 1200, maxSpeechMs = 7000)
            "negative" -> ClipExpectation(minSpeechMs = 250, maxSpeechMs = 5000)
            else -> ClipExpectation()
        }
        if ("quiet" in tags || "far" in tags) e = e.copy(minPeakDb = -50f, minSnrDb = 6f)
        if ("noise" in tags) e = e.copy(minPeakDb = -45f, minSnrDb = 0f)
        if ("slow" in tags) e = e.copy(maxSpeechMs = 7000)
        return e
    }

    private fun embedder(): OnnxSpeakerEmbedder? {
        if (embedder == null) embedder = OnnxSpeakerEmbedder.load(context)
        return embedder
    }

    // ------------------------------------------------------------- finish

    /**
     * Builds the owner profile from identity + wake takes and calibrates the
     * threshold (with guests when present). Needs enough variety: refuses a
     * profile built from the wake phrase alone or from few conditions.
     */
    fun finish(result: MethodChannel.Result) {
        if (!consented) return result.success(mapOf("ok" to false, "reason" to "consent_required"))
        if (busy) return result.success(mapOf("ok" to false, "reason" to "busy"))
        busy = true
        thread(name = "nexa-voice-setup-finish") {
            val out = try { build() } catch (e: Exception) { mapOf("ok" to false, "reason" to "save_failed") }
            busy = false
            main.post { WakeListenerService.reload(context); result.success(out) }
        }
    }

    private fun build(): Map<String, Any?> {
        if (staged.isEmpty() && keepClips) rebuildFromClips()
        val owner = staged.filter { it.speaker == "owner" }
        val identity = owner.count { it.kind == "identity" }
        val conditions = owner.flatMap { it.tags }.toSet().size
        if (owner.size < MIN_OWNER_TAKES) return reasonMap("too_few_samples", owner.size)
        if (identity < MIN_IDENTITY) return reasonMap("too_few_identity_sentences", identity)
        if (conditions < MIN_CONDITIONS) return reasonMap("too_few_conditions", conditions)
        val guests = staged.filter { it.speaker.startsWith("guest") }
        val cal = SpeakerCalibration.calibrate(owner.map { it.embedding }, guests.map { it.embedding })
        val embeddings = owner.map { it.embedding }.takeLast(MAX_STORED)
        val profile = SpeakerProfile.fromEmbeddings(embeddings)
        val speaker = SpeakerProfile(profile.embedding, cal.threshold, embeddings)
        val phrase = store.load()?.phrase ?: WakePhraseModel(emptyList(), 0.3f)
        store.save(VoiceProfile(phrase, speaker, System.currentTimeMillis()))
        // Scores and counts only; never embeddings.
        val summary = JSONObject()
            .put("mode", cal.mode).put("threshold", cal.threshold.toDouble())
            .put("ownerP05", cal.ownerP05.toDouble()).put("ownerMedian", cal.ownerMedian.toDouble())
            .put("impostorMax", cal.impostorMax?.toDouble() ?: JSONObject.NULL)
            .put("separable", cal.separable)
            .put("ownerSamples", cal.ownerSamples).put("impostorSamples", cal.impostorSamples)
            .put("identitySamples", identity).put("conditions", conditions)
            .put("at", System.currentTimeMillis())
        sp.edit().putString("calibration", summary.toString()).apply()
        android.util.Log.i(
            "NexaWake",
            "voice setup: owner=${owner.size} identity=$identity guests=${guests.size} mode=${cal.mode} separable=${cal.separable}",
        )
        return mapOf("ok" to true) + summary.toMap()
    }

    private fun rebuildFromClips() {
        val m = manifest()
        val e = embedder() ?: return
        for (i in 0 until m.length()) {
            val o = m.getJSONObject(i)
            val kind = o.getString("kind")
            if (kind != "wake" && kind != "identity") continue
            val f = File(root, "clips/$kind/${o.getString("id")}.wav")
            if (!f.exists()) continue
            val v = e.embed(ClipQuality.normalizeLevel(readWav(f))) ?: continue
            val tags = o.getJSONArray("tags").let { a -> List(a.length()) { a.getString(it) } }
            staged += Staged(o.getString("id"), o.getString("speaker"), kind, tags, v)
        }
    }

    private fun reasonMap(reason: String, have: Int) = mapOf("ok" to false, "reason" to reason, "have" to have)

    // ----------------------------------------------------------- deletion

    /** Revokes consent and removes every recording, the profile, its key and the calibration. */
    fun deleteAll(): Map<String, Any?> {
        staged.clear()
        embedder?.close(); embedder = null
        root.deleteRecursively()
        store.delete()
        sp.edit().clear().apply()
        prefs.requireOwner = false
        WakeListenerService.reload(context)
        return status()
    }

    // ---------------------------------------------------------- manifest

    private fun manifest(): JSONArray = try {
        if (manifestFile.exists()) JSONArray(manifestFile.readText()) else JSONArray()
    } catch (e: Exception) { JSONArray() }

    private fun addManifest(id: String, kind: String, promptId: String, tags: List<String>, speaker: String, m: ClipMetrics, file: Boolean = true) {
        val a = manifest()
        a.put(
            JSONObject().put("id", id).put("kind", kind).put("prompt", promptId)
                .put("tags", JSONArray(tags)).put("speaker", speaker).put("file", file)
                .put("createdAt", System.currentTimeMillis()).put("consent", CONSENT_VERSION)
                .put("durationMs", m.durationMs).put("peakDb", m.peakDb.toDouble())
                .put("speechRmsDb", m.speechRmsDb.toDouble()).put("noiseDb", m.noiseDb.toDouble())
                .put("snrDb", m.snrDb.toDouble()),
        )
        root.mkdirs()
        manifestFile.writeText(a.toString())
    }

    private fun metricsMap(m: ClipMetrics) = mapOf(
        "durationMs" to m.durationMs, "speechMs" to m.speechMs,
        "peakDb" to m.peakDb.toDouble(), "speechRmsDb" to m.speechRmsDb.toDouble(),
        "noiseDb" to m.noiseDb.toDouble(), "snrDb" to m.snrDb.toDouble(),
    )

    private fun JSONObject.toMap(): Map<String, Any?> =
        keys().asSequence().associateWith { k -> opt(k).let { if (it == JSONObject.NULL) null else it } }

    // --------------------------------------------------------------- wav

    private fun writeWav(f: File, samples: FloatArray) {
        f.parentFile?.mkdirs()
        val data = ByteBuffer.allocate(samples.size * 2).order(ByteOrder.LITTLE_ENDIAN)
        for (s in samples) data.putShort((s.coerceIn(-1f, 1f) * 32767).toInt().toShort())
        val h = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
        h.put("RIFF".toByteArray()).putInt(36 + data.capacity()).put("WAVE".toByteArray())
        h.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1).putInt(16000).putInt(32000).putShort(2).putShort(16)
        h.put("data".toByteArray()).putInt(data.capacity())
        f.outputStream().use { it.write(h.array()); it.write(data.array()) }
    }

    private fun readWav(f: File): FloatArray {
        val b = f.readBytes()
        val n = (b.size - 44) / 2
        val bb = ByteBuffer.wrap(b, 44, b.size - 44).order(ByteOrder.LITTLE_ENDIAN)
        return FloatArray(n) { bb.short / 32768f }
    }

    companion object {
        const val CONSENT_VERSION = 1
        const val MIN_OWNER_TAKES = 24
        const val MIN_IDENTITY = 8
        const val MIN_CONDITIONS = 4
        const val MAX_STORED = 64
    }
}
