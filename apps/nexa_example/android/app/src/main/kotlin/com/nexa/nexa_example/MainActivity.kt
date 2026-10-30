package com.nexa.nexa_example

import android.content.Context
import com.nexa.assistant.NexaAssistantEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * Uses the engine shared with the assistant panel: reopening the app or
 * expanding the panel continues the same app state, conversation and call
 * instead of starting the app from scratch.
 */
class MainActivity : FlutterActivity() {
    override fun provideFlutterEngine(context: Context): FlutterEngine =
        NexaAssistantEngine.obtain(context)

    override fun shouldDestroyEngineWithHost(): Boolean = false
}
