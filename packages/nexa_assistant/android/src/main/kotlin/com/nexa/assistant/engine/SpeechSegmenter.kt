package com.nexa.assistant.engine

import kotlin.math.log10
import kotlin.math.max

/**
 * Energy-based speech detector on 10 ms chunks of 16 kHz audio. Emits each
 * isolated utterance (with a short lead-in) once it is followed by a pause.
 * Utterances longer than [maxMs] are dropped: the wake phrase is said on
 * its own, not inside a long sentence.
 *
 * Cheap enough to run continuously; everything heavier only runs on the
 * segments it emits.
 */
class SpeechSegmenter(
    private val minMs: Int = 300,
    private val maxMs: Int = 2500,
    /** Quiet needed to end an utterance: long enough not to split «يا | لبيب». */
    private val hangoverMs: Int = 600,
    private val leadInMs: Int = 150,
    /** Speech must be this many dB above the tracked noise floor. */
    private val marginDb: Double = 10.0,
    /** And above this absolute level (dBFS), so silence never triggers. */
    private val minLevelDb: Double = -55.0,
    private val onSegment: (FloatArray) -> Unit,
) {
    companion object {
        const val CHUNK = 160
    }

    private val chunk = FloatArray(CHUNK)
    private var filled = 0

    private val lead = ArrayDeque<FloatArray>()
    private val leadChunks = leadInMs / 10
    private val current = ArrayList<FloatArray>()
    private var inSpeech = false
    private var voicedRun = 0
    private var silentRun = 0
    private var noiseDb = Double.NaN

    /** Current noise floor estimate in dBFS (diagnostics). */
    val noiseFloorDb: Double get() = noiseDb

    fun accept(samples: FloatArray, count: Int = samples.size) {
        var i = 0
        while (i < count) {
            val n = minOf(CHUNK - filled, count - i)
            System.arraycopy(samples, i, chunk, filled, n)
            filled += n
            i += n
            if (filled == CHUNK) {
                process(chunk.copyOf())
                filled = 0
            }
        }
    }

    /** Forgets any partial utterance (e.g. after a pause in listening). */
    fun reset() {
        lead.clear()
        current.clear()
        inSpeech = false
        voicedRun = 0
        silentRun = 0
        filled = 0
    }

    private fun process(c: FloatArray) {
        var e = 0.0
        for (s in c) e += s * s
        val db = 10 * log10(e / CHUNK + 1e-10)
        if (noiseDb.isNaN()) noiseDb = db
        val voiced = db > max(noiseDb + marginDb, minLevelDb)
        // Floor follows quiet chunks quickly and loud ones very slowly.
        noiseDb += if (db < noiseDb) 0.3 * (db - noiseDb)
        else if (!voiced) 0.02 * (db - noiseDb)
        else 0.001 * (db - noiseDb)

        if (!inSpeech) {
            lead.addLast(c)
            if (lead.size > leadChunks + 3) lead.removeFirst()
            voicedRun = if (voiced) voicedRun + 1 else 0
            if (voicedRun >= 3) {
                inSpeech = true
                silentRun = 0
                current.clear()
                current.addAll(lead)
                lead.clear()
            }
            return
        }
        current.add(c)
        silentRun = if (voiced) 0 else silentRun + 1
        if (current.size * 10 > maxMs + hangoverMs + leadInMs) {
            // Too long for a wake phrase: wait for the speaker to pause.
            current.clear()
            inSpeech = silentRun < hangoverMs / 10
            if (!inSpeech) voicedRun = 0
            return
        }
        if (silentRun >= hangoverMs / 10) {
            val keep = current.size - silentRun + 5 // a little tail
            val speechMs = (current.size - silentRun) * 10
            if (speechMs >= minMs) {
                val out = FloatArray(keep * CHUNK)
                for (k in 0 until keep) {
                    System.arraycopy(current[k], 0, out, k * CHUNK, CHUNK)
                }
                onSegment(out)
            }
            current.clear()
            inSpeech = false
            voicedRun = 0
        }
    }
}
