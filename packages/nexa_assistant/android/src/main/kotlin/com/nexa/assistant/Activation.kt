package com.nexa.assistant

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle

/** One request to open the assistant, from the system or the wake phrase. */
internal data class Activation(
    /** `system` (assist gesture/button), `keyguard`, `wake`, `assist_intent`. */
    val source: String,
    /** Owner-voice result for `wake`: true/false, null when not checked. */
    val verified: Boolean?,
    val locked: Boolean,
    val at: Long = System.currentTimeMillis(),
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "type" to "activation",
        "source" to source,
        "verified" to verified,
        "locked" to locked,
        "at" to at,
    )

    fun toBundle() = Bundle().apply {
        putString(EXTRA_SOURCE, source)
        if (verified != null) putBoolean(EXTRA_VERIFIED, verified)
    }

    companion object {
        const val EXTRA_SOURCE = "com.nexa.assistant.ACTIVATION_SOURCE"
        const val EXTRA_VERIFIED = "com.nexa.assistant.ACTIVATION_VERIFIED"
        const val EXTRA_REENABLE = "com.nexa.assistant.REENABLE"

        fun locked(context: Context) =
            (context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked

        fun fromBundle(context: Context, b: Bundle?, fallback: String) = Activation(
            source = b?.getString(EXTRA_SOURCE) ?: fallback,
            verified = if (b?.containsKey(EXTRA_VERIFIED) == true) b.getBoolean(EXTRA_VERIFIED) else null,
            locked = locked(context),
        )

        /** The activation an intent carries (our extras or the assist actions). */
        fun fromIntent(context: Context, intent: Intent?): Activation? {
            intent ?: return null
            val source = intent.getStringExtra(EXTRA_SOURCE)
            if (source != null) return fromBundle(context, intent.extras, source)
            return when (intent.action) {
                Intent.ACTION_ASSIST,
                Intent.ACTION_VOICE_COMMAND,
                "android.intent.action.VOICE_ASSIST" -> Activation("assist_intent", null, locked(context))
                else -> null
            }
        }
    }
}

/**
 * Delivers activations to the host UI. Order: straight to Flutter when the
 * host is on screen and unlocked; otherwise through our voice-interaction
 * session when we are the default assistant (the platform's own path);
 * otherwise a "tap to talk" notification. Never a hidden launch.
 */
internal object ActivationRouter {
    /** Set by the plugin while the host activity is resumed. */
    @Volatile
    var deliverToHost: ((Activation) -> Unit)? = null

    private const val CHANNEL = "nexa_assistant_activation"
    private const val NOTIFICATION_ID = 0x4E41

    fun activate(context: Context, a: Activation) {
        AssistantPrefs(context).lastActivation = "${a.source}@${a.at}"
        val host = deliverToHost
        if (host != null && !a.locked) {
            host(a)
            return
        }
        val vis = NexaVoiceInteractionService.current
        if (vis != null) {
            vis.showSession(a.toBundle(), 0)
            return
        }
        notifyTapToTalk(context, a)
    }

    /** Opens (or brings back) the host's launcher activity with [a]. */
    fun launchHost(context: Context, a: Activation) {
        val intent = hostIntent(context, a) ?: return
        context.startActivity(intent)
    }

    fun hostIntent(context: Context, a: Activation): Intent? =
        context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtras(a.toBundle())
        }

    private fun notifyTapToTalk(context: Context, a: Activation) {
        val intent = hostIntent(context, a) ?: return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    context.getString(R.string.nexa_assistant_channel_activation),
                    NotificationManager.IMPORTANCE_HIGH,
                ),
            )
        }
        val pending = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = Notifications.builder(context, CHANNEL)
            .setSmallIcon(R.drawable.nexa_assistant_mic)
            .setContentTitle(context.getString(R.string.nexa_assistant_tap_to_talk))
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setCategory(android.app.Notification.CATEGORY_CALL)
            .apply { if (Build.VERSION.SDK_INT >= 26) setTimeoutAfter(30_000) }
            .build()
        nm.notify(NOTIFICATION_ID, n)
    }
}

internal object Notifications {
    @Suppress("DEPRECATION")
    fun builder(context: Context, channel: String): android.app.Notification.Builder =
        if (Build.VERSION.SDK_INT >= 26) android.app.Notification.Builder(context, channel)
        else android.app.Notification.Builder(context)
}
