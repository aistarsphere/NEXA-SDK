package com.nexa.assistant.engine

import kotlin.math.abs
import kotlin.math.sqrt

/** Turns one utterance into a fixed-size voice embedding (speaker model). */
fun interface SpeakerEmbedder {
    /** Null when the model cannot run (e.g. not installed). */
    fun embed(samples: FloatArray): FloatArray?
}

/**
 * The enrolled owner's voice: the mean embedding, the individual enrolment
 * embeddings and the accept threshold.
 *
 * Score = the better of (similarity to the mean) and (average of the two
 * closest enrolment samples). The second term tolerates the owner's normal
 * variation (tone, speed, loudness) that a single mean blurs, while a
 * stranger is still far from every sample.
 */
class SpeakerProfile(
    val embedding: FloatArray,
    val threshold: Float,
    val samples: List<FloatArray> = emptyList(),
) {
    fun score(other: FloatArray): Float {
        val mean = cosine(embedding, other)
        if (samples.size < 2) return mean
        val top = samples.map { cosine(it, other) }.sortedDescending()
        return maxOf(mean, (top[0] + top[1]) / 2)
    }

    companion object {
        const val DEFAULT_THRESHOLD = 0.55f
        private const val MIN_THRESHOLD = 0.40f
        private const val MAX_THRESHOLD = 0.65f

        /**
         * Owner profile from the enrolment embeddings. The threshold sits
         * 0.12 below the weakest leave-one-out score (each sample scored
         * against a profile of the others, with the same rule as above),
         * clamped. Never lowered below [MIN_THRESHOLD] to admit the owner.
         */
        fun fromEmbeddings(list: List<FloatArray>): SpeakerProfile {
            require(list.isNotEmpty())
            val mean = normalised(average(list))
            if (list.size < 3) return SpeakerProfile(mean, DEFAULT_THRESHOLD, list)
            var weakest = 1f
            for (i in list.indices) {
                val rest = list.filterIndexed { j, _ -> j != i }
                val p = SpeakerProfile(normalised(average(rest)), 0f, rest)
                weakest = minOf(weakest, p.score(list[i]))
            }
            val t = (weakest - 0.12f).coerceIn(MIN_THRESHOLD, MAX_THRESHOLD)
            return SpeakerProfile(mean, t, list)
        }

        fun cosine(a: FloatArray, b: FloatArray): Float {
            var dot = 0.0
            var na = 0.0
            var nb = 0.0
            for (i in a.indices) {
                dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]
            }
            if (na == 0.0 || nb == 0.0) return 0f
            return (dot / sqrt(na * nb)).toFloat()
        }

        private fun average(list: List<FloatArray>): FloatArray {
            val out = FloatArray(list[0].size)
            for (v in list) for (i in out.indices) out[i] += v[i] / list.size
            return out
        }

        private fun normalised(v: FloatArray): FloatArray {
            var n = 0.0
            for (x in v) n += x * x
            val s = sqrt(n).toFloat()
            return if (s == 0f) v else FloatArray(v.size) { v[it] / s }
        }
    }
}

/** Why an utterance did or did not activate the assistant. */
data class WakeDecision(
    val accepted: Boolean,
    val reason: String,
    val keywordDistance: Float,
    val keywordThreshold: Float,
    val speakerScore: Float? = null,
    val speakerThreshold: Float? = null,
    val durationMs: Int = 0,
)

/**
 * The local activation pipeline: speech segment → wake phrase (DTW) →
 * optional owner-voice check → decision. Audio stays in memory and is
 * dropped after each decision.
 *
 * Safeguards: a refractory period after an activation, and rejection of an
 * utterance that is a near-exact copy of the previously accepted one (a
 * replayed recording; a person never repeats a phrase identically).
 */
class WakeEngine(
    private val model: WakePhraseModel,
    private val speaker: SpeakerProfile?,
    private val embedder: SpeakerEmbedder?,
    private val requireOwner: Boolean,
    private val sensitivity: Sensitivity = Sensitivity.NORMAL,
    private val refractoryMs: Long = 3000,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onDecision: (WakeDecision) -> Unit,
) {
    private val bank = FilterBank()
    private var lastAcceptedAt = Long.MIN_VALUE / 2
    private var lastAccepted: Array<FloatArray>? = null

    private val segmenter = SpeechSegmenter(onSegment = ::evaluate)

    fun accept(samples: FloatArray, count: Int = samples.size) =
        segmenter.accept(samples, count)

    fun reset() = segmenter.reset()

    /** Runs the full decision on one utterance (also used by "Test"). */
    fun evaluate(segment: FloatArray) {
        onDecision(decide(segment))
    }

    fun decide(segment: FloatArray): WakeDecision {
        val ms = segment.size / 16
        val now = clock()
        val threshold = model.threshold * sensitivity.keywordScale
        if (now - lastAcceptedAt < refractoryMs) {
            return WakeDecision(false, "refractory", Float.NaN, threshold, durationMs = ms)
        }
        val features = bank.phraseFeatures(segment)
        val distance = model.distance(features)
        if (distance > threshold) {
            return WakeDecision(false, "phrase_mismatch", distance, threshold, durationMs = ms)
        }
        val previous = lastAccepted
        if (previous != null && WakePhraseModel.dtw(features, previous) < threshold * 0.12f) {
            return WakeDecision(false, "replay_suspected", distance, threshold, durationMs = ms)
        }
        var score: Float? = null
        var speakerThreshold: Float? = null
        if (requireOwner) {
            val profile = speaker
            val e = profile?.let { embedder?.embed(segment) }
            if (profile == null || e == null) {
                return WakeDecision(false, "speaker_unavailable", distance, threshold, durationMs = ms)
            }
            score = profile.score(e)
            speakerThreshold = profile.threshold + sensitivity.speakerOffset
            if (score < speakerThreshold) {
                return WakeDecision(
                    false, "speaker_mismatch", distance, threshold,
                    score, speakerThreshold, ms,
                )
            }
        }
        lastAcceptedAt = now
        lastAccepted = features
        return WakeDecision(true, "accepted", distance, threshold, score, speakerThreshold, ms)
    }
}

/** Enrolment sample quality, checked before a sample is kept. */
object SampleQuality {
    /** Null when acceptable, else a reason code. */
    fun problem(segment: FloatArray?): String? {
        if (segment == null) return "no_speech"
        val ms = segment.size / 16
        if (ms < 350) return "too_short"
        if (ms > 2600) return "too_long"
        var peak = 0f
        var clipped = 0
        for (s in segment) {
            val a = abs(s)
            if (a > peak) peak = a
            if (a > 0.99f) clipped++
        }
        if (peak < 0.02f) return "too_quiet"
        if (clipped > segment.size / 200) return "clipped"
        return null
    }
}
