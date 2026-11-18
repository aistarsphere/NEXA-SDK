package com.nexa.assistant

import com.nexa.assistant.engine.EmbeddingWakeDetector
import com.nexa.assistant.engine.NeuralWakeEngine
import com.nexa.assistant.engine.Sensitivity
import com.nexa.assistant.engine.SpeakerEmbedder
import com.nexa.assistant.engine.SpeakerProfile
import com.nexa.assistant.engine.WakeDecision
import com.nexa.assistant.engine.WakeFeatures
import com.nexa.assistant.engine.WakeHead
import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** The trained-acoustic-model path, with the two feature models faked. */
class NeuralWakeTest {
    /** Parity with the Python export (tools/wake_training/train.py). */
    @Test
    fun headScoreMatchesPython() {
        val bytes = javaClass.getResourceAsStream("/fixtures/head_tiny.bin")!!.readBytes()
        val head = WakeHead.parse(bytes)
        assertEquals(4, head.nIn)
        val s = head.score(floatArrayOf(1.0f, 0.0f, 0.4f, 3.0f))
        assertTrue(abs(s - 0.4950002f) < 1e-5f, "score $s")
    }

    @Test
    fun rejectsAFileThatIsNotAHead() {
        val bad = ByteArray(40) { 7 }
        kotlin.runCatching { WakeHead.parse(bad) }.let { assertTrue(it.isFailure) }
    }

    /** The head fires when the newest embedding's first value is high. */
    private fun head(): WakeHead {
        val n = WakeHead.WINDOW * WakeHead.EMBEDDING
        val w1 = FloatArray(n * 1)
        w1[(WakeHead.WINDOW - 1) * WakeHead.EMBEDDING] = 1f // hidden0 = newest embedding[0]
        return WakeHead(
            FloatArray(n), FloatArray(n) { 1f }, w1, floatArrayOf(0f), floatArrayOf(10f), -5f,
        )
    }

    private class Fake(var speech: Boolean = false) : WakeFeatures {
        override fun mel(samples: FloatArray) = Array(8) { FloatArray(32) }
        override fun embed(frames: Array<FloatArray>) =
            FloatArray(96).also { it[0] = if (speech) 1f else 0f }
    }

    private fun chunk() = FloatArray(EmbeddingWakeDetector.CHUNK) { 0.01f }

    private class Clock(var now: Long = 0) : () -> Long {
        override fun invoke() = now
    }

    private fun run(f: Fake, d: EmbeddingWakeDetector, chunks: Int) =
        repeat(chunks) { d.accept(chunk()) }

    @Test
    fun wakesOnlyAfterTheRequiredConsecutiveWindows() {
        val f = Fake()
        val wakes = mutableListOf<Float>()
        val d = EmbeddingWakeDetector(f, head(), 0.9f, hits = 2, onWake = { s, _ -> wakes += s })
        run(f, d, 90) // warm-up: silence
        f.speech = true
        run(f, d, 1)
        assertTrue(wakes.isEmpty(), "one loud window is not a wake")
        f.speech = false
        run(f, d, 1)
        f.speech = true
        run(f, d, 1)
        assertTrue(wakes.isEmpty(), "the run restarts after a quiet window")
        run(f, d, 1)
        assertEquals(1, wakes.size)
    }

    @Test
    fun refractoryStopsRepeatedWakesAndAudioStaysBounded() {
        val f = Fake()
        val clock = Clock()
        var tailSize = 0
        val wakes = mutableListOf<Float>()
        val d = EmbeddingWakeDetector(f, head(), 0.9f, hits = 2, refractoryMs = 3000, clock = clock,
            onWake = { s, tail -> wakes += s; tailSize = tail.size })
        run(f, d, 120)
        f.speech = true
        run(f, d, 6)
        assertEquals(1, wakes.size, "held phrase wakes once")
        assertTrue(tailSize <= EmbeddingWakeDetector.TAIL_SECONDS * EmbeddingWakeDetector.SAMPLE_RATE)
        clock.now += 4000
        run(f, d, 4)
        assertEquals(2, wakes.size, "after the pause it can wake again")
    }

