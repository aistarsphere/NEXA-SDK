package com.nexa.assistant.engine

import kotlin.math.abs
import kotlin.math.log10
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.min
import kotlin.math.sqrt

/**
 * Objective measurements of one recorded clip (numbers only; no audio kept
 * here). Used to accept or redo a take in the guided voice setup and to
 * label what the clip really contains, so loudness and noise are measured
 * rather than trusted from the prompt.
 */
data class ClipMetrics(
    val durationMs: Int,
    val peakDb: Float,
    val speechRmsDb: Float,
    val noiseDb: Float,
    val snrDb: Float,
    val clippedFraction: Float,
    val speechStartMs: Int,
    val speechEndMs: Int,
    val speechFrames: Int = 0,
) {
    val speechMs: Int get() = max(0, speechEndMs - speechStartMs)
}

/** What a prompt expects, so a quiet take is not rejected for being quiet. */
data class ClipExpectation(
    val minPeakDb: Float = -38f,
    val minSpeechMs: Int = 400,
    val maxSpeechMs: Int = 4500,
    val minSnrDb: Float = 8f,
)

object ClipQuality {
    const val SAMPLE_RATE = 16000
    private const val FRAME = 160 // 10 ms

    fun db(x: Float): Float = 20f * log10(max(x, 1e-6f))

    fun analyze(samples: FloatArray): ClipMetrics {
        val frames = samples.size / FRAME
        if (frames == 0) return ClipMetrics(0, -120f, -120f, -120f, 0f, 0f, 0, 0)
        val rms = FloatArray(frames) { i ->
            var s = 0f
            for (k in 0 until FRAME) { val v = samples[i * FRAME + k]; s += v * v }
            sqrt(s / FRAME)
        }
        var peak = 0f
        var clipped = 0
        for (v in samples) {
            val a = abs(v)
            if (a > peak) peak = a
            if (a >= 0.99f) clipped++
        }
        val sorted = rms.sortedArray()
        val noise = sorted[(frames * 0.2f).toInt().coerceIn(0, frames - 1)]
        val noiseDb = db(noise)
        // Speech frames: 10 dB over the noise floor and not near-silent.
        val gate = max(noise * 1.5f, 0.002f) // 3.5 dB: keeps speech inside heavy noise
        var first = -1
        var last = -1
        var sum = 0f
        var n = 0
        for (i in 0 until frames) if (rms[i] >= gate) {
            if (first < 0) first = i
            last = i
            sum += rms[i] * rms[i]; n++
        }
        val speechRms = if (n > 0) sqrt(sum / n) else 0f
        // Speech power with the noise power removed (a noisy take is not louder speech).
        val clean = max(speechRms * speechRms - noise * noise, 1e-12f)
        val snr = 10f * log10(clean / max(noise * noise, 1e-12f))
        return ClipMetrics(
            durationMs = samples.size * 1000 / SAMPLE_RATE,
            peakDb = db(peak),
            speechRmsDb = db(speechRms),
            noiseDb = noiseDb,
            snrDb = snr,
            clippedFraction = clipped.toFloat() / samples.size,
            speechStartMs = if (first < 0) 0 else first * 10,
            speechEndMs = if (last < 0) 0 else (last + 1) * 10,
            speechFrames = n,
        )
    }

    /** Null when the take is usable; else a reason code the UI explains. */
    fun problem(m: ClipMetrics, e: ClipExpectation): String? {
        if (m.speechFrames < 12 || m.speechMs < 120) return "no_speech"
        if (m.speechMs < e.minSpeechMs) return "too_short"
        if (m.speechMs > e.maxSpeechMs) return "too_long"
        if (m.clippedFraction > 0.005f) return "clipped"
        if (m.peakDb < e.minPeakDb) return "too_quiet"
        if (m.snrDb < e.minSnrDb) return "too_noisy"
        return null
    }

    /**
     * Scales speech to a fixed level before it goes to the speaker model, so
     * whispering and shouting reach it alike (the model's mean-normalised
     * features cancel most gain, not all). Capped so noise is not blown up.
     */
    fun normalizeLevel(samples: FloatArray, targetRms: Float = 0.06f, maxGain: Float = 20f): FloatArray {
        val m = analyze(samples)
        val rms = 10f.pow(m.speechRmsDb / 20f)
        if (rms < 1e-4f) return samples
        val g = min(maxGain, targetRms / rms)
        return FloatArray(samples.size) { (samples[it] * g).coerceIn(-1f, 1f) }
    }

    /** The audio worth keeping: the speech with [padMs] of room either side. */
    fun trim(samples: FloatArray, m: ClipMetrics, padMs: Int = 500): FloatArray {
        val from = max(0, (m.speechStartMs - padMs) * SAMPLE_RATE / 1000)
        val to = min(samples.size, (m.speechEndMs + padMs) * SAMPLE_RATE / 1000)
        return if (to > from) samples.copyOfRange(from, to) else samples
    }
}
