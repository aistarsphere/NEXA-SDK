package com.nexa.assistant.engine

import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.sqrt

/** Probability (0..1) that one 32 ms frame of 16 kHz audio contains speech. */
interface SpeechProbability {
    fun probability(frame: FloatArray): Float
    fun reset()
}

/**
 * Fallback detector when the neural VAD cannot load. Unlike the wake
 * segmenter it learns the floor from the quietest part of the last two
 * seconds (never from a single first chunk), so steady room noise does not
 * look like speech.
 */
class EnergyVad(private val marginDb: Double = 10.0) : SpeechProbability {
    private var floor = Double.NaN

    override fun probability(frame: FloatArray): Float {
        var e = 0.0
        for (s in frame) e += s * s
        val db = 10 * log10(e / frame.size + 1e-10)
        // Microphone warm-up delivers digital silence: it says nothing about the room.
        if (db < -85.0) return 0f
        // Minimum tracking: down at once, up very slowly, so a long sentence
        // never becomes "the noise floor".
        floor = if (floor.isNaN() || db < floor) db else floor + 0.02
        return if (db > max(floor + marginDb, -62.0)) 1f else 0f
    }

    override fun reset() {
        floor = Double.NaN
    }
}

/** Timing rules of one kind of prompt. */
data class RecorderConfig(
    /** Speech needed for the take to count at all. */
    val minSpeechMs: Int,
    /** Actual speech (not silence) beyond this is "too long". */
    val maxSpeechMs: Int,
    /** Silence that ends the utterance (longer for sentences: they pause). */
    val endSilenceMs: Int,
    /** Give up when nobody starts speaking. */
    val noSpeechTimeoutMs: Int,
    /** Absolute cap on how long the microphone stays open. */
    val hardLimitMs: Int,
    val preRollMs: Int = 300,
    val startProb: Float = 0.5f,
    val endProb: Float = 0.35f,
    /** Consecutive voiced frames that start an utterance (about 96 ms). */
    val startFrames: Int = 3,
    /**
     * The first moments after the microphone opens carry its start-up pop and
     * the sound of the tap that started the recording: no speech may begin
     * (and "speak now" is not shown) until this has passed.
     */
    val warmUpMs: Int = 320,
) {
    companion object {
        /** The wake phrase: short, said on its own. */
        val WAKE = RecorderConfig(250, 3500, 500, 7000, 12_000)
        /** A sentence: pauses inside it must not end it. */
        val SENTENCE = RecorderConfig(1000, 12_000, 900, 8000, 25_000)
        val NEGATIVE = RecorderConfig(250, 6000, 700, 7000, 14_000)
    }
}

/** What the screen needs to show, in order. */
sealed interface RecorderEvent {
    /** The microphone delivers audio: tell the person to speak. */
    data object Ready : RecorderEvent
    data class Level(val db: Float, val speaking: Boolean) : RecorderEvent
    data object SpeechStarted : RecorderEvent
    /** Speech stopped: the take is being finalised. */
    data class SpeechEnded(val speechMs: Int) : RecorderEvent
    data class Captured(val take: Take) : RecorderEvent
    data class Rejected(val reason: String, val speechMs: Int = 0) : RecorderEvent
}

/** One finished utterance, with per-frame speech labels for measuring it. */
class Take(val samples: FloatArray, val voiced: BooleanArray, val speechMs: Int, val openMs: Int)

/**
 * The recording state machine: waiting -> speaking -> done. Frames are 512
 * samples (32 ms). The end of the utterance is decided by [endSilenceMs] of
 * non-speech after real speech, never by the clock alone; the clock only
 * bounds waiting for speech ([noSpeechTimeoutMs]) and the total ([hardLimitMs]).
 * "Too long" means the person really spoke longer than [maxSpeechMs].
 */
