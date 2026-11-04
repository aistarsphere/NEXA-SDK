package com.nexa.assistant.engine

/**
 * The decision rule of the quick voice setup. It replaces a fixed number of
 * recordings with evidence: after one natural sentence, a DIFFERENT sentence
 * is checked against it; more speech is asked for only when that check is not
 * conclusive.
 *
 * The numbers come from tools/wake_training/enroll_policy_benchmark.py (real
 * speech, 19 LibriSpeech speakers, English, 3-6 s enrolment sentence, 2-4 s
 * verification sentence, clean / quiet / babble / far-field):
 *   genuine median 0.54-0.70, 5th percentile 0.33-0.49;
 *   stranger 99th percentile 0.38-0.41, largest ever seen 0.52-0.54 (n=1).
 * A match of at least [STRONG] is above every stranger in that data. It is
 * NOT Iraqi-Arabic or owner accuracy, so the result is always "provisional".
 */
object EnrollmentPolicy {
    /** Verification score that no stranger reached in the benchmark. */
    const val STRONG = 0.58f

    /** Lowest score still consistent with the same voice in a noisy take. */
    const val WEAK = 0.45f

    /** Live acceptance threshold for sentence-length speech; shorter speech is scaled down by [LengthAwareThreshold]. */
    const val ACCEPT = 0.50f

    /** Takes allowed in total (enrol + verify + extras) before giving up. */
    const val MAX_TAKES = 4

    const val MIN_SPEECH_MS = 2000
    const val MIN_SNR_DB = 8f

    enum class Verdict { READY, NEED_MORE, NEEDS_IMPROVEMENT }

    data class Decision(
        val verdict: Verdict,
        /** What to tell the person (a code, never a score). */
        val reason: String?,
        /** The embeddings that make up the profile (outliers dropped). */
        val profile: List<FloatArray>,
        val threshold: Float,
    )

    /** Null when the take is usable for identity, else why not. */
    fun takeProblem(m: ClipMetrics): String? {
        if (m.clippedFraction > 0.005f) return "clipped"
        if (m.speechMs < MIN_SPEECH_MS) return "too_short"
        if (m.snrDb < MIN_SNR_DB) return "too_noisy"
        if (m.peakDb < -45f) return "too_quiet"
        return null
    }

    /**
     * [pool] holds the accepted embeddings in order (the first is the
     * enrolment sentence), [takes] how many were recorded so far.
     */
    fun decide(pool: List<FloatArray>, takes: Int): Decision {
        require(pool.size >= 2) { "needs the enrolment and a verification take" }
        val (kept, _) = SpeakerCalibration.trimOutliers(pool, minKeep = 2)
        val last = pool.last()
        val prior = pool.dropLast(1)
        val score = SpeakerCalibration.profile(prior).score(last)
        val loo = SpeakerCalibration.looScores(kept).sorted()
        val median = if (loo.isEmpty()) score else loo[loo.size / 2]

        if (takes <= 2) {
            return when {
                score >= STRONG -> ready(pool)
                score >= WEAK -> need("not_sure", pool)
                else -> need("different_voice", pool)
            }
        }
        // After an extra sample the profile has 3+ takes: they must agree with each other.
        return when {
            kept.size >= 3 && median >= ACCEPT -> ready(kept)
            takes >= MAX_TAKES -> Decision(Verdict.NEEDS_IMPROVEMENT, "not_consistent", kept, ACCEPT)
            else -> need(if (score < WEAK) "different_voice" else "not_sure", pool)
        }
    }

    private fun ready(profile: List<FloatArray>) = Decision(Verdict.READY, null, profile, ACCEPT)

    private fun need(reason: String, pool: List<FloatArray>) = Decision(Verdict.NEED_MORE, reason, pool, ACCEPT)

    /** How to describe a live voice test result, without exposing a score. */
    fun describeTest(score: Float, threshold: Float): String = when {
        score >= threshold -> "match"
        score >= threshold - LengthAwareThreshold.UNCERTAIN_BAND -> "uncertain"
        else -> "different"
    }
}
