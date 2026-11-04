package com.nexa.assistant

import android.content.Context
import com.nexa.assistant.engine.WakeHead
import org.json.JSONObject

/**
 * The wake phrases that have a real acoustic model installed. A phrase is
 * only listed as installed when its trained head file is bundled next to
 * `phrases.json`; there is no way to "type" a new phrase: a new phrase
 * needs a trained head (tools/wake_training) added here.
 */
internal object WakePhraseCatalog {
    const val DEFAULT_ID = "yaameer"
    private const val DIR = "nexa_assistant/wake"

    data class Entry(
        val id: String,
        val label: String,
        val head: String,
        val threshold: Float,
        val hits: Int,
        val installed: Boolean,
    )

    fun entries(context: Context): List<Entry> = try {
        val text = context.assets.open("$DIR/phrases.json").bufferedReader().use { it.readText() }
        val list = JSONObject(text).getJSONArray("phrases")
        val files = context.assets.list(DIR)?.toSet() ?: emptySet()
        (0 until list.length()).map { i ->
            val o = list.getJSONObject(i)
            val head = o.getString("head")
            Entry(
                o.getString("id"), o.getString("label"), head,
                o.optDouble("threshold", 0.9).toFloat(), o.optInt("hits", 2),
                head in files,
            )
        }
    } catch (e: Throwable) {
        emptyList()
    }

    fun find(context: Context, id: String): Entry? = entries(context).firstOrNull { it.id == id && it.installed }

    /** True when at least one phrase can run on this build. */
    fun available(context: Context) = entries(context).any { it.installed }

    fun loadHead(context: Context, e: Entry): WakeHead? = try {
        WakeHead.parse(context.assets.open("$DIR/${e.head}").use { it.readBytes() })
    } catch (t: Throwable) {
        null
    }
}
