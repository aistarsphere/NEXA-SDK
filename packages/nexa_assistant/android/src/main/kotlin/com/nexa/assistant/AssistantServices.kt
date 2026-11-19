package com.nexa.assistant

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.ColorDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.service.voice.VoiceInteractionService
import android.service.voice.VoiceInteractionSession
import android.service.voice.VoiceInteractionSessionService
import android.speech.RecognitionService
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView

/**
 * Bound by Android while the user has chosen this app as the default
 * assistant. Deliberately light: it only opens sessions; the host app does
 * the work.
 */
class NexaVoiceInteractionService : VoiceInteractionService() {
    companion object {
        @Volatile
        internal var current: NexaVoiceInteractionService? = null
    }

    override fun onReady() {
        super.onReady()
        current = this
    }

    override fun onShutdown() {
        current = null
        super.onShutdown()
    }

    override fun onLaunchVoiceAssistFromKeyguard() {
        showSession(Bundle().apply { putString(Activation.EXTRA_SOURCE, "keyguard") }, 0)
    }
}

class NexaVoiceInteractionSessionService : VoiceInteractionSessionService() {
    override fun onNewSession(args: Bundle?): VoiceInteractionSession =
        NexaVoiceInteractionSession(this)
}

/**
 * Opened by the assist gesture / button (or our wake listener).
 *
 * Shows the compact assistant panel in the system's own assistant window:
 * a Flutter view on the host's shared engine, covering only part of the
 * screen. Touches outside the panel reach the app underneath. When the
 * device is locked, or the host app is already on screen, it hands over
 * to the host activity instead (unlock gate / in-app voice).
 */
internal class NexaVoiceInteractionSession(context: Context) : VoiceInteractionSession(context) {
    companion object {
        @Volatile
        var current: NexaVoiceInteractionSession? = null
    }

    private var root: FrameLayout? = null
    private var card: FrameLayout? = null
    private var flutterView: FlutterView? = null
    private var hostView: FlutterView? = null
    private var insets = Rect()

    override fun onCreate() {
        super.onCreate()
        window.window?.apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        }
    }

    override fun onCreateContentView(): View {
        val r = FrameLayout(context)
        val c = FrameLayout(context)
        r.addView(c, FrameLayout.LayoutParams(0, 0))
        r.setOnApplyWindowInsetsListener { _, wi ->
            insets = systemInsets(wi)
            layoutPanel()
            wi
        }
        root = r
        card = c
        return r
    }

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        current = this
        val a = Activation.fromBundle(context, args, "system")
        AssistantPrefs(context).note(a)
        if (a.locked || ActivationRouter.deliverToHost != null) {
            ActivationRouter.launchHost(context, a)
            finish()
            return
        }
        showPanel(a)
    }

    private fun showPanel(a: Activation) {
        if (flutterView != null) return
        val engine = NexaAssistantEngine.obtain(context)
        // One engine renders to one view: borrow it from the activity.
        hostView = PanelBridge.hostView?.invoke()?.takeIf { it.isAttachedToFlutterEngine }
        hostView?.detachFromFlutterEngine()
        val v = FlutterView(context, FlutterSurfaceView(context, true))
        card?.addView(v, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
        v.attachToFlutterEngine(engine)
        engine.lifecycleChannel.appIsResumed()
        flutterView = v
        layoutPanel()
        PanelBridge.shown(a, position())
    }

    override fun onHide() {
        teardownPanel()
        super.onHide()
    }

    override fun onDestroy() {
        teardownPanel()
        if (current === this) current = null
        super.onDestroy()
    }

    private fun teardownPanel() {
        val v = flutterView ?: return
        flutterView = null
        PanelBridge.hiddenNow()
        v.detachFromFlutterEngine()
        card?.removeView(v)
        val engine = NexaAssistantEngine.current() ?: return
        hostView?.takeIf { it.isAttachedToWindow }?.attachToFlutterEngine(engine)
        hostView = null
        if (ActivationRouter.deliverToHost == null) engine.lifecycleChannel.appIsPaused()
    }

    private fun position() = runCatching {
        PanelPosition.valueOf(AssistantPrefs(context).panelPosition.uppercase())
    }.getOrDefault(PanelPosition.BOTTOM)

    /** Size and place the panel inside the safe area. */
    private fun layoutPanel() {
        val r = root ?: return
        val c = card ?: return
        val dm = context.resources.displayMetrics
        val dp = dm.density
        val w = dm.widthPixels
        val h = dm.heightPixels
        val gap = (12 * dp).toInt()
        val lp = FrameLayout.LayoutParams(0, 0)
        when (position()) {
            PanelPosition.BOTTOM, PanelPosition.TOP -> {
                lp.width = minOf(w - insets.left - insets.right - 2 * gap, (600 * dp).toInt())
                lp.height = (176 * dp).toInt()
                val top = position() == PanelPosition.TOP
                lp.gravity = Gravity.CENTER_HORIZONTAL or if (top) Gravity.TOP else Gravity.BOTTOM
                lp.topMargin = if (top) insets.top + gap else 0
                lp.bottomMargin = if (top) 0 else insets.bottom + gap
            }
            PanelPosition.LEFT, PanelPosition.RIGHT -> {
                lp.width = minOf((340 * dp).toInt(), (w * 0.86f).toInt())
                lp.height = minOf(h - insets.top - insets.bottom - 2 * gap, (540 * dp).toInt())
                val left = position() == PanelPosition.LEFT
                lp.gravity = Gravity.CENTER_VERTICAL or if (left) Gravity.START else Gravity.END
                lp.marginStart = if (left) insets.left + gap else 0
                lp.marginEnd = if (left) 0 else insets.right + gap
            }
        }
        c.layoutParams = lp
        r.requestLayout()
    }

    /** Only the panel takes touches; the rest of the screen stays usable. */
    override fun onComputeInsets(outInsets: Insets) {
        super.onComputeInsets(outInsets)
        val c = card ?: return
        if (c.width == 0) return
        val loc = IntArray(2)
        c.getLocationInWindow(loc)
        outInsets.contentInsets.setEmpty()
        outInsets.touchableInsets = Insets.TOUCHABLE_INSETS_REGION
        outInsets.touchableRegion.set(loc[0], loc[1], loc[0] + c.width, loc[1] + c.height)
    }

    @Suppress("DEPRECATION")
    private fun systemInsets(wi: WindowInsets): Rect =
        if (Build.VERSION.SDK_INT >= 30) {
            val i = wi.getInsets(WindowInsets.Type.systemBars() or WindowInsets.Type.displayCutout())
            Rect(i.left, i.top, i.right, i.bottom)
        } else {
            Rect(wi.systemWindowInsetLeft, wi.systemWindowInsetTop, wi.systemWindowInsetRight, wi.systemWindowInsetBottom)
        }
}

