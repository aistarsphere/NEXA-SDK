package com.nexa.assistant

import com.nexa.assistant.engine.FilterBank
import com.nexa.assistant.engine.SampleQuality
import com.nexa.assistant.engine.Sensitivity
import com.nexa.assistant.engine.SpeakerProfile
import com.nexa.assistant.engine.SpeechSegmenter
import com.nexa.assistant.engine.WakeDecision
import com.nexa.assistant.engine.WakeEngine
import com.nexa.assistant.engine.WakePhraseModel
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.max
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Local wake pipeline on synthetic test speech (see fixtures/README.md). */
class WakeEngineTest {
    private fun wav(name: String): FloatArray {
        val bytes = javaClass.getResourceAsStream("/fixtures/$name.wav")!!.readBytes()
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        var pos = 12
        while (pos + 8 <= bytes.size) {
            val id = String(bytes, pos, 4)
            val size = buf.getInt(pos + 4)
            if (id == "data") {
                return FloatArray(size / 2) { buf.getShort(pos + 8 + it * 2) / 32768f }
            }
            pos += 8 + size + (size and 1)
        }
        error("no data chunk in $name")
    }

    /** Quiet room noise around the clip, as a microphone would deliver it. */
    private fun inRoom(clip: FloatArray, seed: Int = 1): FloatArray {
        val r = Random(seed)
        val pad = 16000
        return FloatArray(clip.size + 2 * pad) { i ->
            val noise = (r.nextFloat() - 0.5f) * 0.002f
            noise + if (i in pad until pad + clip.size) clip[i - pad] else 0f
        }
    }

    private fun segments(audio: FloatArray): List<FloatArray> {
        val out = ArrayList<FloatArray>()
        val s = SpeechSegmenter(onSegment = { out += it })
        // Feed in microphone-sized reads.
        var i = 0
        while (i < audio.size) {
            val n = minOf(1024, audio.size - i)
            s.accept(audio.copyOfRange(i, i + n))
            i += n
        }
        return out
    }

    private val bank = FilterBank()
    private fun features(name: String) = bank.phraseFeatures(segments(inRoom(wav(name))).single())

    private val enrolled by lazy { (1..4).map { features("enroll_$it") } }
    private val model by lazy { WakePhraseModel.fromSamples(enrolled) }

    @Test
    fun `filterbank matches kaldi-native-fbank`() {
        val ref = javaClass.getResourceAsStream("/fixtures/enroll_1_fbank.txt")!!
            .bufferedReader().readLines().map { l -> l.trim().split(" ").map(String::toFloat) }
        val ours = bank.compute(wav("enroll_1"))
        assertEquals(ref.size, ours.size)
        var worst = 0f
        for (t in ref.indices) for (b in 0 until 80) {
            worst = max(worst, abs(ref[t][b] - ours[t][b]))
        }
        println("filterbank max abs difference: $worst")
        assertTrue(worst < 2e-3f, "max diff $worst")
    }

    @Test
    fun `segmenter finds one utterance and ignores room noise`() {
        assertEquals(1, segments(inRoom(wav("pos_1"))).size)
        assertEquals(0, segments(inRoom(FloatArray(48000))).size)
    }

    @Test
    fun `wake phrase accepted, other phrases and voices rejected`() {
        println("threshold ${model.threshold}")
        for (i in enrolled.indices) for (j in i + 1 until enrolled.size) {
            println("enrol $i-$j distance %.3f".format(WakePhraseModel.dtw(enrolled[i], enrolled[j])))
        }
        val positives = listOf("pos_1", "pos_2")
        val negatives = listOf(
            "neg_habibi", "neg_salam", "neg_tabib", "neg_tabib_noisy", "neg_weather",
            "other_samantha", "other_daniel", "other_karen",
        )
        for (n in positives + negatives) {
            println("%-16s distance %.3f".format(n, model.distance(features(n))))
        }
        for (n in positives) assertTrue(model.matches(features(n), Sensitivity.NORMAL), n)
        for (n in negatives) assertFalse(model.matches(features(n), Sensitivity.NORMAL), n)
    }

