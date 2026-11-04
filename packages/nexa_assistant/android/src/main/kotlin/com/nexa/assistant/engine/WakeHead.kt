package com.nexa.assistant.engine

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.exp

/**
 * The small trained classifier on top of the speech-embedding features: the
 * last [windowEmbeddings] x 96 values -> probability that the wake phrase
 * just ended. File format (little endian), written by
 * tools/wake_training/train.py:
 * `"AMRW" 0x01, int32 nIn, int32 nHidden, float32 mu[nIn], sd[nIn],
 * W1[nIn*nHidden] (input-major), b1[nHidden], W2[nHidden], b2`.
 */
class WakeHead(
    private val mu: FloatArray,
    private val sd: FloatArray,
    private val w1: FloatArray,
    private val b1: FloatArray,
    private val w2: FloatArray,
    private val b2: Float,
) {
    val nIn = mu.size
    private val nHidden = b1.size

    /** [features] is the flattened window (nIn values). */
    fun score(features: FloatArray): Float {
        require(features.size == nIn)
        val h = FloatArray(nHidden) { b1[it] }
        for (i in 0 until nIn) {
            val x = (features[i] - mu[i]) / sd[i]
            if (x == 0f) continue
            val base = i * nHidden
            for (j in 0 until nHidden) h[j] += x * w1[base + j]
        }
        var z = b2
        for (j in 0 until nHidden) if (h[j] > 0f) z += h[j] * w2[j]
        return (1.0 / (1.0 + exp(-z.toDouble()))).toFloat()
    }

    companion object {
        const val EMBEDDING = 96
        const val WINDOW = 16

        fun parse(bytes: ByteArray): WakeHead {
            require(bytes.size > 13 && bytes[0] == 'A'.code.toByte() && bytes[1] == 'M'.code.toByte() &&
                bytes[2] == 'R'.code.toByte() && bytes[3] == 'W'.code.toByte() && bytes[4].toInt() == 1) {
                "not a wake head"
            }
            val b = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
            b.position(5)
            val nIn = b.int
            val nHidden = b.int
            fun floats(n: Int) = FloatArray(n).also { b.asFloatBuffer().get(it); b.position(b.position() + n * 4) }
            val mu = floats(nIn)
            val sd = floats(nIn)
            val w1 = floats(nIn * nHidden)
            val b1 = floats(nHidden)
            val w2 = floats(nHidden)
            val b2 = floats(1)[0]
            return WakeHead(mu, sd, w1, b1, w2, b2)
        }
    }
}
