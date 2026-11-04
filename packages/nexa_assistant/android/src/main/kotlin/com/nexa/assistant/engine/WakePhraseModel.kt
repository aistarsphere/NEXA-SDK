package com.nexa.assistant.engine

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * The owner's wake phrase as MFCC templates (one per enrolment sample),
 * matched by dynamic time warping. A personal, speaker-dependent keyword
 * spotter: no trained Arabic wake-word model is needed, but it only knows
 * the phrase as the enrolled person says it.
 *
 * [threshold] is calibrated from how close the owner's own samples are
 * to each other at enrolment.
 */
class WakePhraseModel(
    val templates: List<Array<FloatArray>>,
    val threshold: Float,
) {
    init {
        require(templates.isNotEmpty())
    }

    /** Best (lowest) normalised DTW distance to any template. */
    fun distance(features: Array<FloatArray>): Float =
        templates.minOf { dtw(features, it) }

    fun matches(features: Array<FloatArray>, sensitivity: Sensitivity) =
        distance(features) <= threshold * sensitivity.keywordScale

    companion object {
        const val MIN_SAMPLES = 3

        /**
         * A new enrolment sample this far from all others is another phrase.
         * Real voices vary far more between takes than synthetic speech
         * (first device data: 0.33-0.44 between the owner's own takes), so
         * this only catches clearly different utterances.
         */
        const val INCONSISTENT = 0.55f
        private const val MIN_THRESHOLD = 0.05f
        private const val MAX_THRESHOLD = 0.30f

        /**
         * Builds the model from enrolment features. Matching uses the
         * nearest template, so the threshold comes from each sample's
         * distance to its nearest other sample (median, robust to one odd
         * sample) times 3, clamped. Measured on test speech only: real
         * voices must be checked with the settings "Test".
         */
        fun fromSamples(samples: List<Array<FloatArray>>): WakePhraseModel {
            require(samples.size >= MIN_SAMPLES)
            val nearest = samples.indices.map { i ->
                samples.indices.filter { it != i }.minOf { j -> dtw(samples[i], samples[j]) }
            }.sorted()
            val median = nearest[nearest.size / 2]
            val threshold = (median * 3f).coerceIn(MIN_THRESHOLD, MAX_THRESHOLD)
            return WakePhraseModel(samples, threshold)
        }

        /** Distance from [sample] to the closest of [others]. */
        fun nearest(sample: Array<FloatArray>, others: List<Array<FloatArray>>): Float =
            others.minOf { dtw(sample, it) }

        /**
         * Length-normalised DTW over cosine frame distances (robust to
         * loudness and steady noise) with a Sakoe-Chiba band. Utterances
         * whose lengths differ by more than 2.5x cannot be the same phrase.
         */
        fun dtw(a: Array<FloatArray>, b: Array<FloatArray>): Float {
            val n = a.size
            val m = b.size
            if (n == 0 || m == 0) return Float.MAX_VALUE
            if (max(n, m) * 2 > 5 * min(n, m)) return Float.MAX_VALUE
            val band = max(abs(n - m), max(n, m) / 4) + 2
            val inf = Float.MAX_VALUE / 4
            var prev = FloatArray(m + 1) { inf }
            var cur = FloatArray(m + 1) { inf }
            prev[0] = 0f
            for (i in 1..n) {
                cur.fill(inf)
                val center = (i.toLong() * m / n).toInt()
                val from = max(1, center - band)
                val to = min(m, center + band)
                for (j in from..to) {
                    val c = cosineDistance(a[i - 1], b[j - 1])
                    val best = min(prev[j - 1], min(prev[j], cur[j - 1]))
                    cur[j] = c + best
                }
                val t = prev; prev = cur; cur = t
            }
            val total = prev[m]
            return if (total >= inf) Float.MAX_VALUE else total / (n + m)
        }

        private fun cosineDistance(x: FloatArray, y: FloatArray): Float {
            var dot = 0f
            var nx = 0f
            var ny = 0f
            for (k in x.indices) {
                dot += x[k] * y[k]; nx += x[k] * x[k]; ny += y[k] * y[k]
            }
            if (nx == 0f || ny == 0f) return 1f
            return 1f - dot / sqrt(nx * ny)
        }
    }
}

/** How strict activation is; both checks scale together. */
enum class Sensitivity(
    val keywordScale: Float,
    val speakerOffset: Float,
    /** Added to the neural detector's score threshold. */
    val neuralOffset: Float = 0f,
) {
    STRICT(0.8f, 0.05f, 0.05f),
    NORMAL(1.0f, 0f, 0f),
    RELAXED(1.25f, -0.05f, -0.15f),
}
