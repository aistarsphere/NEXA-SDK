package com.nexa.assistant

import android.Manifest
import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import com.nexa.assistant.engine.FilterBank
import com.nexa.assistant.engine.WakeDecision
import com.nexa.assistant.engine.NeuralWakeEngine
import com.nexa.assistant.engine.WakeEngine
import com.nexa.assistant.engine.WakeFrontEnd

/**
 * Listens for the wake phrase on the device while the user has it on.
 *
 * A foreground service of type `microphone` with a permanent notification
 * (Android also shows its microphone indicator). Audio is analysed in
 * memory in 100 ms reads and never stored or sent anywhere. The microphone
 * is released while paused: during the host's voice conversation, during
 * phone calls, and right after an activation.
 *
 * Android only allows this service to start while the app is on screen
 * (and never after a force-stop or straight after a reboot).
 */
class WakeListenerService : Service() {
    companion object {
        private const val ACTION_START = "com.nexa.assistant.wake.START"
        private const val ACTION_STOP = "com.nexa.assistant.wake.STOP"
        private const val ACTION_PAUSE = "com.nexa.assistant.wake.PAUSE"
        private const val ACTION_RESUME = "com.nexa.assistant.wake.RESUME"
        private const val ACTION_RELOAD = "com.nexa.assistant.wake.RELOAD"
        private const val EXTRA_REASON = "reason"
        private const val CHANNEL = "nexa_assistant_listening"
        private const val NOTIFICATION_ID = 0x4E40

        /** If the host does not take over after an activation, listen again. */
        private const val ACTIVATION_RESUME_MS = 45_000L

        @Volatile
        internal var state: String = "stopped"
            private set

        @Volatile
        internal var stateReason: String? = null
            private set

        /** Plugin hooks (main thread). */
        @Volatile
        internal var onState: ((String, String?) -> Unit)? = null

        @Volatile
        internal var onDecision: ((WakeDecision) -> Unit)? = null

        internal fun start(context: Context) = send(context, ACTION_START, null, foreground = true)
        internal fun stop(context: Context) = send(context, ACTION_STOP)
        internal fun pause(context: Context, reason: String) = send(context, ACTION_PAUSE, reason)
        internal fun resume(context: Context) = send(context, ACTION_RESUME)
        internal fun reload(context: Context) = send(context, ACTION_RELOAD)

        private fun send(context: Context, action: String, reason: String? = null, foreground: Boolean = false) {
            if (!foreground && state == "stopped") return
            val i = Intent(context, WakeListenerService::class.java).setAction(action)
            if (reason != null) i.putExtra(EXTRA_REASON, reason)
            if (foreground && Build.VERSION.SDK_INT >= 26) context.startForegroundService(i)
            else context.startService(i)
        }
    }

    private val main = Handler(Looper.getMainLooper())
    private lateinit var prefs: AssistantPrefs
    private var worker: Thread? = null

    @Volatile private var running = false
    @Volatile private var pausedBy: String? = null
    @Volatile private var engineStale = true
    private var embedder: OnnxSpeakerEmbedder? = null
    private var features: OnnxWakeFeatures? = null

    private val autoResume = Runnable { if (pausedBy == "activation") doResume() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        prefs = AssistantPrefs(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> if (!begin()) stopSelf()
            ACTION_STOP -> {
                end("turned_off")
                stopSelf()
            }
            ACTION_PAUSE -> {
                main.removeCallbacks(autoResume)
                pausedBy = intent.getStringExtra(EXTRA_REASON) ?: "host"
                publish("paused", pausedBy)
            }
            ACTION_RESUME -> doResume()
            ACTION_RELOAD -> engineStale = true
            else -> stopSelf() // restarted without a command: not allowed to listen
        }
        // Not sticky: Android must not restart microphone capture in the
        // background on its own.
        return START_NOT_STICKY
    }

    private fun doResume() {
        main.removeCallbacks(autoResume)
        if (!running) return
        pausedBy = null
        publish("running", null)
    }

