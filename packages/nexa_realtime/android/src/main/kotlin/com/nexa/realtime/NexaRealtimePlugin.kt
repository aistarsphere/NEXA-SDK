package com.nexa.realtime

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Read-only facts about the platform audio during a voice call: the audio
 * mode, the output actually in use, whether a phone call holds the audio,
 * whether a Bluetooth headset is present. LiveKit owns the session (mode,
 * focus, routing); this plugin only reads it, plus one repair:
 * [reassertCommunicationMode] after a phone call left the mode changed.
 * No audio, no permissions requested here.
 */
class NexaRealtimePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "nexa_realtime/call_audio")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "state" -> result.success(state())
            "reassertCommunicationMode" -> result.success(reassertCommunicationMode())
            else -> result.notImplemented()
        }
    }

    private val audio: AudioManager
        get() = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun state(): Map<String, Any?> {
        val am = audio
        val mode = am.mode
        return mapOf(
            "platform" to "android",
            "osVersion" to "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})",
            "model" to "${Build.MANUFACTURER} ${Build.MODEL}",
            "mode" to modeName(mode),
            "route" to route(am),
            "phoneCall" to isPhoneCallMode(mode),
            "bluetoothPresent" to bluetoothPresent(am),
            "bluetoothPermissionNeeded" to bluetoothPermissionNeeded(),
            "aecAvailable" to AcousticEchoCanceler.isAvailable(),
            "nsAvailable" to NoiseSuppressor.isAvailable(),
            "agcAvailable" to AutomaticGainControl.isAvailable(),
        )
    }

    /** After a phone call, Android may leave the mode at NORMAL; without
     *  MODE_IN_COMMUNICATION the platform echo canceller is not applied. */
    private fun reassertCommunicationMode(): String {
        val am = audio
        if (am.mode != AudioManager.MODE_IN_COMMUNICATION && !isPhoneCallMode(am.mode)) {
            am.mode = AudioManager.MODE_IN_COMMUNICATION
        }
        return modeName(am.mode)
    }

    private fun isPhoneCallMode(mode: Int): Boolean =
        mode == AudioManager.MODE_RINGTONE ||
            mode == AudioManager.MODE_IN_CALL ||
            mode == 4 || // MODE_CALL_SCREENING (API 30)
            mode == 5 // MODE_CALL_REDIRECT (API 33)

    private fun modeName(mode: Int): String = when (mode) {
        AudioManager.MODE_NORMAL -> "normal"
        AudioManager.MODE_RINGTONE -> "ringtone"
        AudioManager.MODE_IN_CALL -> "in_call"
        AudioManager.MODE_IN_COMMUNICATION -> "in_communication"
        4 -> "call_screening"
        5 -> "call_redirect"
        6 -> "communication_redirect"
        else -> "mode_$mode"
    }

    private fun route(am: AudioManager): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            am.communicationDevice?.let { return routeOf(it.type) }
        }
        @Suppress("DEPRECATION")
        return when {
            am.isBluetoothScoOn -> "bluetooth"
            am.isSpeakerphoneOn -> "speaker"
            outputs(am).any { routeOf(it.type) == "wired" } -> "wired"
            outputs(am).any { routeOf(it.type) == "usb" } -> "usb"
            else -> "earpiece"
        }
    }

    private fun routeOf(type: Int): String = when (type) {
        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "speaker"
        AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "earpiece"
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired"
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE -> "usb"
        AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
        AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
        26, // TYPE_BLE_HEADSET (API 31)
        27 -> "bluetooth" // TYPE_BLE_SPEAKER (API 31)
        else -> "other"
    }

    private fun outputs(am: AudioManager): Array<AudioDeviceInfo> =
        am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)

    /** Listing devices needs no Bluetooth permission. */
    private fun bluetoothPresent(am: AudioManager): Boolean =
        outputs(am).any { routeOf(it.type) == "bluetooth" }

    private fun bluetoothPermissionNeeded(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            context.checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) !=
            PackageManager.PERMISSION_GRANTED
}
