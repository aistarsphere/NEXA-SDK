package com.nexa.assistant

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Keeps a live voice call (microphone capture and playback) alive while the
 * app is in the background.
 *
 * A foreground service of type `microphone` with an ongoing notification
 * and an "End call" action. It only holds the process: the call itself runs
 * in Flutter. Android 14+ refuses to start a microphone service from the
 * background, so the plugin starts it only while the app is on screen and
 * the host carries on without it when that fails.
 *
 * Not sticky: after a process kill nothing restarts, the server ends the
 * call by its own timeout.
 */
class CallForegroundService : Service() {
    companion object {
        private const val TAG = "NexaCallService"
        private const val ACTION_START = "com.nexa.assistant.call.START"
        private const val ACTION_END = "com.nexa.assistant.call.END"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_END_LABEL = "endLabel"
        private const val CHANNEL = "nexa_call"
        private const val NOTIFICATION_ID = 0x4E41

        @Volatile
        internal var running = false
            private set

        /** Plugin hook (main thread): the user ended the call outside the app. */
        @Volatile
        internal var onEndRequested: ((String) -> Unit)? = null

        /** Throws (e.g. ForegroundServiceStartNotAllowedException) when Android refuses. */
        internal fun start(context: Context, title: String, endLabel: String) {
            val i = Intent(context, CallForegroundService::class.java)
                .setAction(ACTION_START)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_END_LABEL, endLabel)
            if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(i)
            else context.startService(i)
        }

        internal fun stop(context: Context) {
            if (!running) return
            context.stopService(Intent(context, CallForegroundService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> begin(
                intent.getStringExtra(EXTRA_TITLE) ?: getString(R.string.nexa_assistant_call_title),
                intent.getStringExtra(EXTRA_END_LABEL) ?: getString(R.string.nexa_assistant_call_end),
            )
            ACTION_END -> {
                onEndRequested?.invoke("notification")
                stopSelf()
            }
            else -> stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun begin(title: String, endLabel: String) {
        try {
            val n = notification(title, endLabel)
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
            running = true
        } catch (e: Exception) {
            // Missing permission or a background start Android refused.
            Log.w(TAG, "call service not started: ${e.javaClass.simpleName}")
            running = false
            stopSelf()
        }
    }

    /** The app was swiped away: end the call (nothing else would hold it). */
    override fun onTaskRemoved(rootIntent: Intent?) {
        onEndRequested?.invoke("task_removed")
        stopSelf()
    }

    override fun onDestroy() {
        running = false
        super.onDestroy()
    }

    @Suppress("DEPRECATION")
    private fun notification(title: String, endLabel: String): Notification {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, getString(R.string.nexa_assistant_channel_call), NotificationManager.IMPORTANCE_LOW),
            )
        }
        val end = PendingIntent.getService(
            this, 4,
            Intent(this, CallForegroundService::class.java).setAction(ACTION_END),
            PendingIntent.FLAG_IMMUTABLE,
        )
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 5, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return Notifications.builder(this, CHANNEL)
            .setSmallIcon(R.drawable.nexa_assistant_mic)
            .setContentTitle(title)
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, endLabel, end).build())
            .build()
    }
}