    private fun begin(): Boolean {
        if (running) {
            pausedBy = null
            engineStale = true
            publish("running", null)
            return true
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            publish("stopped", "permission_denied")
            return false
        }
        try {
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification())
            }
        } catch (e: Exception) {
            // Android 12+: not allowed from the background.
            publish("stopped", "background_start_blocked")
            return false
        }
        running = true
        pausedBy = null
        engineStale = true
        worker = Thread(::loop, "nexa-wake").apply { start() }
        publish("running", null)
        return true
    }

    private fun end(reason: String) {
        running = false
        main.removeCallbacks(autoResume)
        worker?.join(1500)
        worker = null
        embedder?.close()
        embedder = null
        features?.close()
        features = null
        if (Build.VERSION.SDK_INT >= 24) stopForeground(STOP_FOREGROUND_REMOVE)
        publish("stopped", reason)
    }

    override fun onDestroy() {
        if (running) end("destroyed")
        super.onDestroy()
    }

    private fun buildEngine(): WakeFrontEnd? {
        buildNeural()?.let { return it }
        val profile = VoiceProfileStore(this).load() ?: return null
        val requireOwner = prefs.requireOwner && profile.speaker != null
        if (requireOwner && embedder == null) embedder = OnnxSpeakerEmbedder.load(this)
        return WakeEngine(
            model = profile.phrase,
            speaker = profile.speaker,
            embedder = embedder,
            requireOwner = prefs.requireOwner,
            sensitivity = prefs.sensitivity,
            onDecision = ::onDecided,
        )
    }

    /** The trained acoustic detector for the chosen phrase, if installed. */
    private fun buildNeural(): NeuralWakeEngine? {
        val entry = WakePhraseCatalog.find(this, prefs.wakePhraseId) ?: return null
        val head = WakePhraseCatalog.loadHead(this, entry) ?: return null
        val f = features ?: OnnxWakeFeatures.load(this)?.also { features = it } ?: return null
        val profile = VoiceProfileStore(this).load()
        if (prefs.requireOwner && profile?.speaker != null && embedder == null) {
            embedder = OnnxSpeakerEmbedder.load(this)
        }
        Log.i("NexaWake", "detector=neural phrase=${entry.id} threshold=${entry.threshold} hits=${entry.hits}")
        return NeuralWakeEngine(
            features = f,
            head = head,
            baseThreshold = entry.threshold,
            hits = entry.hits,
            speaker = profile?.speaker,
            embedder = embedder,
            requireOwner = prefs.requireOwner,
            sensitivity = prefs.sensitivity,
            onDecision = ::onDecided,
        )
    }

    /** A marker file in the app's external files dir (adb-created) turns activation off for benchmarks. */
    private fun dryRun(): Boolean =
        java.io.File(getExternalFilesDir(null), "wake_dry_run").exists()

    private fun onDecided(d: WakeDecision) {
        // Scores only (never audio): needed to tune thresholds on real voices.
        Log.i(
            "NexaWake",
            "decision=${d.reason} ms=${d.durationMs} phrase=%.3f/%.3f voice=%s/%s".format(
                java.util.Locale.ROOT, d.keywordDistance, d.keywordThreshold,
                d.speakerScore?.let { "%.2f".format(java.util.Locale.ROOT, it) } ?: "-",
                d.speakerThreshold?.let { "%.2f".format(java.util.Locale.ROOT, it) } ?: "-",
            ),
        )
        main.post { onDecision?.invoke(d) }
        if (!d.accepted) return
        if (dryRun()) {
            // Measurement mode: the decision is logged above; no call opens.
            Log.i("NexaWake", "dry-run: activation suppressed")
            return
        }
        // Free the microphone before the assistant UI opens.
        pausedBy = "activation"
        main.post {
            publish("paused", "activation")
            ActivationRouter.activate(
                this,
                Activation("wake", if (prefs.requireOwner) true else null, Activation.locked(this)),
            )
            main.postDelayed(autoResume, ACTIVATION_RESUME_MS)
        }
    }

    @SuppressLint("MissingPermission") // checked in begin()
    private fun loop() {
        val audio = getSystemService(AUDIO_SERVICE) as AudioManager
        val buf = ShortArray(FilterBank.SAMPLE_RATE / 10)
        val floats = FloatArray(buf.size)
        var recorder: AudioRecord? = null
        var engine: WakeFrontEnd? = null
        var lastLogged = 0L
        fun releaseMic() {
            recorder?.let { r ->
                runCatching { r.stop() }
                r.release()
            }
            recorder = null
            engine?.reset()
        }
        while (running) {
            val inCall = audio.mode == AudioManager.MODE_IN_CALL ||
                audio.mode == AudioManager.MODE_IN_COMMUNICATION
            if (pausedBy != null || inCall) {
                releaseMic()
                Thread.sleep(250)
                continue
            }
            if (engineStale || engine == null) {
                engine = buildEngine()
                engineStale = false
                if (engine == null) {
                    main.post { publish("stopped", "not_enrolled") }
                    running = false
                    main.post { stopSelf() }
                    break
                }
            }
            if (recorder == null) {
                recorder = openRecorder()
                if (recorder == null) {
                    main.post { publish("error", "microphone_unavailable") }
                    Thread.sleep(2000)
                    continue
                }
                main.post { if (pausedBy == null) publish("running", null) }
            }
            val n = recorder!!.read(buf, 0, buf.size)
            if (n <= 0) {
                releaseMic() // revoked permission or the device took the mic
                Thread.sleep(500)
                continue
            }
            for (i in 0 until n) floats[i] = buf[i] / 32768f
            engine!!.accept(floats, n)
            (engine as? NeuralWakeEngine)?.let { e ->
                // Scores only (never audio): to measure near misses on the phone.
                val now = System.currentTimeMillis()
                if (e.lastScore >= 0.4f && now - lastLogged > 400) {
                    lastLogged = now
                    Log.i("NexaWake", "score=%.3f".format(java.util.Locale.ROOT, e.lastScore))
                }
            }
        }
        releaseMic()
    }

    @SuppressLint("MissingPermission")
    private fun openRecorder(): AudioRecord? {
        val min = AudioRecord.getMinBufferSize(
            FilterBank.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT,
        )
        if (min <= 0) return null
        return try {
            val r = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                FilterBank.SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT, maxOf(min, FilterBank.SAMPLE_RATE),
            )
            if (r.state != AudioRecord.STATE_INITIALIZED) {
                r.release(); null
            } else {
                r.startRecording(); r
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun publish(s: String, reason: String?) {
        state = s
        stateReason = reason
        if (running) {
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager)
                .notify(NOTIFICATION_ID, notification())
        }
        val cb = onState
        if (Looper.myLooper() == Looper.getMainLooper()) cb?.invoke(s, reason)
        else main.post { cb?.invoke(s, reason) }
    }

    private fun notification(): android.app.Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    getString(R.string.nexa_assistant_channel_listening),
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val phrase = prefs.phraseLabel
        val text = when {
            pausedBy != null -> getString(R.string.nexa_assistant_listening_paused)
            phrase != null -> getString(R.string.nexa_assistant_listening_for, phrase)
            else -> getString(R.string.nexa_assistant_listening)
        }
        val stop = PendingIntent.getService(
            this, 2,
            Intent(this, WakeListenerService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 3, it, PendingIntent.FLAG_IMMUTABLE)
        }
        @Suppress("DEPRECATION")
        return Notifications.builder(this, CHANNEL)
            .setSmallIcon(Notifications.smallIcon(this))
            .setContentTitle(text)
            .setContentText(getString(R.string.nexa_assistant_on_device_only))
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(
                android.app.Notification.Action.Builder(
                    null, getString(R.string.nexa_assistant_turn_off), stop,
                ).build(),
            )
            .build()
    }
}
