package com.nexa.assistant

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import com.nexa.assistant.engine.WakeFeatures
import java.io.Closeable
import java.nio.FloatBuffer

/**
 * openWakeWord's two feature extractors (Apache-2.0): a mel spectrogram and
 * Google's speech embedding (96 values per 76 mel frames). Shipped as assets;
 * the trained phrase heads are separate small files (see [WakePhraseCatalog]).
 */
internal class OnnxWakeFeatures private constructor(
    private val env: OrtEnvironment,
    private val melSession: OrtSession,
    private val embSession: OrtSession,
) : WakeFeatures, Closeable {
    private val melIn = melSession.inputNames.first()
    private val embIn = embSession.inputNames.first()

    override fun mel(samples: FloatArray): Array<FloatArray> {
        val t = OnnxTensor.createTensor(env, FloatBuffer.wrap(samples), longArrayOf(1, samples.size.toLong()))
        return t.use {
            melSession.run(mapOf(melIn to it)).use { r ->
                @Suppress("UNCHECKED_CAST")
                val v = r[0].value as Array<Array<Array<FloatArray>>> // 1 x 1 x frames x 32
                Array(v[0][0].size) { f -> FloatArray(32) { k -> v[0][0][f][k] / 10f + 2f } }
            }
        }
    }

    override fun embed(frames: Array<FloatArray>): FloatArray {
        val flat = FloatBuffer.allocate(76 * 32)
        for (row in frames) flat.put(row)
        flat.rewind()
        val t = OnnxTensor.createTensor(env, flat, longArrayOf(1, 76, 32, 1))
        return t.use {
            embSession.run(mapOf(embIn to it)).use { r ->
                @Suppress("UNCHECKED_CAST")
                (r[0].value as Array<Array<Array<FloatArray>>>)[0][0][0] // 1 x 1 x 1 x 96
            }
        }
    }

    override fun close() {
        melSession.close(); embSession.close()
    }

    companion object {
        const val DIR = "nexa_assistant/wake"

        fun load(context: Context): OnnxWakeFeatures? = try {
            val env = OrtEnvironment.getEnvironment()
            val opts = { OrtSession.SessionOptions().apply { setIntraOpNumThreads(1) } }
            fun bytes(n: String) = context.assets.open("$DIR/$n").use { it.readBytes() }
            OnnxWakeFeatures(
                env,
                env.createSession(bytes("melspectrogram.onnx"), opts()),
                env.createSession(bytes("embedding_model.onnx"), opts()),
            )
        } catch (e: Throwable) {
            null
        }
    }
}
