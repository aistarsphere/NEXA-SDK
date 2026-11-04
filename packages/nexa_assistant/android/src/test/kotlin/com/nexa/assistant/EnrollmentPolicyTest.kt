package com.nexa.assistant

import com.nexa.assistant.engine.ClipMetrics
import com.nexa.assistant.engine.EnrollmentPolicy
import com.nexa.assistant.engine.EnrollmentPolicy.Verdict
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Adaptive progression of the quick setup on synthetic embeddings. */
class EnrollmentPolicyTest {
    private val rnd = Random(11)
    private fun centre(seed: Int) = FloatArray(64) { Random(seed * 1000 + it).nextFloat() * 2 - 1 }
    /** A take of the same voice: its centre plus [spread] of variation. */
    private fun take(c: FloatArray, spread: Float) = FloatArray(c.size) { c[it] + spread * (rnd.nextFloat() * 2 - 1) }

    private fun m(speechMs: Int = 3000, snr: Float = 20f, peak: Float = -12f, clipped: Float = 0f) =
        ClipMetrics(speechMs + 800, peak, peak - 6, -50f, snr, clipped, 300, 300 + speechMs, speechMs / 10)

    @Test
    fun aGoodTakeIsUsable() = assertNull(EnrollmentPolicy.takeProblem(m()))

    @Test
    fun poorTakesAreRefusedWithAPreciseReason() {
        assertEquals("too_short", EnrollmentPolicy.takeProblem(m(speechMs = 900)))
        assertEquals("too_noisy", EnrollmentPolicy.takeProblem(m(snr = 3f)))
        assertEquals("clipped", EnrollmentPolicy.takeProblem(m(clipped = 0.02f)))
        assertEquals("too_quiet", EnrollmentPolicy.takeProblem(m(peak = -55f)))
    }

    @Test
    fun aConclusiveSecondSentenceFinishesWithTwoRecordings() {
        val me = centre(1)
        val d = EnrollmentPolicy.decide(listOf(take(me, 0.25f), take(me, 0.25f)), takes = 2)
        assertEquals(Verdict.READY, d.verdict)
        assertEquals(2, d.profile.size)
    }

    @Test
    fun anInconclusiveCheckAsksForOneMoreSampleNotAFixedNumber() {
        val me = centre(1)
        // Two takes of a noisy / changing voice that only partly agree.
        val a = take(me, 1.0f)
        val b = take(me, 1.9f)
        val d = EnrollmentPolicy.decide(listOf(a, b), takes = 2)
        assertEquals(Verdict.NEED_MORE, d.verdict)
        assertTrue(d.reason == "not_sure" || d.reason == "different_voice")
    }

    @Test
    fun aDifferentVoiceIsNeverAcceptedAndIsTold() {
        val d = EnrollmentPolicy.decide(listOf(take(centre(1), 0.2f), take(centre(2), 0.2f)), takes = 2)
        assertEquals(Verdict.NEED_MORE, d.verdict)
        assertEquals("different_voice", d.reason)
    }

    @Test
    fun anExtraSampleThatAgreesCompletesTheProfile() {
        val me = centre(1)
        val pool = listOf(take(me, 0.9f), take(me, 1.1f), take(me, 0.4f))
        val d = EnrollmentPolicy.decide(pool, takes = 3)
        assertEquals(Verdict.READY, d.verdict)
        assertTrue(d.profile.size >= 3)
    }

    @Test
    fun itStopsAskingAfterTheMaximumAndKeepsTheManualPath() {
        val d = EnrollmentPolicy.decide(
            listOf(take(centre(1), 2f), take(centre(2), 2f), take(centre(3), 2f), take(centre(4), 2f)),
            takes = EnrollmentPolicy.MAX_TAKES,
        )
        assertEquals(Verdict.NEEDS_IMPROVEMENT, d.verdict)
        assertEquals("not_consistent", d.reason)
    }

    @Test
    fun liveTestWordsDoNotExposeScores() {
        assertEquals("match", EnrollmentPolicy.describeTest(0.62f, 0.5f))
        assertEquals("uncertain", EnrollmentPolicy.describeTest(0.46f, 0.5f))
        assertEquals("different", EnrollmentPolicy.describeTest(0.2f, 0.5f))
    }
}
