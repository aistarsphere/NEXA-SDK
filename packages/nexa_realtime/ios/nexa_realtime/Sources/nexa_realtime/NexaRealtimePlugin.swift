import AVFoundation
import CallKit
import Flutter
import UIKit

/// Read-only facts about the audio session during a voice call: the mode
/// actually set, the output in use, and whether a phone call (or another
/// CallKit call) holds the audio. LiveKit owns the session; nothing here
/// changes it. No audio and no permissions.
public class NexaRealtimePlugin: NSObject, FlutterPlugin {
  // Phone calls come only from CallKit's observer: it clears itself when a
  // call ends. (An audio-session interruption flag was not used: iOS does
  // not guarantee the matching "ended" notification, so it could stick and
  // keep the microphone off for the rest of the call.)
  private let callObserver = CXCallObserver()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "nexa_realtime/call_audio",
      binaryMessenger: registrar.messenger()
    )
    let instance = NexaRealtimePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "state":
      result(state())
    case "reassertCommunicationMode":
      // LiveKit re-activates the session after an interruption on iOS.
      result(modeName(AVAudioSession.sharedInstance().mode))
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func state() -> [String: Any?] {
    let session = AVAudioSession.sharedInstance()
    let outputs = session.currentRoute.outputs
    let inputs = session.availableInputs ?? []
    let otherCall = callObserver.calls.contains { !$0.hasEnded }
    return [
      "platform": "ios",
      "osVersion": "iOS \(UIDevice.current.systemVersion)",
      "model": machine(),
      "mode": modeName(session.mode),
      "category": session.category.rawValue.replacingOccurrences(
        of: "AVAudioSessionCategory", with: ""),
      "route": outputs.first.map { route($0.portType) } ?? "unknown",
      "phoneCall": otherCall,
      "bluetoothPresent": outputs.contains { route($0.portType) == "bluetooth" }
        || inputs.contains { route($0.portType) == "bluetooth" },
      "bluetoothPermissionNeeded": false,
    ]
  }

  private func modeName(_ mode: AVAudioSession.Mode) -> String {
    let raw = mode.rawValue.replacingOccurrences(of: "AVAudioSessionMode", with: "")
    return raw.prefix(1).lowercased() + raw.dropFirst()
  }

  private func route(_ port: AVAudioSession.Port) -> String {
    switch port {
    case .builtInSpeaker: return "speaker"
    case .builtInReceiver: return "earpiece"
    case .headphones, .headsetMic: return "wired"
    case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE: return "bluetooth"
    case .usbAudio: return "usb"
    default: return "other"
    }
  }

  private func machine() -> String {
    var info = utsname()
    uname(&info)
    let mirror = Mirror(reflecting: info.machine)
    return mirror.children.reduce(into: "") { acc, el in
      if let v = el.value as? Int8, v != 0 { acc.append(Character(UnicodeScalar(UInt8(v)))) }
    }
  }
}
