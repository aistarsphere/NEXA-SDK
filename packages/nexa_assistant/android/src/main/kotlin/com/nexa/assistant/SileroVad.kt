package com.nexa.assistant

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import com.nexa.assistant.engine.SpeechProbability
import java.io.Closeable
import java.nio.FloatBuffer

/**
 * Silero VAD v5 (MIT, 2.3 MB): a small neural speech detector, far more
 * robust to room noise than an energy threshold. One call per 512-sample
 * (32 ms) frame at 16 kHz, with the model's recurrent state and a 64-sample
 * context carried between frames.
 */
internal class SileroVad private constructor(
    private val env: OrtEnvironment,
    private val session: OrtSession,
) : SpeechProbability, Closeable {
    private var state = FloatArray(2 * 128)
    private val ctx = FloatArray(CONTEXT)

    override fun probability(frame: FloatArray): Float {
        val input = FloatArray(CONTEXT + frame.size)
        System.arraycopy(ctx, 0, input, 0, CONTEXT)
        System.arraycopy(frame, 0, input, CONTEXT, frame.size)
        val inT = OnnxTensor.createTensor(env, FloatBuffer.wrap(input), longArrayOf(1, input.size.toLong()))
        val stT = OnnxTensor.createTensor(env, FloatBuffer.wrap(state), longArrayOf(2, 1, 128))
        val srT = OnnxTensor.createTensor(env, java.nio.LongBuffer.wrap(longArrayOf(16000L)), longArrayOf())
        return try {
            session.run(mapOf("input" to inT, "state" to stT, "sr" to srT)).use { r ->
                @Suppress("UNCHECKED_CAST")
                val p = (r[0].value as Array<FloatArray>)[0][0]
                @Suppress("UNCHECKED_CAST")
                val s = r[1].value as Array<Array<FloatArray>>
                for (i in 0 until 2) System.arraycopy(s[i][0], 0, state, i * 128, 128)
                System.arraycopy(frame, frame.size - CONTEXT, ctx, 0, CONTEXT)
                p
            }
        } finally {
            inT.close(); stT.close(); srT.close()
        }
    }

    override fun reset() {
        state = FloatArray(2 * 128)
        ctx.fill(0f)
    }

    override fun close() = session.close()

    companion object {
        private const val CONTEXT = 64
        const val ASSET = "nexa_assistant/vad/silero_vad.onnx"

        /** Null when the model is not bundled or cannot load (the caller falls back). */
        fun load(context: Context): SileroVad? = try {
            val env = OrtEnvironment.getEnvironment()
            val bytes = context.assets.open(ASSET).use { it.readBytes() }
            val opts = OrtSession.SessionOptions().apply { setIntraOpNumThreads(1) }
            SileroVad(env, env.createSession(bytes, opts))
        } catch (e: Throwable) {
            null
        }
    }
}
