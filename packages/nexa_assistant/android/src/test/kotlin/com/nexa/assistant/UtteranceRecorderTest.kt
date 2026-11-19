package com.nexa.assistant

import com.nexa.assistant.engine.EnergyVad
import com.nexa.assistant.engine.RecorderConfig
import com.nexa.assistant.engine.RecorderEvent
import com.nexa.assistant.engine.TakeMetrics
import com.nexa.assistant.engine.UtteranceRecorder
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** The recording state machine on synthetic audio (the energy VAD stands in for Silero). */
class UtteranceRecorderTest {
    private val rnd = Random(5)

    private class Run(val events: MutableList<RecorderEvent>, val recorder: UtteranceRecorder, val frames: Int)

    /** [segments]: (lengthMs, amplitude); amplitude 0 = quiet gap. Steady room noise underneath. */
    private fun run(
        segments: List<Pair<Int, Float>>,
        cfg: RecorderConfig,
        noise: Float = 0.003f,
        cancelAtMs: Int? = null,
        extraSilenceMs: Int = 0,
    ): Run {
        val events = mutableListOf<RecorderEvent>()
        val rec = UtteranceRecorder(EnergyVad(), cfg) { events += it }
        var t = 0
        var phase = 0.0
        val all = segments + listOf(extraSilenceMs to 0f)
        loop@ for ((ms, amp) in all) {
            var left = ms * 16
            while (left > 0 && !rec.done) {
                val frame = FloatArray(UtteranceRecorder.FRAME) { i ->
                    val voiced = if (amp > 0f) amp * sin(phase + 2 * PI * 170 * (t + i) / 16000).toFloat() else 0f
                    voiced + noise * (rnd.nextFloat() * 2 - 1)
                }
                rec.feed(frame)
                t += UtteranceRecorder.FRAME
                left -= UtteranceRecorder.FRAME
                if (cancelAtMs != null && t / 16 >= cancelAtMs) { rec.cancel(); break@loop }
            }
        }
        return Run(events, rec, t / UtteranceRecorder.FRAME)
    }

    private fun Run.outcome(): RecorderEvent = events.last { it is RecorderEvent.Captured || it is RecorderEvent.Rejected }

    @Test
    fun aShortPhraseInSteadyRoomNoiseIsCapturedWhereTheOldSegmenterNeverEnded() {
        // 1.5 s of room noise at about -50 dBFS, 0.9 s of speech, then silence.
        val r = run(listOf(1500 to 0f, 900 to 0.2f), RecorderConfig.WAKE, noise = 0.0045f, extraSilenceMs = 3000)
        assertTrue(r.events.first() is RecorderEvent.Ready)
        val o = r.outcome()
        assertTrue(o is RecorderEvent.Captured, "got $o")
        val take = (o as RecorderEvent.Captured).take
        assertTrue(take.speechMs in 700..1100, "speech ${take.speechMs}")
        assertTrue(take.openMs < 4500, "the microphone closed by itself after ${take.openMs} ms, not at a limit")
        assertTrue(r.events.any { it is RecorderEvent.SpeechStarted })
        assertTrue(r.events.any { it is RecorderEvent.SpeechEnded })
    }

    @Test
    fun theTakeIsFinalisedBySilenceNotByTheClock() {
        val r = run(listOf(600 to 0f, 700 to 0.2f), RecorderConfig.WAKE, extraSilenceMs = 2000)
        val take = (r.outcome() as RecorderEvent.Captured).take
        // 0.6 s lead + 0.7 s speech + ~0.5 s end silence: well under the 12 s limit.
        assertTrue(take.openMs in 1500..2400, "open ${take.openMs}")
    }

    @Test
    fun noSpeechIsReportedAsNoSpeech() {
        val r = run(listOf(9000 to 0f), RecorderConfig.WAKE.copy(noSpeechTimeoutMs = 4000))
        val o = r.outcome()
        assertTrue(o is RecorderEvent.Rejected && o.reason == "no_speech", "got $o")
    }

    @Test
    fun aVeryShortSoundIsTooShortNotTooLong() {
        val r = run(listOf(800 to 0f, 120 to 0.2f), RecorderConfig.WAKE, extraSilenceMs = 2000)
        val o = r.outcome()
        assertTrue(o is RecorderEvent.Rejected && o.reason == "too_short", "got $o")
    }

