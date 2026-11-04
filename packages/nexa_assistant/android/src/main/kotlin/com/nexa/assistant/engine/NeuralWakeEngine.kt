package com.nexa.assistant.engine

import kotlin.math.abs
import kotlin.math.max

/** What the microphone loop feeds; implemented by both detector engines. */
interface WakeFrontEnd {
    fun accept(samples: FloatArray, count: Int = samples.size)
    fun reset()
}

/**
 * Wake phrase by a trained acoustic model (mel + speech-embedding + head),
 * then the optional owner-voice check on the phrase that just ended, then a
 * decision. Decision fields reuse [WakeDecision]: `keywordDistance` is
 * `1 - score` and `keywordThreshold` is `1 - threshold`, so "smaller is
 * better" holds for both detectors in the logs.
 */
class NeuralWakeEngine(
    features: WakeFeatures,
    head: WakeHead,
    private val baseThreshold: Float,
    hits: Int,
    private val speaker: SpeakerProfile?,
    private val embedder: SpeakerEmbedder?,
    private val requireOwner: Boolean,
    private val sensitivity: Sensitivity = Sensitivity.NORMAL,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onDecision: (WakeDecision) -> Unit,
) : WakeFrontEnd {
    private val threshold = (baseThreshold + sensitivity.neuralOffset).coerceIn(0.5f, 0.995f)
    private val detector = EmbeddingWakeDetector(
        features, head, threshold, hits, clock = clock, onWake = ::wake,
    )

    val lastScore: Float get() = detector.lastScore

    override fun accept(samples: FloatArray, count: Int) = detector.accept(samples, count)
    override fun reset() = detector.reset()

    private fun wake(score: Float, tail: FloatArray) {
        val segment = ClipQuality.normalizeLevel(speechTail(tail))
        val ms = segment.size / 16
        val distance = 1f - score
        val limit = 1f - threshold
        if (!requireOwner) {
            onDecision(WakeDecision(true, "accepted", distance, limit, durationMs = ms))
            return
        }
        val e = speaker?.let { embedder?.embed(segment) }
        if (speaker == null || e == null) {
            onDecision(WakeDecision(false, "speaker_unavailable", distance, limit, durationMs = ms))
            return
        }
        val s = speaker.score(e)
        val t = speaker.threshold + sensitivity.speakerOffset
        onDecision(
            if (s >= t) WakeDecision(true, "accepted", distance, limit, s, t, ms)
            else WakeDecision(false, "speaker_mismatch", distance, limit, s, t, ms),
        )
    }

    companion object {
        /**
         * The last ~1.8 s up to the wake, from where speech starts (frames
         * more than 30 dB under the loudest are dropped at the front).
         */
        fun speechTail(tail: FloatArray, maxSamples: Int = 29_000): FloatArray {
            val from = max(0, tail.size - maxSamples)
            val frame = 160
            var peak = 1e-6f
            val rms = FloatArray((tail.size - from) / frame) { i ->
                var s = 0f
                for (k in 0 until frame) { val v = tail[from + i * frame + k]; s += v * v }
                kotlin.math.sqrt(s / frame).also { if (it > peak) peak = it }
            }
            val floor = peak * 0.0316f // -30 dB
            val first = rms.indexOfFirst { it >= floor }.let { if (it < 0) 0 else it }
            return tail.copyOfRange(from + first * frame, tail.size)
        }
    }
}
