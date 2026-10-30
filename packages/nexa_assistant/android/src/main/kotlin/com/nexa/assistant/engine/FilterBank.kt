package com.nexa.assistant.engine

import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Kaldi-compatible log-mel filterbank at 16 kHz: 25 ms frames every 10 ms,
 * DC removal, pre-emphasis 0.97, povey window, 512-point FFT, no dither,
 * `snip_edges`. These are the features the speaker model was trained on;
 * [mfcc] derives the compact features used to match the wake phrase.
 *
 * Input samples are floats in [-1, 1].
 */
class FilterBank(
    val numBins: Int = 80,
    lowFreq: Double = 20.0,
    highFreq: Double = SAMPLE_RATE / 2.0,
) {
    companion object {
        const val SAMPLE_RATE = 16000
        const val FRAME = 400
        const val SHIFT = 160
        private const val FFT = 512
        private const val HALF = FFT / 2
        private const val EPS = 1.1920929e-7

        fun frameCount(samples: Int): Int =
            if (samples < FRAME) 0 else 1 + (samples - FRAME) / SHIFT

        private fun mel(f: Double) = 1127.0 * ln(1.0 + f / 700.0)
    }

    private val window = DoubleArray(FRAME) { i ->
        (0.5 - 0.5 * cos(2.0 * PI * i / (FRAME - 1))).pow(0.85)
    }

    /** Per mel bin: first FFT bin and its triangular weights. */
    private val offsets = IntArray(numBins)
    private val weights: Array<DoubleArray>

    private val fft = Fft(FFT)
    private val re = DoubleArray(FFT)
    private val im = DoubleArray(FFT)
    private val power = DoubleArray(HALF)

    init {
        val binWidth = SAMPLE_RATE.toDouble() / FFT
        val melLow = mel(lowFreq)
        val melHigh = mel(highFreq)
        val delta = (melHigh - melLow) / (numBins + 1)
        weights = Array(numBins) { b ->
            val left = melLow + b * delta
            val center = left + delta
            val right = center + delta
            var first = -1
            var last = -1
            val w = DoubleArray(HALF)
            for (i in 0 until HALF) {
                val m = mel(binWidth * i)
                if (m > left && m < right) {
                    w[i] = if (m <= center) (m - left) / (center - left)
                    else (right - m) / (right - center)
                    if (first < 0) first = i
                    last = i
                }
            }
            offsets[b] = max(first, 0)
            if (first < 0) DoubleArray(0) else w.copyOfRange(first, last + 1)
        }
    }

    /** `frames x numBins` log-mel energies. */
    fun compute(samples: FloatArray): Array<FloatArray> {
        val n = frameCount(samples.size)
        return Array(n) { f -> frame(samples, f * SHIFT) }
    }

    private fun frame(samples: FloatArray, start: Int): FloatArray {
        var mean = 0.0
        for (i in 0 until FRAME) mean += samples[start + i]
        mean /= FRAME
        for (i in 0 until FRAME) re[i] = samples[start + i] - mean
        for (i in FRAME - 1 downTo 1) re[i] -= 0.97 * re[i - 1]
        re[0] -= 0.97 * re[0]
        for (i in 0 until FRAME) re[i] *= window[i]
        for (i in FRAME until FFT) re[i] = 0.0
        im.fill(0.0)
        fft.transform(re, im)
        for (k in 0 until HALF) power[k] = re[k] * re[k] + im[k] * im[k]
        return FloatArray(numBins) { b ->
            val w = weights[b]
            val o = offsets[b]
            var e = 0.0
            for (j in w.indices) e += w[j] * power[o + j]
            ln(max(e, EPS)).toFloat()
        }
    }

    /**
     * MFCCs from the log-mel energies: orthonormal DCT-II, coefficients
     * 1..[count] (energy term dropped), mean-normalised over the utterance.
     */
    fun mfcc(logMel: Array<FloatArray>, count: Int = 13): Array<FloatArray> {
        val dct = Array(count) { k ->
            val c = k + 1
            DoubleArray(numBins) { m ->
                sqrt(2.0 / numBins) * cos(PI * c * (m + 0.5) / numBins)
            }
        }
        val out = Array(logMel.size) { t ->
            FloatArray(count) { k ->
                var s = 0.0
                val row = logMel[t]
                val d = dct[k]
                for (m in 0 until numBins) s += d[m] * row[m]
                s.toFloat()
            }
        }
        subtractMean(out)
        return out
    }
}

/** Removes the per-dimension mean over time (in place). */
fun subtractMean(features: Array<FloatArray>) {
    if (features.isEmpty()) return
    val dims = features[0].size
    for (d in 0 until dims) {
        var s = 0.0
        for (row in features) s += row[d]
        val m = (s / features.size).toFloat()
        for (row in features) row[d] -= m
    }
}

/** In-place iterative radix-2 complex FFT of a fixed power-of-two size. */
internal class Fft(private val n: Int) {
    private val cosT = DoubleArray(n / 2) { cos(2.0 * PI * it / n) }
    private val sinT = DoubleArray(n / 2) { -kotlin.math.sin(2.0 * PI * it / n) }

    fun transform(re: DoubleArray, im: DoubleArray) {
        var j = 0
        for (i in 1 until n) {
            var bit = n shr 1
            while (j and bit != 0) {
                j = j xor bit
                bit = bit shr 1
            }
            j = j xor bit
            if (i < j) {
                var t = re[i]; re[i] = re[j]; re[j] = t
                t = im[i]; im[i] = im[j]; im[j] = t
            }
        }
        var len = 2
        while (len <= n) {
            val step = n / len
            val half = len / 2
            var i = 0
            while (i < n) {
                for (k in 0 until half) {
                    val wr = cosT[k * step]
                    val wi = sinT[k * step]
                    val a = i + k
                    val b = a + half
                    val xr = re[b] * wr - im[b] * wi
                    val xi = re[b] * wi + im[b] * wr
                    re[b] = re[a] - xr
                    im[b] = im[a] - xi
                    re[a] += xr
                    im[a] += xi
                }
                i += len
            }
            len = len shl 1
        }
    }
}