    private fun engine(
        requireOwner: Boolean,
        speaker: SpeakerProfile?,
        embedder: SpeakerEmbedder?,
        f: Fake,
        out: MutableList<WakeDecision>,
    ) = NeuralWakeEngine(
        f, head(), 0.9f, 2, speaker, embedder, requireOwner, Sensitivity.NORMAL, onDecision = { out += it },
    )

    private fun feedWake(e: NeuralWakeEngine, f: Fake) {
        repeat(90) { e.accept(chunk()) }
        f.speech = true
        repeat(3) { e.accept(chunk()) }
    }

    @Test
    fun withoutOwnerCheckTheWakeIsAccepted() {
        val f = Fake()
        val out = mutableListOf<WakeDecision>()
        feedWake(engine(false, null, null, f, out), f)
        assertEquals(listOf("accepted"), out.map { it.reason })
    }

    @Test
    fun ownerCheckRejectsAStrangerAndAcceptsTheOwner() {
        val owner = floatArrayOf(1f, 0f, 0f)
        val profile = SpeakerProfile(owner, 0.6f)
        for ((voice, expected) in listOf(
            floatArrayOf(0.9f, 0.1f, 0f) to "accepted",
            floatArrayOf(0f, 1f, 0f) to "speaker_mismatch",
        )) {
            val f = Fake()
            val out = mutableListOf<WakeDecision>()
            feedWake(engine(true, profile, { voice }, f, out), f)
            assertEquals(listOf(expected), out.map { it.reason })
        }
    }

    @Test
    fun anUncertainVoiceIsNeitherAcceptedNorFlatlyRejected() {
        // Threshold 0.8: a 0.74 voice is uncertain (manual path), a 0.2 voice is a mismatch.
        val profile = SpeakerProfile(floatArrayOf(1f, 0f), 0.8f)
        val cases = listOf(
            floatArrayOf(0.74f, 0.67f) to "speaker_uncertain", // cos about 0.74
            floatArrayOf(0.2f, 0.98f) to "speaker_mismatch",
        )
        for ((voice, expected) in cases) {
            val f = Fake()
            val out = mutableListOf<WakeDecision>()
            feedWake(engine(true, profile, { voice }, f, out), f)
            assertEquals(listOf(expected), out.map { it.reason })
            assertFalse(out.single().accepted)
        }
    }

    @Test
    fun ownerCheckFailsClosedWithoutAProfileOrModel() {
        val f = Fake()
        val out = mutableListOf<WakeDecision>()
        feedWake(engine(true, null, null, f, out), f)
        assertEquals(listOf("speaker_unavailable"), out.map { it.reason })
        assertFalse(out.single().accepted)
    }

    /**
     * Defect REL-03 (docs/mobile/ENGINEERING_QA_REPORT_2026-11-18.md): neither the
     * detector nor the engine contains a model error, and WakeListenerService.loop()
     * has no try/catch either, so one failed inference ends the app process.
     * This pins the current behaviour: whoever drives the engine must catch.
     */
    @Test
    fun aModelErrorIsNotContainedByTheEngine() {
        val broken = object : WakeFeatures {
            override fun mel(samples: FloatArray): Array<FloatArray> = error("model failed")
            override fun embed(frames: Array<FloatArray>) = FloatArray(96)
        }
        val e = NeuralWakeEngine(
            broken, head(), 0.9f, 2, null, null, false, Sensitivity.NORMAL, onDecision = {},
        )
        val thrown = kotlin.runCatching { repeat(4) { e.accept(chunk()) } }.exceptionOrNull()
        assertTrue(thrown is IllegalStateException, "got $thrown")
    }

    @Test
    fun speechTailStartsWhereSpeechStarts() {
        val tail = FloatArray(16000) + FloatArray(8000) { 0.3f } // 1 s silence, 0.5 s speech
        val seg = NeuralWakeEngine.speechTail(tail)
        assertTrue(seg.size in 8000..8400, "size ${seg.size}")
    }
}
