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
            "benchRecord" -> benchRecord(
                call.argument<String>("label") ?: "clip",
                call.argument<Int>("seconds") ?: 3,
                result,
            )
            "benchClear" -> {
                val dir = benchDir()
                val n = dir.listFiles()?.count { it.delete() } ?: 0
                result.success(n)
            }
            "benchCount" -> result.success(benchDir().listFiles()?.size ?: 0)
            "benchModelSpeed" -> benchModelSpeed(result)
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
     * Android's "Assist & voice input" page, whose first item is "Digital
     * assistant app" (the user decides). Apps cannot open the assistant
     * role chooser itself: the permission controller redirects that request
     * to the general "Default apps" list (seen on Android 13 and 16). The
     * host should tell the user to pick the top item, not "Voice input".
     */
    private fun openAssistantSettings(): Boolean =
        open(Intent(Settings.ACTION_VOICE_INPUT_SETTINGS)) ||
            (Build.VERSION.SDK_INT >= 24 && open(Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS))) ||
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
            val feats = bank.phraseFeatures(s)
            val previous = enrolment.map { bank.phraseFeatures(it) }
            val nearest = WakePhraseModel.nearest(feats, previous)
            android.util.Log.i(
                "NexaWake",
                "enrol sample ${enrolment.size + 1}: ms=${s.size / 16} nearest=${"%.3f".format(nearest)}",
            )
            if (nearest > WakePhraseModel.INCONSISTENT) {
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
                val feats = samples.map { bank.phraseFeatures(it) }
                val phrase = WakePhraseModel.fromSamples(feats)
                // Calibration evidence (numbers only, no audio).
                android.util.Log.i(
                    "NexaWake",
                    "enrolled n=${feats.size} ms=${samples.map { it.size / 16 }} " +
                        "nearest=${feats.indices.map { i -> "%.3f".format(WakePhraseModel.nearest(feats[i], feats.filterIndexed { j, _ -> j != i })) }} " +
                        "threshold=${"%.3f".format(phrase.threshold)}",
                )
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

    // ------------------------------------- wake-word benchmark (dev only)

    /**
     * Labelled benchmark clips, recorded only after the user's consent in
     * the developer screen: 16 kHz mono WAV in the app's own external files
     * folder (readable over USB for offline evaluation, removed with the
     * app or "Delete all"). Never uploaded.
     */
    private fun benchDir() =
        java.io.File(context.getExternalFilesDir(null), "wake_bench").apply { mkdirs() }

    @SuppressLint("MissingPermission")
    private fun benchRecord(label: String, seconds: Int, result: MethodChannel.Result) {
        if (!micGranted()) return result.success(mapOf("ok" to false, "reason" to "permission_denied"))
        if (busyRecording) return result.success(mapOf("ok" to false, "reason" to "busy"))
        busyRecording = true
        WakeListenerService.pause(context, "test")
        thread(name = "nexa-bench") {
            val total = FilterBank.SAMPLE_RATE * seconds.coerceIn(1, 15)
            val pcm = ShortArray(total)
            var filled = 0
            var reason: String? = null
            var rec: AudioRecord? = null
            try {
                val min = AudioRecord.getMinBufferSize(
                    FilterBank.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                )
                rec = AudioRecord(
                    MediaRecorder.AudioSource.VOICE_RECOGNITION, FilterBank.SAMPLE_RATE,
                    AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
                    maxOf(min, FilterBank.SAMPLE_RATE),
                )
                rec.startRecording()
                emit(mapOf("type" to "recording", "active" to true))
                while (filled < total) {
                    val n = rec.read(pcm, filled, minOf(1600, total - filled))
                    if (n <= 0) { reason = "microphone_unavailable"; break }
                    filled += n
                }
            } catch (e: Exception) {
                reason = "microphone_unavailable"
            } finally {
                rec?.let { r -> runCatching { r.stop() }; r.release() }
                emit(mapOf("type" to "recording", "active" to false))
            }
            val out = if (reason != null) {
                mapOf("ok" to false, "reason" to reason)
            } else {
                val safe = label.replace(Regex("[^A-Za-z0-9_-]"), "_")
                val f = java.io.File(benchDir(), "${safe}_${System.currentTimeMillis()}.wav")
                writeWav(f, pcm, filled)
                mapOf("ok" to true, "file" to f.name, "count" to (benchDir().listFiles()?.size ?: 0))
            }
            busyRecording = false
            main.post {
                WakeListenerService.resume(context)
                result.success(out)
            }
        }
    }

    /**
     * Times the speech-embedding wake detector (openWakeWord mel + Google
     * speech_embedding, pushed by the developer to files/models/) in the
     * streaming setting: each 80 ms step computes the mel of the last
     * 1.36 s and one 96-d embedding. 60 s of synthetic audio, no
     * microphone, no network.
     */
    private fun benchModelSpeed(result: MethodChannel.Result) {
        val dir = java.io.File(context.getExternalFilesDir(null), "models")
        val melF = java.io.File(dir, "melspectrogram.onnx")
        val embF = java.io.File(dir, "embedding_model.onnx")
        if (!melF.exists() || !embF.exists()) {
            return result.success(mapOf("ok" to false, "reason" to "models_missing"))
        }
        thread(name = "nexa-bench-speed") {
            val out = try {
                val env = ai.onnxruntime.OrtEnvironment.getEnvironment()
                val opts = ai.onnxruntime.OrtSession.SessionOptions().apply { setIntraOpNumThreads(1) }
                val heap0 = android.os.Debug.getNativeHeapAllocatedSize()
                val loadStart = System.nanoTime()
                val mel = env.createSession(melF.readBytes(), opts)
                val emb = env.createSession(embF.readBytes(), opts)
                val loadMs = (System.nanoTime() - loadStart) / 1e6
                val heapModels = android.os.Debug.getNativeHeapAllocatedSize() - heap0
                val rnd = java.util.Random(1)
                val window = 21760 // 1.36 s: enough mel frames for one 76-frame window
                val steps = 750    // 60 s of 80 ms steps
                val audio = FloatArray(window) { (rnd.nextGaussian() * 800).toFloat() }
                val stepMs = DoubleArray(steps)
                val cpu0 = android.os.Process.getElapsedCpuTime()
                val wall0 = System.nanoTime()
                for (s in 0 until steps) {
                    val t0 = System.nanoTime()
                    ai.onnxruntime.OnnxTensor.createTensor(
                        env, java.nio.FloatBuffer.wrap(audio), longArrayOf(1, window.toLong()),
                    ).use { a ->
                        mel.run(mapOf(mel.inputNames.first() to a)).use { r ->
                            @Suppress("UNCHECKED_CAST")
                            val m = r[0].value as Array<Array<Array<FloatArray>>>
                            val frames = m.size
                            val last = FloatArray(76 * 32)
                            for (i in 0 until 76) {
                                val src = m[frames - 76 + i][0][0]
                                for (k in 0 until 32) last[i * 32 + k] = src[k] / 10f + 2f
                            }
                            ai.onnxruntime.OnnxTensor.createTensor(
                                env, java.nio.FloatBuffer.wrap(last), longArrayOf(1, 76, 32, 1),
                            ).use { e -> emb.run(mapOf(emb.inputNames.first() to e)).close() }
                        }
                    }
                    stepMs[s] = (System.nanoTime() - t0) / 1e6
                }
                val wallMs = (System.nanoTime() - wall0) / 1e6
                val cpuMs = android.os.Process.getElapsedCpuTime() - cpu0
                mel.close(); emb.close()
                val sorted = stepMs.sorted()
                mapOf(
                    "ok" to true,
                    "load_ms" to loadMs,
                    "model_heap_kb" to heapModels / 1024,
                    "step_ms_median" to sorted[steps / 2],
                    "step_ms_p95" to sorted[(steps * 0.95).toInt()],
                    "steps" to steps,
                    "realtime_cpu_percent_of_one_core" to (sorted.sum() / (steps * 80.0)) * 100,
                    "wall_ms" to wallMs,
                    "process_cpu_ms" to cpuMs,
                )
            } catch (e: Throwable) {
                mapOf("ok" to false, "reason" to e.javaClass.simpleName)
            }
            android.util.Log.i("NexaWakeBench", "speed $out")
            main.post { result.success(out) }
        }
    }

    private fun writeWav(f: java.io.File, pcm: ShortArray, n: Int) {
        val data = n * 2
        val b = java.nio.ByteBuffer.allocate(44 + data).order(java.nio.ByteOrder.LITTLE_ENDIAN)
        b.put("RIFF".toByteArray()).putInt(36 + data).put("WAVE".toByteArray())
        b.put("fmt ".toByteArray()).putInt(16).putShort(1).putShort(1)
            .putInt(FilterBank.SAMPLE_RATE).putInt(FilterBank.SAMPLE_RATE * 2).putShort(2).putShort(16)
        b.put("data".toByteArray()).putInt(data)
        for (i in 0 until n) b.putShort(pcm[i])
        f.writeBytes(b.array())
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
