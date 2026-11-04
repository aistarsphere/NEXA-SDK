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
import com.nexa.assistant.engine.EnergyVad
import com.nexa.assistant.engine.RecorderConfig
import com.nexa.assistant.engine.RecorderEvent
import com.nexa.assistant.engine.SpeechProbability
import com.nexa.assistant.engine.Take
import com.nexa.assistant.engine.TakeMetrics
import com.nexa.assistant.engine.UtteranceRecorder
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

    fun begin() {
        WakeListenerService.pause(context, "enrollment")
        // Takes are held in memory only (nothing biometric is written unless
        // the person chose to keep recordings). If the app restarted since,
        // those takes are gone: start the counts again instead of showing
        // progress that cannot be built into a profile.
        if (staged.isEmpty() && !keepClips && manifest().length() > 0) {
            manifestFile.delete()
        }
    }
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

    private val cancelFlag = java.util.concurrent.atomic.AtomicBoolean(false)

    /** Stops the recording in progress (the person pressed stop, or left the screen). */
    fun cancel() = cancelFlag.set(true)

    private fun status(stage: String, extra: Map<String, Any?> = emptyMap()) =
        emit(mapOf("type" to "setup", "stage" to stage) + extra)

    @SuppressLint("MissingPermission")
    private fun capture(kind: String, promptId: String, tags: List<String>, speaker: String, maxMs: Int): Map<String, Any?> {
        if (kind == "background") return captureFixed(kind, promptId, tags, speaker, maxMs)
        cancelFlag.set(false)
        val rate = FilterBank.SAMPLE_RATE
        val cfg = when (kind) {
            "identity" -> RecorderConfig.SENTENCE
            "negative" -> RecorderConfig.NEGATIVE
            else -> RecorderConfig.WAKE
        }
        val neural = SileroVad.load(context)
        val vad: SpeechProbability = neural ?: EnergyVad()
        var outcome: RecorderEvent? = null
        val t0 = System.currentTimeMillis()
        var frameNo = 0
        val probs = StringBuilder()
        val recorder = UtteranceRecorder(vad, cfg) { e ->
            when (e) {
                is RecorderEvent.Ready -> status("ready")
                is RecorderEvent.Level -> if (frameNo % 3 == 0) status("level", mapOf("db" to e.db.toDouble(), "speaking" to e.speaking))
                is RecorderEvent.SpeechStarted -> {
                    android.util.Log.i("NexaSetupTrace", "speech_start t=${System.currentTimeMillis() - t0}")
                    status("speech")
                }
                is RecorderEvent.SpeechEnded -> {
                    android.util.Log.i("NexaSetupTrace", "speech_end t=${System.currentTimeMillis() - t0} speech_ms=${e.speechMs}")
                    status("processing")
                }
                is RecorderEvent.Captured, is RecorderEvent.Rejected -> outcome = e
            }
        }
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val rec = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(min, rate),
        )
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release(); neural?.close()
            return mapOf("ok" to false, "reason" to "microphone_unavailable")
        }
        val shorts = ShortArray(UtteranceRecorder.FRAME)
        val frame = FloatArray(UtteranceRecorder.FRAME)
        try {
            rec.startRecording()
            android.util.Log.i("NexaSetupTrace", "mic_open kind=$kind vad=${if (neural != null) "silero" else "energy"}")
            emit(mapOf("type" to "recording", "active" to true))
            status("opening")
            outer@ while (!recorder.done) {
                var got = 0
                while (got < shorts.size) {
                    if (cancelFlag.get()) { recorder.cancel("interrupted"); break@outer }
                    val n = rec.read(shorts, got, shorts.size - got)
                    if (n <= 0) { recorder.cancel("interrupted"); break@outer }
                    got += n
                }
                for (i in shorts.indices) frame[i] = shorts[i] / 32768f
                frameNo++
                recorder.feed(frame)
                if (frameNo <= 60) probs.append("%.2f ".format(java.util.Locale.ROOT, recorder.lastProbability))
            }
        } finally {
            runCatching { rec.stop() }
            rec.release()
            neural?.close()
            emit(mapOf("type" to "recording", "active" to false))
            android.util.Log.i("NexaSetupTrace", "vad_probabilities_first_60_frames: $probs")
        }
        val openMs = (System.currentTimeMillis() - t0).toInt()
        return when (val o = outcome) {
            is RecorderEvent.Rejected -> {
                android.util.Log.i("NexaSetupTrace", "rejected reason=${o.reason} open_ms=$openMs speech_ms=${o.speechMs}")
                mapOf("ok" to false, "reason" to o.reason, "speechMs" to o.speechMs, "openMs" to openMs)
            }
            is RecorderEvent.Captured -> finishTake(kind, promptId, tags, speaker, o.take, openMs)
            else -> mapOf("ok" to false, "reason" to "interrupted", "openMs" to openMs)
        }
    }

    private fun finishTake(kind: String, promptId: String, tags: List<String>, speaker: String, take: Take, openMs: Int): Map<String, Any?> {
        val metrics = TakeMetrics.of(take)
        android.util.Log.i(
            "NexaSetupTrace",
            "closed open_ms=$openMs take_ms=${metrics.durationMs} speech_ms=${take.speechMs} peak_db=%.1f noise_db=%.1f snr_db=%.1f"
                .format(java.util.Locale.ROOT, metrics.peakDb, metrics.noiseDb, metrics.snrDb),
        )
        TakeMetrics.problem(metrics, expectation(kind, tags))?.let {
            android.util.Log.i("NexaSetupTrace", "rejected reason=$it")
            return mapOf("ok" to false, "reason" to it, "metrics" to metricsMap(metrics), "speechMs" to take.speechMs, "openMs" to openMs)
        }
        val clip = take.samples
        val id = "${speaker}_${kind}_${System.currentTimeMillis()}"
        var saved = false
        if (keepClips) {
            writeWav(File(root, "clips/$kind/$id.wav"), clip)
            saved = true
        }
        addManifest(id, kind, promptId, tags, speaker, metrics, file = saved)
        // The speaker model needs enough speech: a sentence always has it; the
        // short wake phrase only when it was said long enough to be reliable.
        var embedded = false
        if ((kind == "identity" && take.speechMs >= 1000) || (kind == "wake" && take.speechMs >= 600)) {
            val t = System.nanoTime()
            embedder()?.embed(ClipQuality.normalizeLevel(clip))?.let {
                staged += Staged(id, speaker, kind, tags, it)
                embedded = true
                android.util.Log.i("NexaSetupTrace", "embed_ms=${(System.nanoTime() - t) / 1_000_000} speech_ms=${take.speechMs}")
            }
        }
        return mapOf(
            "ok" to true, "id" to id, "saved" to saved, "embedded" to embedded,
            "speechMs" to take.speechMs, "openMs" to openMs,
            "metrics" to metricsMap(metrics), "status" to status(),
        )
    }

    /** Background sound: a fixed length, no speech needed. */
    @SuppressLint("MissingPermission")
    private fun captureFixed(kind: String, promptId: String, tags: List<String>, speaker: String, maxMs: Int): Map<String, Any?> {
        cancelFlag.set(false)
        val rate = FilterBank.SAMPLE_RATE
        val limit = rate * maxMs.coerceIn(1000, 65_000) / 1000
        val all = FloatArray(limit)
        var filled = 0
        val min = AudioRecord.getMinBufferSize(rate, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        val rec = AudioRecord(
            MediaRecorder.AudioSource.VOICE_RECOGNITION, rate,
            AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, maxOf(min, rate),
        )
        if (rec.state != AudioRecord.STATE_INITIALIZED) {
            rec.release(); return mapOf("ok" to false, "reason" to "microphone_unavailable")
        }
        val buf = ShortArray(rate / 10)
        try {
            rec.startRecording()
            emit(mapOf("type" to "recording", "active" to true))
            status("ready")
            while (filled < limit && !cancelFlag.get()) {
                val n = rec.read(buf, 0, minOf(buf.size, limit - filled))
                if (n <= 0) return mapOf("ok" to false, "reason" to "interrupted")
                for (i in 0 until n) all[filled + i] = buf[i] / 32768f
                filled += n
                if ((filled / buf.size) % 3 == 0) status("level", mapOf("db" to ClipQuality.db(kotlin.math.abs(all[filled - 1])).toDouble(), "speaking" to false))
            }
        } finally {
            runCatching { rec.stop() }
            rec.release()
            emit(mapOf("type" to "recording", "active" to false))
        }
        if (cancelFlag.get()) return mapOf("ok" to false, "reason" to "interrupted")
        val samples = all.copyOf(filled)
        val metrics = ClipQuality.analyze(samples)
        val id = "${speaker}_${kind}_${System.currentTimeMillis()}"
        var saved = false
        if (keepClips) { writeWav(File(root, "clips/$kind/$id.wav"), samples); saved = true }
        addManifest(id, kind, promptId, tags, speaker, metrics, file = saved)
        return mapOf("ok" to true, "id" to id, "saved" to saved, "embedded" to false, "metrics" to metricsMap(metrics), "status" to status())
    }

    /** Level and noise limits only; speech length is decided by the recorder. */
    private fun expectation(kind: String, tags: List<String>): ClipExpectation {
        var e = ClipExpectation()
        if ("quiet" in tags || "far" in tags) e = e.copy(minPeakDb = -50f, minSnrDb = 6f)
        if ("noise" in tags) e = e.copy(minPeakDb = -45f, minSnrDb = 0f)
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
    fun finish(quick: Boolean, result: MethodChannel.Result) {
        if (!consented) return result.success(mapOf("ok" to false, "reason" to "consent_required"))
        if (busy) return result.success(mapOf("ok" to false, "reason" to "busy"))
        busy = true
        thread(name = "nexa-voice-setup-finish") {
            val out = try {
                build(quick)
            } catch (e: Exception) {
                // The kind of failure only (never data): so "save_failed" can be diagnosed.
                android.util.Log.w("NexaSetupTrace", "build failed: ${e.javaClass.simpleName} at ${e.stackTrace.firstOrNull()}")
                mapOf("ok" to false, "reason" to "save_failed")
            }
            busy = false
            main.post { WakeListenerService.reload(context); result.success(out) }
        }
    }

    private fun build(quick: Boolean): Map<String, Any?> {
        if (staged.isEmpty() && keepClips) rebuildFromClips()
        if (staged.isEmpty()) return reasonMap("recordings_lost", 0)
        val owner = staged.filter { it.speaker == "owner" }
        val identity = owner.count { it.kind == "identity" }
        val conditions = owner.flatMap { it.tags }.toSet().size
        // Quick setup (about 2 minutes) asks for less; its profile is labelled
        // by how few takes backed it, and the full protocol remains for testing.
        val minTakes = if (quick) QUICK_TAKES else MIN_OWNER_TAKES
        val minIdentity = if (quick) QUICK_IDENTITY else MIN_IDENTITY
        val minConditions = if (quick) QUICK_CONDITIONS else MIN_CONDITIONS
        if (owner.size < minTakes) return reasonMap("too_few_samples", owner.size)
        if (identity < minIdentity) return reasonMap("too_few_identity_sentences", identity)
        if (conditions < minConditions) return reasonMap("too_few_conditions", conditions)
        val guests = staged.filter { it.speaker.startsWith("guest") }
        val (kept, dropped) = SpeakerCalibration.trimOutliers(owner.map { it.embedding })
        val cal = SpeakerCalibration.calibrate(kept, guests.map { it.embedding })
        // Enrolment quality is separate from accuracy: if the takes do not
        // agree with each other, ask for more (clean) sentences instead of
        // building a profile that will reject the owner.
        if (cal.ownerMedian < SpeakerCalibration.MIN_CONSISTENCY_MEDIAN) {
            return reasonMap("low_consistency", owner.size) + mapOf("ownerMedian" to cal.ownerMedian.toDouble())
        }
        val embeddings = kept.takeLast(MAX_STORED)
        val profile = SpeakerProfile.fromEmbeddings(embeddings)
        val speaker = SpeakerProfile(profile.embedding, cal.threshold, embeddings)
        val phrase = store.load()?.phrase // keeps an older template if one exists; neural phrases need none
        store.save(VoiceProfile(phrase, speaker, System.currentTimeMillis()))
        // Scores and counts only; never embeddings.
        val summary = JSONObject()
            .put("mode", cal.mode).put("threshold", cal.threshold.toDouble())
            .put("ownerP05", cal.ownerP05.toDouble()).put("ownerMedian", cal.ownerMedian.toDouble())
            .put("impostorMax", cal.impostorMax?.toDouble() ?: JSONObject.NULL)
            .put("separable", cal.separable)
            .put("ownerSamples", cal.ownerSamples).put("impostorSamples", cal.impostorSamples)
            .put("identitySamples", identity).put("conditions", conditions).put("quick", quick)
            .put("dropped", dropped)
            // Provisional until strangers were measured: a profile that only knows the owner has an unmeasured false-accept rate.
            .put("quality", if (cal.mode == "with_guests" && cal.separable && cal.impostorSamples >= 20) "measured" else "provisional")
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
        const val QUICK_TAKES = 12
        const val QUICK_IDENTITY = 4
        const val QUICK_CONDITIONS = 3
        const val MAX_STORED = 64
    }
}
