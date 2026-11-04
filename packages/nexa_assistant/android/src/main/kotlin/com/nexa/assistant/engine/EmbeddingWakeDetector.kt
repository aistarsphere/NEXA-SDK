package com.nexa.assistant.engine

/** The two feature models, behind an interface so the logic is testable. */
interface WakeFeatures {
    /** Mel frames (rows of 32, already x/10+2) for int16-scale [samples]. */
    fun mel(samples: FloatArray): Array<FloatArray>

    /** One 96-value embedding from 76 mel frames. */
    fun embed(frames: Array<FloatArray>): FloatArray
}

/**
 * Streaming wake-phrase detector: every 80 ms of microphone audio produces
 * one embedding; the last 16 are scored by [head]. A wake needs [hits]
 * consecutive windows at or above [threshold] (smooths a single noisy
 * frame), then a [refractoryMs] pause. Audio is only held in memory: the
 * last [TAIL_SECONDS] are kept so the owner check can look at the phrase.
 */
class EmbeddingWakeDetector(
    private val features: WakeFeatures,
    private val head: WakeHead,
    var threshold: Float = 0.9f,
    private val hits: Int = 2,
    private val refractoryMs: Long = 3000,
    private val clock: () -> Long = System::currentTimeMillis,
    private val onWake: (score: Float, tail: FloatArray) -> Unit,
) {
    private val context = FloatArray(CONTEXT)
    private var haveContext = false
    private val mel = ArrayDeque<FloatArray>()
    private val emb = ArrayDeque<FloatArray>()
    private val pending = FloatArray(CHUNK)
    private var pendingCount = 0
    private val tail = FloatArray(TAIL_SECONDS * SAMPLE_RATE)
    private var tailCount = 0
    private var run = 0
    private var best = 0f
    private var lastWakeAt = Long.MIN_VALUE / 2

    /** Latest window score (for diagnostics and the on-device benchmark). */
    var lastScore = 0f
        private set

    fun accept(samples: FloatArray, count: Int = samples.size) {
        var i = 0
        while (i < count) {
            val n = minOf(count - i, CHUNK - pendingCount)
            System.arraycopy(samples, i, pending, pendingCount, n)
            pendingCount += n
            i += n
            if (pendingCount == CHUNK) {
                process()
                pendingCount = 0
            }
        }
    }

    fun reset() {
        mel.clear(); emb.clear()
        haveContext = false
        pendingCount = 0; tailCount = 0; run = 0; best = 0f
    }

    private fun process() {
        remember(pending)
        // The feature models take int16-scale audio, with 480 samples of
        // left context so frame boundaries match the offline training.
        val input = FloatArray(CONTEXT + CHUNK)
        System.arraycopy(context, 0, input, 0, CONTEXT)
        for (k in 0 until CHUNK) input[CONTEXT + k] = pending[k] * 32767f
        for (k in 0 until CONTEXT) context[k] = pending[CHUNK - CONTEXT + k] * 32767f
        if (!haveContext) {
            haveContext = true
            return // the first chunk has no context: skip it
        }
        for (frame in features.mel(input)) mel.addLast(frame)
        while (mel.size > MEL_WINDOW) mel.removeFirst()
        if (mel.size < MEL_WINDOW) return
        emb.addLast(features.embed(mel.toTypedArray()))
        while (emb.size > WakeHead.WINDOW) emb.removeFirst()
        if (emb.size < WakeHead.WINDOW) return
        val flat = FloatArray(WakeHead.WINDOW * WakeHead.EMBEDDING)
        emb.forEachIndexed { r, e -> System.arraycopy(e, 0, flat, r * WakeHead.EMBEDDING, WakeHead.EMBEDDING) }
        val s = head.score(flat)
        lastScore = s
        if (s >= threshold) {
            run++
            if (s > best) best = s
            if (run >= hits) {
                val now = clock()
                if (now - lastWakeAt >= refractoryMs) {
                    lastWakeAt = now
                    onWake(best, tail.copyOf(tailCount))
                }
                run = 0; best = 0f
            }
        } else {
            run = 0; best = 0f
        }
    }

    private fun remember(chunk: FloatArray) {
        if (tailCount + CHUNK > tail.size) {
            val keep = tail.size - CHUNK
            System.arraycopy(tail, tailCount - keep, tail, 0, keep)
            tailCount = keep
        }
        System.arraycopy(chunk, 0, tail, tailCount, CHUNK)
        tailCount += CHUNK
    }

    companion object {
        const val SAMPLE_RATE = 16000
        const val CHUNK = 1280        // 80 ms
        const val CONTEXT = 480       // 3 mel hops of left context
        const val MEL_WINDOW = 76
        const val TAIL_SECONDS = 3
    }
}