    private fun engine(
        requireOwner: Boolean,
        embedding: FloatArray?,
        now: () -> Long = { 0L },
        out: MutableList<WakeDecision>,
    ) = WakeEngine(
        model = model,
        speaker = SpeakerProfile(floatArrayOf(1f, 0f, 0f), 0.6f),
        embedder = { embedding },
        requireOwner = requireOwner,
        clock = now,
        onDecision = { out += it },
    )

    @Test
    fun `owner check gates activation`() {
        val out = ArrayList<WakeDecision>()
        val clip = segments(inRoom(wav("pos_1"))).single()
        val owner = engine(true, floatArrayOf(0.9f, 0.1f, 0f), out = out)
        assertTrue(owner.decide(clip).accepted)
        val stranger = engine(true, floatArrayOf(0.1f, 0.9f, 0f), out = out)
        val d = stranger.decide(clip)
        assertFalse(d.accepted)
        assertEquals("speaker_mismatch", d.reason)
        val noModel = engine(true, null, out = out)
        assertEquals("speaker_unavailable", noModel.decide(clip).reason)
    }

    @Test
    fun `refractory period and replayed audio are rejected`() {
        var now = 0L
        val out = ArrayList<WakeDecision>()
        val e = engine(false, null, { now }, out)
        val clip = segments(inRoom(wav("pos_1"))).single()
        assertTrue(e.decide(clip).accepted)
        now = 1000
        assertEquals("refractory", e.decide(clip).reason)
        now = 10_000
        assertEquals("replay_suspected", e.decide(clip).reason)
        val other = segments(inRoom(wav("pos_2"))).single()
        assertTrue(e.decide(other).accepted)
    }

    @Test
    fun `streaming audio produces a decision per utterance`() {
        val out = ArrayList<WakeDecision>()
        var t = 0L
        val e = engine(false, null, { t += 5000; t }, out)
        val stream = inRoom(wav("neg_salam"), 2) + inRoom(wav("pos_2"), 3)
        var i = 0
        while (i < stream.size) {
            val n = minOf(640, stream.size - i)
            e.accept(stream.copyOfRange(i, i + n))
            i += n
        }
        assertEquals(listOf(false, true), out.map { it.accepted })
    }

    @Test
    fun `speaker threshold calibrates from enrolment`() {
        val a = floatArrayOf(1f, 0.1f, 0f)
        val b = floatArrayOf(0.95f, 0.2f, 0.05f)
        val c = floatArrayOf(0.9f, 0f, 0.1f)
        val p = SpeakerProfile.fromEmbeddings(listOf(a, b, c))
        assertTrue(p.threshold in 0.40f..0.65f)
        assertTrue(p.score(a) > p.threshold)
        assertTrue(p.score(floatArrayOf(0f, 1f, 0f)) < p.threshold)
    }

    @Test
    fun `owner variation close to some samples passes, stranger does not`() {
        // Owner samples spread across two "registers" (e.g. calm / loud).
        val owner = listOf(
            floatArrayOf(1f, 0.3f, 0f, 0f),
            floatArrayOf(0.95f, 0.35f, 0.05f, 0f),
            floatArrayOf(0.6f, 0.8f, 0f, 0f),
            floatArrayOf(0.55f, 0.85f, 0.05f, 0f),
            floatArrayOf(0.8f, 0.55f, 0f, 0.05f),
        )
        val p = SpeakerProfile.fromEmbeddings(owner)
        // Same person in the second register: near two samples, further
        // from the mean.
        val loudOwner = floatArrayOf(0.5f, 0.88f, 0.02f, 0f)
        assertTrue(p.score(loudOwner) >= p.threshold, "owner ${p.score(loudOwner)} vs ${p.threshold}")
        val stranger = floatArrayOf(0.1f, 0.1f, 1f, 0.6f)
        assertTrue(p.score(stranger) < p.threshold, "stranger ${p.score(stranger)}")
        assertTrue(p.threshold >= 0.40f, "never lowered below the floor")
    }

    @Test
    fun `enrolment sample quality`() {
        assertNull(SampleQuality.problem(segments(inRoom(wav("pos_1"))).single()))
        assertEquals("no_speech", SampleQuality.problem(null))
        assertEquals("too_short", SampleQuality.problem(FloatArray(3000) { 0.3f }))
        assertEquals("too_quiet", SampleQuality.problem(FloatArray(16000) { 0.001f }))
        assertNotNull(SampleQuality.problem(FloatArray(16000) { 1f }))
    }
}
