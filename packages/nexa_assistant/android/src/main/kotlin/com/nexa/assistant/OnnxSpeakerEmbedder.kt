package com.nexa.assistant

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import android.content.Context
import com.nexa.assistant.engine.FilterBank
import com.nexa.assistant.engine.SpeakerEmbedder
import com.nexa.assistant.engine.subtractMean
import java.io.Closeable
import java.nio.FloatBuffer

/**
 * Speaker embeddings on the device with the bundled 3D-Speaker CAM++ model
 * (80-bin filterbank, mean-normalised → 512 values). Runs only on an
 * utterance that already matched the wake phrase.
 */
internal class OnnxSpeakerEmbedder private constructor(
    private val env: OrtEnvironment,
    private val session: OrtSession,
) : SpeakerEmbedder, Closeable {
    private val bank = FilterBank()
    private val input = session.inputNames.first()

    @Synchronized
    override fun embed(samples: FloatArray): FloatArray? {
        val features = bank.compute(samples)
        if (features.size < 30) return null // under ~0.3 s
        subtractMean(features)
        val flat = FloatBuffer.allocate(features.size * bank.numBins)
        for (row in features) flat.put(row)
        flat.rewind()
        return OnnxTensor.createTensor(
            env, flat, longArrayOf(1, features.size.toLong(), bank.numBins.toLong()),
        ).use { tensor ->
            session.run(mapOf(input to tensor)).use { result ->
                @Suppress("UNCHECKED_CAST")
                (result[0].value as Array<FloatArray>)[0]
            }
        }
    }

    override fun close() = session.close()

    companion object {
        const val ASSET_DIR = "nexa_assistant"
        const val ASSET_NAME = "speaker_campplus_voxceleb_16k.onnx"
        const val MODEL_ID = "3d-speaker-campplus-voxceleb-16k"

        fun available(context: Context): Boolean =
            runCatching { context.assets.list(ASSET_DIR)?.contains(ASSET_NAME) == true }
                .getOrDefault(false)

        /** Null when the model is not bundled or cannot be loaded. */
        fun load(context: Context): OnnxSpeakerEmbedder? {
            if (!available(context)) return null
            return try {
                val bytes = context.assets.open("$ASSET_DIR/$ASSET_NAME").use { it.readBytes() }
                val env = OrtEnvironment.getEnvironment()
                val opts = OrtSession.SessionOptions().apply { setIntraOpNumThreads(2) }
                OnnxSpeakerEmbedder(env, env.createSession(bytes, opts))
            } catch (e: Throwable) {
                null
            }
        }
    }
}