/**
 * Android requires a recognition service next to a voice-interaction
 * service, and may make it the system "Voice input". This app has no
 * speech-to-text of its own, so it hands each request to the device's
 * normal recogniser (Google's when installed), keeping voice typing in
 * other apps working. With no other recogniser it declines.
 */
class NexaRecognitionService : RecognitionService() {
    private var delegate: SpeechRecognizer? = null

    override fun onStartListening(recognizerIntent: Intent?, listener: Callback?) {
        listener ?: return
        val target = otherRecognizer()
        if (target == null) {
            runCatching { listener.error(SpeechRecognizer.ERROR_CLIENT) }
            return
        }
        release()
        val r = SpeechRecognizer.createSpeechRecognizer(this, target)
        delegate = r
        r.setRecognitionListener(Relay(listener))
        r.startListening(recognizerIntent ?: Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH))
    }

    override fun onStopListening(listener: Callback?) {
        delegate?.stopListening()
    }

    override fun onCancel(listener: Callback?) {
        delegate?.cancel()
        release()
    }

    override fun onDestroy() {
        release()
        super.onDestroy()
    }

    private fun release() {
        delegate?.destroy()
        delegate = null
    }

    private fun otherRecognizer(): ComponentName? =
        packageManager.queryIntentServices(Intent(SERVICE_INTERFACE), 0)
            .map { ComponentName(it.serviceInfo.packageName, it.serviceInfo.name) }
            .filter { it.packageName != packageName }
            .sortedBy { if (it.packageName == "com.google.android.googlequicksearchbox") 0 else 1 }
            .firstOrNull()

    /** Passes every recogniser callback through unchanged. */
    private class Relay(private val cb: Callback) : RecognitionListener {
        override fun onReadyForSpeech(params: Bundle?) { runCatching { cb.readyForSpeech(params ?: Bundle()) } }
        override fun onBeginningOfSpeech() { runCatching { cb.beginningOfSpeech() } }
        override fun onRmsChanged(rmsdB: Float) { runCatching { cb.rmsChanged(rmsdB) } }
        override fun onBufferReceived(buffer: ByteArray?) { runCatching { cb.bufferReceived(buffer ?: ByteArray(0)) } }
        override fun onEndOfSpeech() { runCatching { cb.endOfSpeech() } }
        override fun onError(error: Int) { runCatching { cb.error(error) } }
        override fun onResults(results: Bundle?) { runCatching { cb.results(results ?: Bundle()) } }
        override fun onPartialResults(partialResults: Bundle?) { runCatching { cb.partialResults(partialResults ?: Bundle()) } }
        override fun onEvent(eventType: Int, params: Bundle?) {}
    }
}

/**
 * After a restart Android does not let an app start listening to the
 * microphone from the background. If the wake phrase was on, a quiet
 * notification asks the user to open the app once to turn it back on.
 */
class NexaAssistantBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!AssistantPrefs(context).wakeEnabled) return
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.apply { putExtra(Activation.EXTRA_REENABLE, true) } ?: return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = "nexa_assistant_listening"
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    channel,
                    context.getString(R.string.nexa_assistant_channel_listening),
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val n = Notifications.builder(context, channel)
            .setSmallIcon(Notifications.smallIcon(context))
            .setContentTitle(context.getString(R.string.nexa_assistant_reenable_title))
            .setContentText(context.getString(R.string.nexa_assistant_reenable_text))
            .setContentIntent(
                PendingIntent.getActivity(
                    context, 1, launch,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                ),
            )
            .setAutoCancel(true)
            .build()
        nm.notify(0x4E42, n)
    }
}
