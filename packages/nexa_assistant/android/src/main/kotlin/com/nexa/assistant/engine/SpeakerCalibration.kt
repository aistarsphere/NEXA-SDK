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
            val t = (p05 - 0.10f).coerceIn(FLOOR, 0.65f)
            return Result(t, "owner_only", p05, median, null, null, true, owner.size, 0)
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

    fun profile(samples: List<FloatArray>): SpeakerProfile = SpeakerProfile.fromEmbeddings(samples)

    private fun percentile(sorted: List<Float>, p: Float): Float {
        if (sorted.isEmpty()) return 0f
        val idx = (p * (sorted.size - 1))
        val lo = idx.toInt()
        val hi = min(sorted.size - 1, lo + 1)
        return sorted[lo] + (sorted[hi] - sorted[lo]) * (idx - lo)
    }
}
