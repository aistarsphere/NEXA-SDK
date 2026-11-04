package com.nexa.assistant

import com.nexa.assistant.engine.ClipExpectation
import com.nexa.assistant.engine.ClipQuality
import com.nexa.assistant.engine.SpeakerCalibration
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** Clip measurements and calibration on synthetic signals / embeddings. */
class VoiceSetupMathTest {
    private val rnd = Random(3)

    private fun clip(speechMs: Int, amp: Float, noise: Float, lead: Int = 600, tail: Int = 600): FloatArray {
        val n = (lead + speechMs + tail) * 16
        return FloatArray(n) { i ->
            val t = i / 16
            val voiced = t in lead until lead + speechMs
            val s = if (voiced) amp * sin(2 * PI * 180 * i / 16000).toFloat() else 0f
            s + noise * (rnd.nextFloat() * 2 - 1)
        }
    }

    @Test
    fun measuresDurationLevelAndSnr() {
        val m = ClipQuality.analyze(clip(1200, 0.3f, 0.002f))
        assertTrue(m.speechMs in 1100..1300, "speech ${m.speechMs}")
        assertTrue(m.speechStartMs in 550..650, "start ${m.speechStartMs}")
        assertTrue(m.snrDb > 30f, "snr ${m.snrDb}")
        assertTrue(m.peakDb in -11f..-8f, "peak ${m.peakDb}")
    }

    @Test
    fun aQuietTakeIsOnlyRejectedWhenThePromptWantsNormalVolume() {
        val m = ClipQuality.analyze(clip(1000, 0.012f, 0.0004f)) // ~ -38 dBFS peak
        assertEquals("too_quiet", ClipQuality.problem(m, ClipExpectation(minPeakDb = -30f)))
        assertNull(ClipQuality.problem(m, ClipExpectation(minPeakDb = -48f)))
    }

    @Test
    fun rejectsSilenceClippingAndNoise() {
        assertEquals("no_speech", ClipQuality.problem(ClipQuality.analyze(FloatArray(32000)), ClipExpectation()))
        val clipped = clip(1000, 1.5f, 0.0f).map { it.coerceIn(-1f, 1f) }.toFloatArray()
        assertEquals("clipped", ClipQuality.problem(ClipQuality.analyze(clipped), ClipExpectation()))
        val noisy = ClipQuality.analyze(clip(1000, 0.05f, 0.04f))
        assertEquals("too_noisy", ClipQuality.problem(noisy, ClipExpectation(minSnrDb = 12f)))
        // A prompt that expects background noise accepts it.
        assertNull(ClipQuality.problem(noisy, ClipExpectation(minSnrDb = 0f, minPeakDb = -40f)))
    }

    @Test
    fun trimKeepsRoomAroundTheSpeech() {
        val x = clip(1000, 0.3f, 0.001f, lead = 2000, tail = 2000)
        val m = ClipQuality.analyze(x)
        val t = ClipQuality.trim(x, m, padMs = 500)
        assertTrue(t.size in 31000..33000, "size ${t.size}") // ~1.0 s + 2 x 0.5 s at 16 kHz
    }

    private fun cluster(center: FloatArray, n: Int, spread: Float) = List(n) {
        FloatArray(center.size) { i -> center[i] + spread * (rnd.nextFloat() * 2 - 1) }
    }

    private fun centre(seed: Int) = FloatArray(48) { Random(seed).let { r -> repeat(it) { r.nextFloat() }; r.nextFloat() * 2 - 1 } }

    @Test
    fun withGuestsTheThresholdSitsBetweenOwnerAndStrangers() {
        val owner = cluster(centre(1), 24, 0.55f)
        val guests = cluster(centre(2), 10, 0.55f) + cluster(centre(3), 10, 0.55f)
        val r = SpeakerCalibration.calibrate(owner, guests)
        assertEquals("with_guests", r.mode)
        assertTrue(r.separable, "separable: owner p05 ${r.ownerP05} vs impostor max ${r.impostorMax}")
        assertTrue(r.threshold > r.impostorMax!! && r.threshold < r.ownerP05, "t ${r.threshold}")
    }

    @Test
    fun ownerOnlyIsLabelledAsNotMeasuringFalseAcceptance() {
        val r = SpeakerCalibration.calibrate(cluster(centre(1), 12, 0.5f), emptyList())
        assertEquals("owner_only", r.mode)
        assertNull(r.impostorMax)
        assertTrue(r.threshold in 0.40f..0.65f)
    }

    @Test
    fun overlappingStrangersAreReportedNotHidden() {
        val owner = cluster(centre(1), 20, 1.6f) // very spread out
        val similar = cluster(centre(1), 12, 1.6f) // a "stranger" from the same cloud
        val r = SpeakerCalibration.calibrate(owner, similar)
        assertFalse(r.separable)
    }

    @Test
    fun refusesToCalibrateOnTooFewOwnerSamples() {
        val e = runCatching { SpeakerCalibration.calibrate(cluster(centre(1), 3, 0.3f), emptyList()) }
        assertTrue(e.isFailure)
    }
}
