package com.nexa.assistant

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.app.Application
import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import com.nexa.assistant.engine.FilterBank
import com.nexa.assistant.engine.SampleQuality
import com.nexa.assistant.engine.Sensitivity
import com.nexa.assistant.engine.SpeakerProfile
import com.nexa.assistant.engine.SpeechSegmenter
import com.nexa.assistant.engine.WakeDecision
import com.nexa.assistant.engine.WakeEngine
import com.nexa.assistant.engine.WakePhraseModel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlin.concurrent.thread

/** Flutter bridge for the Android assistant role, wake phrase and voice profile. */
class NexaAssistantPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {

    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private lateinit var prefs: AssistantPrefs
    private lateinit var store: VoiceProfileStore
    private val main = Handler(Looper.getMainLooper())

    private var sink: EventChannel.EventSink? = null
    private var binding: ActivityPluginBinding? = null
    private val activity: Activity? get() = binding?.activity
    private var resumed = false
    private var pending: Activation? = null

    /** Enrolment audio is kept in memory only, until finish or cancel. */
    private val enrolment = ArrayList<FloatArray>()

    @Volatile private var busyRecording = false

    override fun onAttachedToEngine(b: FlutterPlugin.FlutterPluginBinding) {
        context = b.applicationContext
        prefs = AssistantPrefs(context)
        store = VoiceProfileStore(context)
        methods = MethodChannel(b.binaryMessenger, "nexa_assistant/methods")
        methods.setMethodCallHandler(this)
        events = EventChannel(b.binaryMessenger, "nexa_assistant/events")
        events.setStreamHandler(this)
        WakeListenerService.onState = { s, r -> emit(mapOf("type" to "listener", "state" to s, "reason" to r)) }
        WakeListenerService.onDecision = { d -> emit(decisionMap(d, "decision")) }
        PanelBridge.emitter = { m -> emit(m) }
    }

    override fun onDetachedFromEngine(b: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        WakeListenerService.onState = null
        WakeListenerService.onDecision = null
        ActivationRouter.deliverToHost = null
        PanelBridge.emitter = null
    }

