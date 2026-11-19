package com.nexa.assistant.engine

import kotlin.math.max
import kotlin.math.min

/**
 * Chooses the owner-verification threshold from measured scores instead of
 * a fixed number. Owner scores come from leave-one-out (each enrolment
 * sample scored against a profile of the others); stranger scores come from
 * consented guest recordings when there are any.
 *
 * Without guests only the false-rejection side is measured, so the result is
 * labelled `owner_only` and must not be read as a false-acceptance claim.
 */
object SpeakerCalibration {
    data class Result(
        val threshold: Float,
        val mode: String,            // owner_only | with_guests
        val ownerP05: Float,
        val ownerMedian: Float,
        val impostorMax: Float?,
        val impostorP99: Float?,
        val separable: Boolean,
        val ownerSamples: Int,
        val impostorSamples: Int,
    )

    const val MIN_OWNER = 6
    /**
     * Strangers' 99th-percentile score with the bundled CAM++ and the app's
     * scoring on 19 real LibriSpeech speakers (tools/wake_training/
     * speaker_benchmark.py): 0.45-0.47 for normal speech. An owner-only
     * profile never goes under this + a margin.
     */
    const val STRANGER_P99_PRIOR = 0.47f
    private const val FLOOR = 0.40f
    private const val CEIL = 0.80f

    fun calibrate(owner: List<FloatArray>, impostors: List<FloatArray>): Result {
        require(owner.size >= MIN_OWNER) { "need at least $MIN_OWNER owner samples" }
        val loo = owner.indices.map { i ->
            val rest = owner.filterIndexed { j, _ -> j != i }
            profile(rest).score(owner[i])
        }.sorted()
        val p05 = percentile(loo, 0.05f)
        val median = percentile(loo, 0.5f)
        if (impostors.isEmpty()) {
            val floor = STRANGER_P99_PRIOR + 0.02f
            val t = (p05 - 0.10f).coerceIn(floor, 0.65f)
            // The owner's own low scores sit about at stranger level: not reliably separable.
            return Result(t, "owner_only", p05, median, null, null, p05 - 0.05f >= floor, owner.size, 0)
        }
        val all = profile(owner)
        val imp = impostors.map { all.score(it) }.sorted()
        val impMax = imp.last()
        val impP99 = percentile(imp, 0.99f)
        val gap = p05 - impMax
        val t = if (gap > 0.04f) impMax + 0.4f * gap
        else min(CEIL, max(FLOOR, impMax + 0.02f))
        return Result(
            t.coerceIn(FLOOR, CEIL), "with_guests", p05, median, impMax, impP99,
            gap > 0.04f, owner.size, impostors.size,
        )
    }

    /** Each sample scored against a profile built from the others. */
    fun looScores(owner: List<FloatArray>): List<Float> = owner.indices.map { i ->
        profile(owner.filterIndexed { j, _ -> j != i }).score(owner[i])
    }

    /**
     * Drops takes that do not look like the owner's other takes (a cough, a
     * second voice, a clipped or very noisy take that slipped through): the
     * leave-one-out score is more than 3 robust deviations under the median.
     * Never drops more than a fifth, and never goes under [minKeep].
     * Returns the kept embeddings and how many were dropped.
     */
    fun trimOutliers(owner: List<FloatArray>, minKeep: Int = MIN_OWNER): Pair<List<FloatArray>, Int> {
        if (owner.size <= minKeep) return owner to 0
        val loo = looScores(owner)
        val sorted = loo.sorted()
        val median = percentile(sorted, 0.5f)
        val mad = percentile(loo.map { kotlin.math.abs(it - median) }.sorted(), 0.5f) * 1.4826f
        val cut = median - 3f * max(mad, 0.03f)
        val worst = loo.withIndex().filter { it.value < cut }.sortedBy { it.value }
            .take(min(owner.size / 5, owner.size - minKeep)).map { it.index }.toSet()
        return owner.filterIndexed { i, _ -> i !in worst } to worst.size
    }

    /** Below this the takes do not agree with each other: more (cleaner) ones are needed. */
    const val MIN_CONSISTENCY_MEDIAN = 0.55f

    fun profile(samples: List<FloatArray>): SpeakerProfile = SpeakerProfile.fromEmbeddings(samples)

    private fun percentile(sorted: List<Float>, p: Float): Float {
        if (sorted.isEmpty()) return 0f
        val idx = (p * (sorted.size - 1))
        val lo = idx.toInt()
        val hi = min(sorted.size - 1, lo + 1)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo)
    }
}

/**
 * A short utterance carries less identity: on real speech the owner's median
 * score falls 0.85 -> 0.60 -> 0.52 for long, 1 s and 0.7 s speech while
 * strangers' p99 falls only 0.46 -> 0.40 -> 0.37. The acceptance threshold
 * therefore follows the length of the speech that was verified, instead of
 * pretending one number fits both a sentence and the wake phrase.
 */
object LengthAwareThreshold {
    /** [base] is the calibrated threshold for normal (2.5 s or longer) speech. */
    fun forSpeech(base: Float, speechMs: Int): Float {
        val penalty = when {
            speechMs >= 2500 -> 0f
            speechMs >= 1000 -> 0.07f * (2500 - speechMs) / 1500f
            speechMs >= 700 -> 0.07f + 0.05f * (1000 - speechMs) / 300f
            else -> 0.12f
        }
        return base - penalty
    }

    /** Scores this far under the threshold are "uncertain" (offer the manual path), not rejected outright. */
    const val UNCERTAIN_BAND = 0.08f
}
