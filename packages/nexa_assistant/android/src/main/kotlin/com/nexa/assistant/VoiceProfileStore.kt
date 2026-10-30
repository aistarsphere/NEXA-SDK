package com.nexa.assistant

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.nexa.assistant.engine.SpeakerProfile
import com.nexa.assistant.engine.WakePhraseModel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** What enrolment keeps: features and a voice embedding, never audio. */
internal class VoiceProfile(
    val phrase: WakePhraseModel,
    val speaker: SpeakerProfile?,
    val createdAt: Long,
)

/**
 * The owner's voice profile on this device only: AES-GCM encrypted with a
 * non-exportable Android Keystore key, in the no-backup directory (never
 * part of a cloud backup). Deleting removes both the file and the key.
 */
internal class VoiceProfileStore(context: Context) {
    private val file = File(context.noBackupFilesDir, "nexa_assistant/voice_profile.bin")

    val exists: Boolean get() = file.exists()

    fun load(): VoiceProfile? {
        if (!file.exists()) return null
        return try {
            val bytes = file.readBytes()
            val cipher = Cipher.getInstance(TRANSFORM)
            cipher.init(Cipher.DECRYPT_MODE, key(create = false) ?: return null,
                GCMParameterSpec(128, bytes, 0, IV))
            decode(cipher.doFinal(bytes, IV, bytes.size - IV))
        } catch (e: Exception) {
            null
        }
    }

    fun save(profile: VoiceProfile) {
        val cipher = Cipher.getInstance(TRANSFORM)
        cipher.init(Cipher.ENCRYPT_MODE, key(create = true))
        val sealed = cipher.doFinal(encode(profile))
        file.parentFile?.mkdirs()
        val tmp = File(file.path + ".tmp")
        tmp.writeBytes(cipher.iv + sealed)
        if (!tmp.renameTo(file)) {
            file.delete()
            tmp.renameTo(file)
        }
    }

    fun delete() {
        file.delete()
        runCatching {
            val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
            if (ks.containsAlias(ALIAS)) ks.deleteEntry(ALIAS)
        }
    }

    private fun key(create: Boolean): SecretKey? {
        val ks = KeyStore.getInstance(KEYSTORE).apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        if (!create) return null
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        gen.init(
            KeyGenParameterSpec.Builder(
                ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return gen.generateKey()
    }

    private companion object {
        const val KEYSTORE = "AndroidKeyStore"
        const val ALIAS = "nexa_assistant_voice_profile"
        const val TRANSFORM = "AES/GCM/NoPadding"
        const val IV = 12
        const val VERSION = 1

        fun encode(p: VoiceProfile): ByteArray {
            val bytes = ByteArrayOutputStream()
            DataOutputStream(bytes).use { out ->
                out.writeInt(VERSION)
                out.writeLong(p.createdAt)
                out.writeFloat(p.phrase.threshold)
                out.writeInt(p.phrase.templates.size)
                for (t in p.phrase.templates) {
                    out.writeInt(t.size)
                    out.writeInt(if (t.isEmpty()) 0 else t[0].size)
                    for (row in t) for (v in row) out.writeFloat(v)
                }
                val s = p.speaker
                out.writeBoolean(s != null)
                if (s != null) {
                    out.writeFloat(s.threshold)
                    out.writeInt(s.embedding.size)
                    for (v in s.embedding) out.writeFloat(v)
                }
            }
            return bytes.toByteArray()
        }

        fun decode(data: ByteArray): VoiceProfile? {
            DataInputStream(ByteArrayInputStream(data)).use { inp ->
                if (inp.readInt() != VERSION) return null
                val createdAt = inp.readLong()
                val threshold = inp.readFloat()
                val templates = List(inp.readInt()) {
                    val frames = inp.readInt()
                    val dims = inp.readInt()
                    Array(frames) { FloatArray(dims) { inp.readFloat() } }
                }
                val speaker = if (inp.readBoolean()) {
                    val t = inp.readFloat()
                    SpeakerProfile(FloatArray(inp.readInt()) { inp.readFloat() }, t)
                } else null
                return VoiceProfile(WakePhraseModel(templates, threshold), speaker, createdAt)
            }
        }
    }
}