    @Test
    fun tooLongOnlyWhenTheSpeechItselfIsLong() {
        val r = run(listOf(500 to 0f, 5000 to 0.2f), RecorderConfig.WAKE, extraSilenceMs = 1000)
        val o = r.outcome()
        assertTrue(o is RecorderEvent.Rejected && o.reason == "too_long" && o.speechMs > 3500, "got $o")
        // The same audio is fine as a sentence.
        val s = run(listOf(500 to 0f, 5000 to 0.2f), RecorderConfig.SENTENCE, extraSilenceMs = 2000)
        assertTrue(s.outcome() is RecorderEvent.Captured, "got ${s.outcome()}")
    }

    @Test
    fun aPauseInsideASentenceDoesNotEndIt() {
        val r = run(
            listOf(500 to 0f, 1500 to 0.2f, 600 to 0f, 1500 to 0.2f),
            RecorderConfig.SENTENCE, extraSilenceMs = 2000,
        )
        val take = (r.outcome() as RecorderEvent.Captured).take
        assertTrue(take.speechMs in 2800..3300, "speech ${take.speechMs}: both halves kept")
    }

    @Test
    fun loudAndQuietSpeechAreBothCaptured() {
        for (amp in listOf(0.02f, 0.9f)) {
            val r = run(listOf(800 to 0f, 900 to amp), RecorderConfig.WAKE, noise = 0.0008f, extraSilenceMs = 2000)
            assertTrue(r.outcome() is RecorderEvent.Captured, "amp $amp -> ${r.outcome()}")
        }
    }

    @Test
    fun aClickOrPopRightAfterTheMicrophoneOpensIsNotSpeech() {
        // 200 ms of loud transient at the very start, then room noise, then a real phrase.
        val r = run(listOf(200 to 0.5f, 1500 to 0f, 900 to 0.2f), RecorderConfig.WAKE, extraSilenceMs = 3000)
        val o = r.outcome()
        assertTrue(o is RecorderEvent.Captured, "got $o")
        val take = (o as RecorderEvent.Captured).take
        assertTrue(take.speechMs in 700..1100, "only the real phrase counts: ${take.speechMs}")
        // "Speak now" was announced only after the warm-up.
        val readyAt = r.events.indexOfFirst { it is RecorderEvent.Ready }
        val levelsBefore = r.events.take(readyAt).count { it is RecorderEvent.Level }
        assertEquals(0, levelsBefore)
    }

    @Test
    fun cancellationEndsTheTakeWithoutAResultToKeep() {
        val r = run(listOf(500 to 0f, 3000 to 0.2f), RecorderConfig.SENTENCE, cancelAtMs = 1500)
        val o = r.outcome()
        assertTrue(o is RecorderEvent.Rejected && o.reason == "interrupted", "got $o")
        assertTrue(r.recorder.done)
    }

    @Test
    fun eachAttemptIsIndependent() {
        val first = run(listOf(9000 to 0f), RecorderConfig.WAKE.copy(noSpeechTimeoutMs = 3000))
        assertTrue((first.outcome() as RecorderEvent.Rejected).reason == "no_speech")
        val second = run(listOf(600 to 0f, 800 to 0.2f), RecorderConfig.WAKE, extraSilenceMs = 2000)
        assertTrue(second.outcome() is RecorderEvent.Captured)
    }

    @Test
    fun metricsUseTheSpeechLabelsSoNoiseIsNotCountedAsSpeech() {
        val r = run(listOf(1200 to 0f, 1000 to 0.2f), RecorderConfig.WAKE, noise = 0.004f, extraSilenceMs = 2000)
        val take = (r.outcome() as RecorderEvent.Captured).take
        val m = TakeMetrics.of(take)
        assertNotNull(m)
        assertTrue(m.speechMs in 700..1300, "speech span ${m.speechMs}")
        assertTrue(m.snrDb > 20f, "snr ${m.snrDb}")
        assertEquals(take.samples.size / UtteranceRecorder.FRAME * UtteranceRecorder.FRAME_MS, m.durationMs)
    }
}