    // ---------------------------------------------------------------- events

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
    }

    private fun emit(event: Map<String, Any?>) = main.post { sink?.success(event) }

    // -------------------------------------------------------------- activity

    private val lifecycle = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(a: Activity) {
            if (a !== activity) return
            resumed = true
            ActivationRouter.deliverToHost = { act -> deliver(act) }
        }

        override fun onActivityPaused(a: Activity) {
            if (a !== activity) return
            resumed = false
            ActivationRouter.deliverToHost = null
        }

        override fun onActivityCreated(a: Activity, s: Bundle?) {}
        override fun onActivityStarted(a: Activity) {}
        override fun onActivityStopped(a: Activity) {}
        override fun onActivitySaveInstanceState(a: Activity, s: Bundle) {}
        override fun onActivityDestroyed(a: Activity) {}
    }

    override fun onAttachedToActivity(b: ActivityPluginBinding) {
        binding = b
        b.addOnNewIntentListener(this)
        b.activity.application.registerActivityLifecycleCallbacks(lifecycle)
        PanelBridge.hostView = {
            binding?.activity?.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)
        }
        handleIntent(b.activity.intent)
        // Reopened after a reboot or force-stop: listening was on, and the
        // app is now on screen, which is when Android allows it to start.
        if (prefs.wakeEnabled && WakeListenerService.state == "stopped" && micGranted() && store.exists) {
            WakeListenerService.start(context)
        }
    }

    override fun onDetachedFromActivity() {
        binding?.removeOnNewIntentListener(this)
        binding?.activity?.application?.unregisterActivityLifecycleCallbacks(lifecycle)
        binding = null
        resumed = false
        ActivationRouter.deliverToHost = null
        PanelBridge.hostView = null
    }

    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onNewIntent(intent: Intent): Boolean = handleIntent(intent)

    /**
     * A fresh engine is not listening yet: the activation waits for
     * `takePendingActivation`. A kept engine receives it straight away.
     */
    private fun handleIntent(intent: Intent?): Boolean {
        val a = Activation.fromIntent(context, intent) ?: return false
        // Consume it so a later recreation does not activate again.
        intent?.removeExtra(Activation.EXTRA_SOURCE)
        intent?.action = Intent.ACTION_MAIN
        if (a.locked) showOverLockScreen(true)
        deliver(a)
        return true
    }

    private fun deliver(a: Activation) {
        prefs.lastActivation = "${a.source}@${a.at}"
        if (sink == null) pending = a else emit(a.toMap())
    }

    /**
     * Shows the host above the lock screen for this activation only. The
     * host must cover its content until [requestUnlock] succeeds.
     */
    private fun showOverLockScreen(on: Boolean) {
        val act = activity ?: return
        if (Build.VERSION.SDK_INT >= 27) {
            act.setShowWhenLocked(on)
            act.setTurnScreenOn(on)
        }
    }

    // --------------------------------------------------------------- methods

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(status())
            "configure" -> {
                prefs.phraseLabel = call.argument<String>("phraseLabel")
                result.success(null)
            }
            "surface" -> result.success(PanelBridge.state)
            "closePanel" -> {
                PanelBridge.nextHideReason = call.argument<String>("reason") ?: "closed"
                prefs.lastEnd = "${PanelBridge.nextHideReason}@${System.currentTimeMillis()}"
                val s = NexaVoiceInteractionSession.current
                if (s == null) PanelBridge.hiddenNow() else s.finish()
                result.success(null)
            }
            "expandPanel" -> {
                PanelBridge.nextHideReason = "expand"
                NexaVoiceInteractionSession.current?.finish()
                ActivationRouter.launchHost(context, Activation("expand", null, Activation.locked(context)))
                result.success(null)
            }
            "setPanelPosition" -> {
                prefs.panelPosition = call.argument<String>("value") ?: "bottom"
                result.success(null)
            }
            "setIdleTimeout" -> {
                prefs.idleTimeoutSeconds = call.argument<Int>("seconds") ?: 60
                result.success(null)
            }
            "reportSessionEnd" -> {
                prefs.lastEnd = "${call.argument<String>("reason")}@${System.currentTimeMillis()}"
                result.success(null)
            }
            "takePendingActivation" -> {
                result.success(pending?.toMap())
                pending = null
            }
            "openAssistantSettings" -> result.success(openAssistantSettings())
            "openBatterySettings" -> result.success(
                open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) || openAppDetails(),
            )
            "openBackgroundSettings" -> result.success(openOemBackgroundSettings() || openAppDetails())
            "openAppSettings" -> result.success(openAppDetails())
            "setWakeEnabled" -> setWakeEnabled(call.argument<Boolean>("enabled") == true, result)
            "setRequireOwnerVoice" -> setRequireOwner(call.argument<Boolean>("enabled") == true, result)
            "setSensitivity" -> {
                prefs.sensitivity = runCatching { Sensitivity.valueOf(call.argument<String>("value")!!.uppercase()) }
                    .getOrDefault(Sensitivity.NORMAL)
                WakeListenerService.reload(context)
                result.success(null)
            }
            "suspendListening" -> {
                WakeListenerService.pause(context, call.argument<String>("reason") ?: "host")
                result.success(null)
            }
            "resumeListening" -> {
                WakeListenerService.resume(context)
                result.success(null)
            }
            "enrollmentStart" -> {
                enrolment.clear()
                WakeListenerService.pause(context, "enrollment")
                result.success(null)
            }
            "enrollmentRecord" -> recordOne(call.argument<Int>("timeoutMs") ?: 6000, result) { seg -> enrolmentSample(seg) }
            "enrollmentFinish" -> finishEnrolment(result)
            "enrollmentCancel" -> {
                enrolment.clear()
                WakeListenerService.resume(context)
                result.success(null)
            }
            "deleteVoiceProfile" -> {
                enrolment.clear()
                prefs.wakeEnabled = false
                prefs.requireOwner = false
                WakeListenerService.stop(context)
                store.delete()
                result.success(null)
            }
            "testListen" -> testListen(call.argument<Int>("timeoutMs") ?: 6000, result)
            "requestUnlock" -> requestUnlock(result)
            "endLockScreenSession" -> {
                showOverLockScreen(false)
                if (call.argument<Boolean>("moveToBack") == true) activity?.moveTaskToBack(true)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun micGranted() =
        context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED

    private fun status(): Map<String, Any?> {
        val profile = store.load()
        val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return mapOf(
            "platformSupported" to true,
            "sdkInt" to Build.VERSION.SDK_INT,
            "release" to Build.VERSION.RELEASE,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "assistantRoleAvailable" to roleAvailable(),
            "isDefaultAssistant" to isDefaultAssistant(),
            "assistantRoleHeld" to roleHeld(),
            "assistantSetting" to secureSettingIsUs("assistant"),
            "voiceInteractionSetting" to secureSettingIsUs("voice_interaction_service"),
            "assistantServiceBound" to (NexaVoiceInteractionService.current != null),
            "panelPosition" to prefs.panelPosition,
            "idleTimeoutSeconds" to prefs.idleTimeoutSeconds,
            "lastActivation" to prefs.lastActivation,
            "lastEnd" to prefs.lastEnd,
            "surface" to PanelBridge.state["surface"],
            // Android's always-on hotword API needs a privileged/system app
            // and OEM keyphrase models; an installed app uses the software
            // listener instead.
            "hardwareHotword" to "requires_system_app",
            "microphonePermission" to micGranted(),
            "notificationsEnabled" to nm.areNotificationsEnabled(),
            "ignoringBatteryOptimizations" to pm.isIgnoringBatteryOptimizations(context.packageName),
            "wakeEnabled" to prefs.wakeEnabled,
            "listenerState" to WakeListenerService.state,
            "listenerReason" to WakeListenerService.stateReason,
            "enrolled" to (profile != null),
            "enrolledSamples" to (profile?.phrase?.templates?.size ?: 0),
            "speakerEnrolled" to (profile?.speaker != null),
            "speakerModelAvailable" to OnnxSpeakerEmbedder.available(context),
            "speakerModel" to OnnxSpeakerEmbedder.MODEL_ID,
            "requireOwnerVoice" to prefs.requireOwner,
            "sensitivity" to prefs.sensitivity.name.lowercase(),
            "locked" to Activation.locked(context),
        )
    }

    private fun roleAvailable(): Boolean =
        if (Build.VERSION.SDK_INT >= 29) {
            context.getSystemService(RoleManager::class.java).isRoleAvailable(RoleManager.ROLE_ASSISTANT)
        } else true

    /**
     * Read from Android each time (never cached): the assistant role, the
     * assistant settings OEM screens write, or Android having bound our
     * assistant service (it binds only the selected assistant's).
     */
    private fun isDefaultAssistant(): Boolean =
        roleHeld() == true ||
            secureSettingIsUs("voice_interaction_service") == true ||
            secureSettingIsUs("assistant") == true ||
            NexaVoiceInteractionService.current != null

    private fun roleHeld(): Boolean? =
        if (Build.VERSION.SDK_INT >= 29) {
            runCatching {
                context.getSystemService(RoleManager::class.java).isRoleHeld(RoleManager.ROLE_ASSISTANT)
            }.getOrNull()
        } else null

    /** Null when Android does not let this app read the setting. */
    private fun secureSettingIsUs(key: String): Boolean? = runCatching {
        val v = Settings.Secure.getString(context.contentResolver, key) ?: return@runCatching false
        ComponentName.unflattenFromString(v)?.packageName == context.packageName
    }.getOrNull()

    /**
     * The system's own "Digital assistant app" chooser (the user decides).
     * Not the "Assist & voice input" page: there "Voice input" is a
     * different setting (speech-to-text) and is easily picked by mistake.
     */
    private fun openAssistantSettings(): Boolean =
        // The role's own chooser (permission controller; not in the public
        // SDK, so by name). Falls back to the public "Default apps" list.
        (Build.VERSION.SDK_INT >= 29 &&
            open(
                Intent("android.intent.action.MANAGE_DEFAULT_APP")
                    .putExtra("android.intent.extra.ROLE_NAME", RoleManager.ROLE_ASSISTANT),
            )) ||
            (Build.VERSION.SDK_INT >= 24 && open(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))) ||
            open(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)) ||
            open(Intent(Settings.ACTION_SETTINGS))

    /** Xiaomi/Redmi/POCO autostart screen when present; otherwise app details. */
    private fun openOemBackgroundSettings(): Boolean {
        val m = Build.MANUFACTURER.lowercase()
        if (m == "xiaomi" || m == "redmi" || m == "poco") {
            val i = Intent().setComponent(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
            )
            if (open(i)) return true
        }
        return false
    }

    private fun openAppDetails() =
        open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))

    private fun open(intent: Intent): Boolean {
        val launcher = activity ?: context
        if (launcher === context) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            launcher.startActivity(intent); true
        } catch (e: Exception) {
            false
        }
    }

    private fun setWakeEnabled(on: Boolean, result: MethodChannel.Result) {
        if (!on) {
            prefs.wakeEnabled = false
            WakeListenerService.stop(context)
            result.success("off")
            return
        }
        when {
            !micGranted() -> result.success("permission_denied")
            !store.exists -> result.success("not_enrolled")
            !resumed -> result.success("not_in_foreground")
            else -> {
                prefs.wakeEnabled = true
                WakeListenerService.start(context)
                result.success("on")
            }
        }
    }

    private fun setRequireOwner(on: Boolean, result: MethodChannel.Result) {
        if (on) {
            val p = store.load()
            when {
                !OnnxSpeakerEmbedder.available(context) -> return result.success("model_unavailable")
                p?.speaker == null -> return result.success("not_enrolled")
            }
        }
        prefs.requireOwner = on
        WakeListenerService.reload(context)
        result.success(if (on) "on" else "off")
    }

    // ------------------------------------------------- one-shot recordings

    /**
     * Records until one utterance ends (or [timeoutMs]); the audio stays in
     * memory and goes to [use] only.
     */
    @SuppressLint("MissingPermission")
    private fun recordOne(timeoutMs: Int, result: MethodChannel.Result, use: (FloatArray?) -> Map<String, Any?>) {
        if (!micGranted()) return result.success(mapOf("ok" to false, "reason" to "permission_denied"))
        if (busyRecording) return result.success(mapOf("ok" to false, "reason" to "busy"))
        busyRecording = true
        thread(name = "nexa-enrol") {
            var segment: FloatArray? = null
            val seg = SpeechSegmenter(onSegment = { if (segment == null) segment = it })
            val buf = ShortArray(FilterBank.SAMPLE_RATE / 10)
            val floats = FloatArray(buf.size)
            var rec: AudioRecord? = null
            var reason: String? = null
            try {
                val min = AudioRecord.getMinBufferSize(
                    FilterBank.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                )
                rec = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION, FilterBank.SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(min, FilterBank.SAMPLE_RATE),
                )
                if (rec.state != AudioRecord.STATE_INITIALIZED) {
                    reason = "microphone_unavailable"
                } else {
                    rec.startRecording()
                    emit(mapOf("type" to "recording", "active" to true))
                    val deadline = System.currentTimeMillis() + timeoutMs
                    while (segment == null && System.currentTimeMillis() < deadline) {
                        val n = rec.read(buf, 0, buf.size)
                        if (n <= 0) {
                            reason = "microphone_unavailable"; break
                        }
                        for (i in 0 until n) floats[i] = buf[i] / 32768f
                        seg.accept(floats, n)
                    }
                }
            } catch (e: Exception) {
                reason = "microphone_unavailable"
            } finally {
                rec?.let { r ->
                    runCatching { r.stop() }
                    r.release()
                }
                emit(mapOf("type" to "recording", "active" to false))
            }
            val out = if (reason != null) mapOf("ok" to false, "reason" to reason) else use(segment)
            busyRecording = false
            main.post { result.success(out) }
        }
    }

    private val bank = FilterBank()

    private fun enrolmentSample(segment: FloatArray?): Map<String, Any?> {
        val problem = SampleQuality.problem(segment)
        if (problem != null) return mapOf("ok" to false, "reason" to problem, "count" to enrolment.size)
        val s = segment!!
        if (enrolment.isNotEmpty()) {
            // A very different utterance is probably not the phrase.
            val feats = bank.mfcc(bank.compute(s))
            val previous = enrolment.map { bank.mfcc(bank.compute(it)) }
            if (WakePhraseModel.nearest(feats, previous) > WakePhraseModel.INCONSISTENT) {
                return mapOf("ok" to false, "reason" to "inconsistent", "count" to enrolment.size)
            }
        }
        enrolment += s
        return mapOf("ok" to true, "count" to enrolment.size, "durationMs" to s.size / 16)
    }

    private fun finishEnrolment(result: MethodChannel.Result) {
        if (enrolment.size < WakePhraseModel.MIN_SAMPLES) {
            return result.success(mapOf("ok" to false, "reason" to "too_few_samples", "count" to enrolment.size))
        }
        val samples = ArrayList(enrolment)
        enrolment.clear()
        thread(name = "nexa-enrol-finish") {
            val out = try {
                val phrase = WakePhraseModel.fromSamples(samples.map { bank.mfcc(bank.compute(it)) })
                val embedder = OnnxSpeakerEmbedder.load(context)
                val speaker = embedder?.use { e ->
                    samples.mapNotNull { e.embed(it) }.takeIf { it.size >= 2 }
                        ?.let { SpeakerProfile.fromEmbeddings(it) }
                }
                store.save(VoiceProfile(phrase, speaker, System.currentTimeMillis()))
                if (speaker == null) prefs.requireOwner = false
                mapOf("ok" to true, "count" to samples.size, "speaker" to (speaker != null))
            } catch (e: Exception) {
                mapOf("ok" to false, "reason" to "save_failed")
            } finally {
                samples.clear()
            }
            main.post {
                WakeListenerService.reload(context)
                WakeListenerService.resume(context)
                result.success(out)
            }
        }
    }

    private fun testListen(timeoutMs: Int, result: MethodChannel.Result) {
        val profile = store.load() ?: return result.success(mapOf("ok" to false, "reason" to "not_enrolled"))
        WakeListenerService.pause(context, "test")
        recordOne(timeoutMs, object : MethodChannel.Result {
            override fun success(r: Any?) {
                WakeListenerService.resume(context)
                result.success(r)
            }
            override fun error(c: String, m: String?, d: Any?) = result.error(c, m, d)
            override fun notImplemented() = result.notImplemented()
        }) { seg ->
            if (seg == null) return@recordOne mapOf("ok" to false, "reason" to "no_speech")
            val embedder = if (profile.speaker != null) OnnxSpeakerEmbedder.load(context) else null
            embedder.use {
                val d = WakeEngine(
                    model = profile.phrase,
                    speaker = profile.speaker,
                    embedder = embedder,
                    // The test always reports the voice score when it can.
                    requireOwner = profile.speaker != null && embedder != null,
                    sensitivity = prefs.sensitivity,
                    onDecision = {},
                ).decide(seg)
                decisionMap(d, "test") + mapOf("ok" to true, "ownerRequired" to prefs.requireOwner)
            }
        }
    }

    private fun decisionMap(d: WakeDecision, type: String) = mapOf(
        "type" to type,
        "accepted" to d.accepted,
        "reason" to d.reason,
        "keywordDistance" to d.keywordDistance.toDouble().takeIf { it.isFinite() },
        "keywordThreshold" to d.keywordThreshold.toDouble(),
        "speakerScore" to d.speakerScore?.toDouble(),
        "speakerThreshold" to d.speakerThreshold?.toDouble(),
        "durationMs" to d.durationMs,
    )

    // ------------------------------------------------------------ keyguard

    private fun requestUnlock(result: MethodChannel.Result) {
        val act = activity ?: return result.success("no_activity")
        val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!km.isKeyguardLocked) {
            showOverLockScreen(false)
            return result.success("unlocked")
        }
        if (Build.VERSION.SDK_INT < 26) return result.success("unsupported")
        km.requestDismissKeyguard(act, object : KeyguardManager.KeyguardDismissCallback() {
            override fun onDismissSucceeded() {
                showOverLockScreen(false)
                result.success("unlocked")
            }
            override fun onDismissCancelled() = result.success("cancelled")
            override fun onDismissError() = result.success("error")
        })
    }
}
