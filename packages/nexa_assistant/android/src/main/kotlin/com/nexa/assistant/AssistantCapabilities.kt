package com.nexa.assistant

import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.role.RoleManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Facts about what THIS device offers for an assistant, read from Android
 * each time (never cached, never inferred from "the user came back from
 * Settings"). The checklist logic lives in Dart and only uses these facts.
 */
internal object AssistantCapabilities {

    /** A settings destination: the intent, and whether Android can open it here. */
    data class Destination(val id: String, val intent: Intent) {
        fun resolvable(context: Context): Boolean =
            intent.resolveActivity(context.packageManager) != null
    }

    fun appDetails(context: Context) = Destination(
        "app_details",
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)),
    )

    /** Lists the apps' battery optimisation screen (needs no special permission). */
    fun batterySettings() = Destination("battery_list", Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))

    fun defaultApps() = Destination(
        "default_apps",
        Intent(if (Build.VERSION.SDK_INT >= 24) Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS else Settings.ACTION_SETTINGS),
    )

    fun voiceInput() = Destination("voice_input", Intent(Settings.ACTION_VOICE_INPUT_SETTINGS))

    fun notificationSettings(context: Context) = Destination(
        "notifications",
        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
    )

    /**
     * Known vendor "auto-start / background" screens. They are only OFFERED
     * when this device resolves them; never launched blind.
     */
    fun oemBackground(): List<Destination> = listOf(
        "xiaomi" to ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity"),
        "huawei" to ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"),
        "oppo" to ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity"),
        "vivo" to ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity"),
        "samsung" to ComponentName("com.samsung.android.lool", "com.samsung.android.sm.battery.ui.BatteryActivity"),
        "oneplus" to ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"),
    ).map { (id, c) -> Destination("oem_$id", Intent().setComponent(c)) }

    fun collect(context: Context, prefs: AssistantPrefs): Map<String, Any?> {
        val pm = context.packageManager
        val sdk = Build.VERSION.SDK_INT
        val role = if (sdk >= 29) context.getSystemService(RoleManager::class.java) else null
        val kg = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val power = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val roleAvailable = runCatching { role?.isRoleAvailable(RoleManager.ROLE_ASSISTANT) }.getOrNull()
        val roleHeld = runCatching { role?.isRoleHeld(RoleManager.ROLE_ASSISTANT) }.getOrNull()
        val serviceEnabled = runCatching {
            pm.getComponentEnabledSetting(ComponentName(context, NexaVoiceInteractionService::class.java)) !=
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
        }.getOrDefault(false)
        val oem = oemBackground().firstOrNull { it.resolvable(context) }
        return mapOf(
            "sdkInt" to sdk,
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            // Assistant selection.
            "roleApi" to (sdk >= 29),
            "roleAvailable" to roleAvailable,
            "roleHeld" to roleHeld,
            // The intent resolves, but the system refuses it ("Role is not requestable:
            // android.app.role.ASSISTANT", logged on Android 13): never offered.
            "roleRequestable" to false,
            "serviceDeclared" to serviceEnabled,
            "serviceBound" to (NexaVoiceInteractionService.current != null),
            "settingsDefaultApps" to defaultApps().resolvable(context),
            "settingsVoiceInput" to voiceInput().resolvable(context),
            // Microphone / background.
            "microphonePermission" to (context.checkSelfPermission(android.Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED),
            "fgsMicrophoneDeclared" to true,
            // Android 14+ refuses to start a microphone foreground service from
            // the background; 11-13 allow it only while the app is "in use".
            "microphoneFgsStart" to if (sdk >= 34) "foreground_only_strict" else if (sdk >= 30) "while_in_use" else "allowed",
            "postNotificationsRuntime" to (sdk >= 33),
            "notificationsEnabled" to nm.areNotificationsEnabled(),
            "ignoringBatteryOptimizations" to power.isIgnoringBatteryOptimizations(context.packageName),
            "batterySettingsResolvable" to batterySettings().resolvable(context),
            "oemBackgroundSettings" to oem?.id,
            "powerSaveMode" to power.isPowerSaveMode,
            // Lock screen.
            "keyguardSupportDeclared" to true, // supportsLaunchVoiceAssistFromKeyguard in the service metadata
            "deviceSecure" to kg.isDeviceSecure,
            "keyguardLocked" to kg.isKeyguardLocked,
            // Listening.
            "wakeEnabled" to prefs.wakeEnabled,
            "listenerState" to WakeListenerService.state,
            "listenerReason" to WakeListenerService.stateReason,
            "hotwordHardware" to "requires_system_app",
            // Evidence that something really happened (epoch ms, or null).
            "evidenceAssistAt" to prefs.evidenceAssistAt,
            "evidenceWakeAt" to prefs.evidenceWakeAt,
            "evidenceWakeLockedAt" to prefs.evidenceWakeLockedAt,
            "evidenceRoleSeenAt" to prefs.evidenceRoleSeenAt,
        )
    }
}