class UtteranceRecorder(
    private val vad: SpeechProbability,
    private val cfg: RecorderConfig,
    private val onEvent: (RecorderEvent) -> Unit,
) {
    companion object {
        const val FRAME = 512
        const val FRAME_MS = 32
    }

    private enum class State { WAITING, SPEAKING, DONE }

    private var state = State.WAITING
    private var frames = 0
    private val preRoll = ArrayDeque<FloatArray>()
    private val preRollFrames = cfg.preRollMs / FRAME_MS + 1
    private val body = ArrayList<FloatArray>()
    private val labels = ArrayList<Boolean>()
    private var voicedRun = 0
    private var speechMs = 0
    private var silenceFrames = 0
    private var announcedReady = false

    val done: Boolean get() = state == State.DONE

    /** Latest verdict (numbers only, for diagnostics). */
    var lastProbability = 0f
        private set

    /** Feeds exactly [FRAME] samples. */
    fun feed(frame: FloatArray) {
        if (state == State.DONE) return
        require(frame.size == FRAME)
        frames++
        val openMs = frames * FRAME_MS
        val warm = openMs <= cfg.warmUpMs
        // The detector still sees warm-up audio (it settles), but its verdict is ignored.
        val p = if (warm) 0f.also { vad.probability(frame) } else vad.probability(frame)
        lastProbability = p
        if (!announcedReady && !warm) {
            announcedReady = true
            onEvent(RecorderEvent.Ready)
        }
        var e = 0f
        for (s in frame) e += s * s
        val db = 10f * log10(e / FRAME + 1e-10f)
        when (state) {
            State.WAITING -> {
                preRoll.addLast(frame.copyOf())
                if (preRoll.size > preRollFrames) preRoll.removeFirst()
                voicedRun = if (p >= cfg.startProb) voicedRun + 1 else 0
                if (announcedReady) onEvent(RecorderEvent.Level(db, false))
                if (voicedRun >= cfg.startFrames) {
                    state = State.SPEAKING
                    // Pre-roll (room sound before speech) + the voiced frames so far.
                    val pre = preRoll.toList()
                    preRoll.clear()
                    for ((i, f) in pre.withIndex()) {
                        body += f
                        labels += (i >= pre.size - voicedRun)
                    }
                    speechMs = voicedRun * FRAME_MS
                    silenceFrames = 0
                    onEvent(RecorderEvent.SpeechStarted)
                } else if (openMs >= cfg.noSpeechTimeoutMs) {
                    finish(RecorderEvent.Rejected("no_speech"))
                }
            }
            State.SPEAKING -> {
                body += frame.copyOf()
                val voiced = p >= cfg.endProb
                labels += voiced
                onEvent(RecorderEvent.Level(db, voiced))
                if (voiced) {
                    speechMs += FRAME_MS
                    silenceFrames = 0
                } else {
                    silenceFrames++
                }
                when {
                    speechMs > cfg.maxSpeechMs -> finish(RecorderEvent.Rejected("too_long", speechMs))
                    silenceFrames * FRAME_MS >= cfg.endSilenceMs || openMs >= cfg.hardLimitMs -> endUtterance(openMs)
                    else -> Unit
                }
            }
            State.DONE -> Unit
        }
        if (state == State.WAITING && openMs >= cfg.hardLimitMs) finish(RecorderEvent.Rejected("no_speech"))
    }

    /** The person (or the system) stopped the recording. */
    fun cancel(reason: String = "interrupted") {
        if (state != State.DONE) finish(RecorderEvent.Rejected(reason, speechMs))
    }

    private fun endUtterance(openMs: Int) {
        onEvent(RecorderEvent.SpeechEnded(speechMs))
        if (speechMs < cfg.minSpeechMs) return finish(RecorderEvent.Rejected("too_short", speechMs))
        // Keep at most ~250 ms of the closing silence.
        val keepTail = 250 / FRAME_MS
        val cut = max(0, body.size - max(0, silenceFrames - keepTail))
        val out = FloatArray(cut * FRAME)
        val voiced = BooleanArray(cut)
        for (i in 0 until cut) {
            System.arraycopy(body[i], 0, out, i * FRAME, FRAME)
            voiced[i] = labels[i]
        }
        finish(RecorderEvent.Captured(Take(out, voiced, speechMs, openMs)))
    }

    private fun finish(e: RecorderEvent) {
        state = State.DONE
        onEvent(e)
    }
}

/** Measurements of a take using its speech labels (not a guessed noise gate). */
object TakeMetrics {
    /** Null when the take is usable; else a reason code (level / noise / distortion). */
    fun problem(m: ClipMetrics, e: ClipExpectation): String? {
        if (m.clippedFraction > 0.005f) return "clipped"
        if (m.peakDb < e.minPeakDb) return "too_quiet"
        if (m.snrDb < e.minSnrDb) return "too_noisy"
        return null
    }

    fun of(t: Take): ClipMetrics {
        val n = t.voiced.size
        var sp = 0.0; var spN = 0
        var nz = 0.0; var nzN = 0
        var peak = 0f; var clipped = 0
        var first = -1; var last = -1
        for (i in 0 until n) {
            var e = 0.0
            for (k in 0 until UtteranceRecorder.FRAME) {
                val v = t.samples[i * UtteranceRecorder.FRAME + k]
                e += v * v
                val a = abs(v)
                if (a > peak) peak = a
                if (a >= 0.99f) clipped++
            }
            e /= UtteranceRecorder.FRAME
            if (t.voiced[i]) {
                sp += e; spN++
                if (first < 0) first = i
                last = i
            } else { nz += e; nzN++ }
        }
        val speechPow = if (spN > 0) sp / spN else 0.0
        val noisePow = if (nzN > 0) nz / nzN else 1e-9
        val clean = max(speechPow - noisePow, 1e-12)
        val snr = (10 * log10(clean / max(noisePow, 1e-12))).toFloat()
        val ms = UtteranceRecorder.FRAME_MS
        return ClipMetrics(
            durationMs = n * ms,
            peakDb = ClipQuality.db(peak),
            speechRmsDb = ClipQuality.db(sqrt(speechPow).toFloat()),
            noiseDb = ClipQuality.db(sqrt(noisePow).toFloat()),
            snrDb = snr,
            clippedFraction = if (n > 0) clipped.toFloat() / (n * UtteranceRecorder.FRAME) else 0f,
            speechStartMs = if (first < 0) 0 else first * ms,
            speechEndMs = if (last < 0) 0 else (last + 1) * ms,
            speechFrames = spN,
        )
    }
}
