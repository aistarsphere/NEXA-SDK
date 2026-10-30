package com.nexa.assistant

import android.content.Context
import com.nexa.assistant.engine.Sensitivity

/** The user's assistant choices (not secrets; the voice profile is separate). */
internal class AssistantPrefs(context: Context) {
    private val p = context.getSharedPreferences("nexa_assistant", Context.MODE_PRIVATE)

    var wakeEnabled: Boolean
        get() = p.getBoolean("wake_enabled", false)
        set(v) = p.edit().putBoolean("wake_enabled", v).apply()

    var requireOwner: Boolean
        get() = p.getBoolean("require_owner", false)
        set(v) = p.edit().putBoolean("require_owner", v).apply()

    var sensitivity: Sensitivity
        get() = runCatching { Sensitivity.valueOf(p.getString("sensitivity", null) ?: "") }
            .getOrDefault(Sensitivity.NORMAL)
        set(v) = p.edit().putString("sensitivity", v.name).apply()

    /** `bottom`, `top`, `left` or `right`. */
    var panelPosition: String
        get() = p.getString("panel_position", null) ?: "bottom"
        set(v) = p.edit().putString("panel_position", v).apply()

    /** Idle timeout of a panel conversation; 0 = off. */
    var idleTimeoutSeconds: Int
        get() = p.getInt("idle_timeout_s", 60)
        set(v) = p.edit().putInt("idle_timeout_s", v).apply()

    /** Diagnostics: the last activation and why the last panel call ended. */
    var lastActivation: String?
        get() = p.getString("last_activation", null)
        set(v) = p.edit().putString("last_activation", v).apply()

    var lastEnd: String?
        get() = p.getString("last_end", null)
        set(v) = p.edit().putString("last_end", v).apply()

    /** How the host names the wake phrase in notifications (e.g. «يا لبيب»). */
    var phraseLabel: String?
        get() = p.getString("phrase_label", null)
        set(v) = p.edit().putString("phrase_label", v).apply()
}
