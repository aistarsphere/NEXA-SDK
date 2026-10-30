package com.nexa.assistant

import android.content.Context
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * The host's single Flutter engine, shared by its activity and the
 * assistant panel so both show the same app state, voice call and tools.
 * Hosts return [obtain] from `FlutterActivity.provideFlutterEngine` and
 * `false` from `shouldDestroyEngineWithHost`.
 */
object NexaAssistantEngine {
    const val ENGINE_ID = "nexa_assistant_engine"

    fun obtain(context: Context): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val engine = FlutterEngine(context.applicationContext)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    internal fun current(): FlutterEngine? = FlutterEngineCache.getInstance().get(ENGINE_ID)
}

/** Panel placement, chosen by the user. */
internal enum class PanelPosition { BOTTOM, TOP, LEFT, RIGHT }

/**
 * Links the assistant session window with the Flutter side: which surface
 * Dart should render (`panel` or `hidden`), and why it was hidden.
 */
internal object PanelBridge {
    @Volatile
    var emitter: ((Map<String, Any?>) -> Unit)? = null

    /** The host activity's Flutter view, if the activity exists. */
    @Volatile
    var hostView: (() -> FlutterView?)? = null

    @Volatile
    var state: Map<String, Any?> = hidden("none")
        private set

    /** Set by the plugin before hiding for an expand or a host close. */
    @Volatile
    var nextHideReason: String? = null

    fun shown(a: Activation, position: PanelPosition) = publish(
        mapOf(
            "type" to "surface",
            "surface" to "panel",
            "position" to position.name.lowercase(),
            "source" to a.source,
            "verified" to a.verified,
        ),
    )

    fun hiddenNow() {
        val reason = nextHideReason ?: "dismissed"
        nextHideReason = null
        publish(hidden(reason))
    }

    private fun hidden(reason: String) =
        mapOf("type" to "surface", "surface" to "hidden", "reason" to reason)

    private fun publish(m: Map<String, Any?>) {
        state = m
        emitter?.invoke(m)
    }
}
