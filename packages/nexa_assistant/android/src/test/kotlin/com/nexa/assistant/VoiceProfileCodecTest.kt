package com.nexa.assistant

import com.nexa.assistant.engine.SpeakerProfile
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/** The profile file format: a voice profile must be savable without a legacy wake template. */
class VoiceProfileCodecTest {
    private fun speaker() = SpeakerProfile(
        floatArrayOf(0.6f, 0.8f), 0.55f, listOf(floatArrayOf(1f, 0f), floatArrayOf(0f, 1f)),
    )

    @Test
    fun aVoiceProfileWithoutAWakeTemplateRoundTrips() {
        val bytes = VoiceProfileStore.encode(VoiceProfile(null, speaker(), 123L))
        val back = assertNotNull(VoiceProfileStore.decode(bytes))
        assertNull(back.phrase)
        assertEquals(123L, back.createdAt)
        val s = assertNotNull(back.speaker)
        assertEquals(0.55f, s.threshold)
        assertEquals(2, s.samples.size)
        assertTrue(s.embedding.contentEquals(floatArrayOf(0.6f, 0.8f)))
    }

    @Test
    fun aProfileWithoutASpeakerRoundTrips() {
        val back = assertNotNull(VoiceProfileStore.decode(VoiceProfileStore.encode(VoiceProfile(null, null, 1L))))
        assertNull(back.speaker)
    }
}
