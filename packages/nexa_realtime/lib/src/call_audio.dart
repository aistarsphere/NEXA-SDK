// getAudioProcessingState is experimental in livekit_client 2.13; it is the
// only way to read the echo canceller actually applied. Re-check on upgrades.
// ignore_for_file: experimental_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:nexa_core/nexa_core.dart';

/// Where call audio is playing.
enum NexaAudioRoute { speaker, earpiece, wired, bluetooth, usb, other, unknown }

/// Why the call's microphone is held off by the platform.
enum NexaCallHold {
  /// A phone call (Android audio mode, iOS CallKit; on iOS this includes
  /// VoIP apps that use CallKit, e.g. WhatsApp).
  phoneCall,

  /// Android: another app took audio focus (a VoIP call such as WhatsApp,
  /// a ringtone, a recorder).
  otherApp,
}

/// Platform audio during a call, as read from the OS (no content).
@immutable
final class NexaCallAudioState {
  const NexaCallAudioState({
    this.active = false,
    this.speakerPreferred = true,
    this.route = NexaAudioRoute.unknown,
    this.mode,
    this.requestedMode,
    this.phoneCall = false,
    this.bluetoothPresent = false,
    this.bluetoothPermissionNeeded = false,
    this.platform,
    this.osVersion,
    this.model,
    this.processing = const {},
    this.focus,
    this.hold,
  });

  /// A call is running.
  final bool active;

  /// The user's choice: loudspeaker (default) or earpiece. A connected
  /// headset (wired, USB, Bluetooth) takes priority over either.
  final bool speakerPreferred;

  /// The output actually in use.
  final NexaAudioRoute route;

  /// The platform audio mode as read (Android `in_communication`, iOS
  /// `videoChat` / `voiceChat`); null when unknown.
  final String? mode;

  /// iOS: the mode LiveKit's policy requests for [speakerPreferred]
  /// (`videoChat` with the speaker, `voiceChat` with the earpiece).
  final String? requestedMode;

  /// A phone call (or another CallKit call on iOS) holds the audio.
  final bool phoneCall;
  final bool bluetoothPresent;

  /// Android 12+: a Bluetooth headset can be used only with
  /// `BLUETOOTH_CONNECT`, which is not granted yet.
  final bool bluetoothPermissionNeeded;

  final String? platform;
  final String? osVersion;
  final String? model;

  /// Effective echo cancellation / noise suppression / gain control as
  /// applied by the engine (`platform`, `software`, `disabled`, ...).
  final Map<String, String> processing;

  /// Android: `held`, `lost_transient`, `lost` or `none` (our observer
  /// focus request); null elsewhere.
  final String? focus;

  /// Why the platform holds the microphone off, if it does.
  final NexaCallHold? hold;

  @override
  bool operator ==(Object other) =>
      other is NexaCallAudioState &&
      other.active == active &&
      other.speakerPreferred == speakerPreferred &&
      other.route == route &&
      other.mode == mode &&
      other.requestedMode == requestedMode &&
      other.phoneCall == phoneCall &&
      other.bluetoothPresent == bluetoothPresent &&
      other.bluetoothPermissionNeeded == bluetoothPermissionNeeded &&
      other.platform == platform &&
      other.osVersion == osVersion &&
      other.model == model &&
      other.focus == focus &&
      other.hold == hold &&
      mapEquals(other.processing, processing);

  @override
  int get hashCode => Object.hash(
    active,
    speakerPreferred,
    route,
    mode,
    requestedMode,
    phoneCall,
    bluetoothPresent,
    bluetoothPermissionNeeded,
    platform,
    osVersion,
    model,
    focus,
    hold,
    Object.hashAllUnordered(
      processing.entries.map((e) => '${e.key}=${e.value}'),
    ),
  );

  bool get headset =>
      route == NexaAudioRoute.wired ||
      route == NexaAudioRoute.bluetooth ||
      route == NexaAudioRoute.usb;

  NexaCallAudioState copyWith({
    bool? active,
    bool? speakerPreferred,
    NexaAudioRoute? route,
    String? mode,
    String? requestedMode,
    bool? phoneCall,
    bool? bluetoothPresent,
    bool? bluetoothPermissionNeeded,
    String? platform,
    String? osVersion,
    String? model,
    Map<String, String>? processing,
    String? focus,
    NexaCallHold? hold,
    bool clearHold = false,
  }) => NexaCallAudioState(
    active: active ?? this.active,
    speakerPreferred: speakerPreferred ?? this.speakerPreferred,
    route: route ?? this.route,
    mode: mode ?? this.mode,
    requestedMode: requestedMode ?? this.requestedMode,
    phoneCall: phoneCall ?? this.phoneCall,
    bluetoothPresent: bluetoothPresent ?? this.bluetoothPresent,
    bluetoothPermissionNeeded:
        bluetoothPermissionNeeded ?? this.bluetoothPermissionNeeded,
    platform: platform ?? this.platform,
    osVersion: osVersion ?? this.osVersion,
    model: model ?? this.model,
    processing: processing ?? this.processing,
    focus: focus ?? this.focus,
    hold: clearHold ? null : (hold ?? this.hold),
  );
}

/// Native facts about the audio session (`nexa_realtime/call_audio`).
abstract interface class NexaCallAudioPlatform {
  /// Current facts, or null when the platform cannot tell.
  Future<Map<String, Object?>?> state();

  /// Android: puts the mode back to communication after a phone call left
  /// it changed (the platform echo canceller needs it). Returns the mode.
  Future<String?> reassertCommunicationMode();

  /// Android: takes the observer audio-focus request; true when granted.
  Future<bool> acquireFocus();

  /// Android: gives it back (call ended).
  Future<void> releaseFocus();
}

final class MethodChannelCallAudioPlatform implements NexaCallAudioPlatform {
  const MethodChannelCallAudioPlatform();

  static const _channel = MethodChannel('nexa_realtime/call_audio');

  @override
  Future<Map<String, Object?>?> state() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('state');
      return m;
    } on Object {
      return null; // no plugin (tests, desktop) or a platform error
    }
  }

  @override
  Future<String?> reassertCommunicationMode() async {
    try {
      return await _channel.invokeMethod<String>('reassertCommunicationMode');
    } on Object {
      return null;
    }
  }

  @override
  Future<bool> acquireFocus() async {
    try {
      return await _channel.invokeMethod<bool>('acquireFocus') ?? false;
    } on Object {
      return false; // iOS / no plugin: no focus model
    }
  }

  @override
  Future<void> releaseFocus() async {
    try {
      await _channel.invokeMethod<void>('releaseFocus');
    } on Object {
      // nothing to release
    }
  }
}

/// Call audio for one process: the loudspeaker / earpiece choice, the
/// route and mode actually in use, and phone-call detection. LiveKit owns
/// the audio session; its preferred-device list already switches to a
/// Bluetooth or wired headset when one connects and back to the user's
/// choice when it leaves. This class keeps the choice across rejoins and
/// reports what the OS really did.
///
/// While a call is active the platform is read every [pollInterval] (one
/// cheap method call; no listeners that need permissions).
final class NexaCallAudio {
  NexaCallAudio({
    NexaCallAudioPlatform platform = const MethodChannelCallAudioPlatform(),
    Future<void> Function(bool speaker)? setSpeaker,
    Future<Map<String, String>> Function()? readProcessing,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
    this.pollInterval = const Duration(seconds: 1),
    TargetPlatform? targetPlatform,
  }) : _platform = platform,
       _setSpeaker = setSpeaker ?? _liveKitSpeaker,
       _readProcessing = readProcessing ?? _liveKitProcessing,
       _diagnostics = diagnostics,
       _target = targetPlatform;

  final NexaCallAudioPlatform _platform;
  final Future<void> Function(bool speaker) _setSpeaker;
  final Future<Map<String, String>> Function() _readProcessing;
  final NexaDiagnostics _diagnostics;
  final TargetPlatform? _target;
  final Duration pollInterval;

  final ValueNotifier<NexaCallAudioState> _state = ValueNotifier(
    const NexaCallAudioState(),
  );
  final StreamController<NexaCallHold?> _holds = StreamController.broadcast();
  // Focus changes while the room (re)connects are LiveKit's own focus
  // request, not another app.
  bool _ignoreFocus = true;
  final StreamController<void> _changes = StreamController.broadcast();
  Timer? _poll;
  bool _reading = false;

  ValueListenable<NexaCallAudioState> get state => _state;

  /// Emits the hold reason when the platform takes the audio, null when it
  /// gives it back.
  Stream<NexaCallHold?> get holdChanges => _holds.stream;

  /// Emits when the route, mode or speaker choice changed (for client info).
  Stream<void> get changes => _changes.stream;

  bool get _isIos => (_target ?? defaultTargetPlatform) == TargetPlatform.iOS;

  String? _requestedMode(bool speaker) =>
      _isIos ? (speaker ? 'videoChat' : 'voiceChat') : null;

  /// The room is about to (re)connect: LiveKit will request focus itself.
  void connecting() => _ignoreFocus = true;

  /// A call starts: loudspeaker by default (owner decision), polling on.
  Future<void> beginCall() async {
    _ignoreFocus = true;
    _state.value = NexaCallAudioState(
      active: true,
      requestedMode: _requestedMode(true),
    );
    await _applySpeaker(true);
    _poll?.cancel();
    _poll = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    await refresh();
  }

  /// After every (re)connect: a new room must not reset the user's choice;
  /// also reads the echo canceller actually applied.
  Future<void> afterConnect() async {
    if (!_state.value.active) return;
    await _applySpeaker(_state.value.speakerPreferred);
    // After LiveKit's own request, so this observer request is the newest.
    final granted = await _platform.acquireFocus();
    _ignoreFocus = false;
    _diagnostics.record('voice.audio_focus', {'granted': granted});
    Map<String, String> processing = const {};
    try {
      processing = await _readProcessing();
    } on Object {
      // Experimental API; absent on some platforms.
    }
    _state.value = _state.value.copyWith(processing: processing);
    await refresh();
    final s = _state.value;
    _diagnostics.record('voice.audio_state', {
      'platform': s.platform,
      'os': s.osVersion,
      'mode': s.mode,
      'requested_mode': s.requestedMode,
      'route': s.route.name,
      'speaker_preferred': s.speakerPreferred,
      ...{for (final e in s.processing.entries) 'apm_${e.key}': e.value},
    });
  }

  /// The user picked loudspeaker (true) or earpiece (false).
  Future<void> setSpeakerPreferred(bool speaker) async {
    if (_state.value.speakerPreferred == speaker) return;
    _state.value = _state.value.copyWith(
      speakerPreferred: speaker,
      requestedMode: _requestedMode(speaker),
    );
    _diagnostics.record('voice.audio_route_choice', {'speaker': speaker});
    await _applySpeaker(speaker);
    _changes.add(null);
    await refresh();
  }

  /// A phone call ended: Android may have left the mode changed; route the
  /// call back to the user's choice.
  Future<void> recoverAfterPhoneCall() async {
    final mode = await _platform.reassertCommunicationMode();
    _diagnostics.record('voice.audio_mode_reasserted', {'mode': mode});
    await _applySpeaker(_state.value.speakerPreferred);
    await refresh();
  }

  /// The user wants the call back after another app took focus for good
  /// (Android does not return a permanent loss by itself).
  Future<bool> reacquireFocus() async {
    final granted = await _platform.acquireFocus();
    _diagnostics.record('voice.audio_focus', {
      'granted': granted,
      'cause': 'user',
    });
    await refresh();
    return granted;
  }

  Future<void> endCall() async {
    _poll?.cancel();
    _poll = null;
    _ignoreFocus = true;
    await _platform.releaseFocus();
    _state.value = _state.value.copyWith(
      active: false,
      phoneCall: false,
      clearHold: true,
    );
  }

  /// Reads the platform once and reports changes.
  Future<void> refresh() async {
    if (_reading) return;
    _reading = true;
    try {
      final m = await _platform.state();
      if (m == null) return;
      final before = _state.value;
      final focus = m['focus'] as String?;
      final phoneCall = m['phoneCall'] == true;
      final focusLost =
          !_ignoreFocus && (focus == 'lost' || focus == 'lost_transient');
      final hold = phoneCall
          ? NexaCallHold.phoneCall
          : (focusLost ? NexaCallHold.otherApp : null);
      final next = before.copyWith(
        focus: focus,
        hold: hold,
        clearHold: hold == null,
        route: _route(m['route']),
        mode: m['mode'] as String?,
        phoneCall: phoneCall,
        bluetoothPresent: m['bluetoothPresent'] == true,
        bluetoothPermissionNeeded: m['bluetoothPermissionNeeded'] == true,
        platform: m['platform'] as String?,
        osVersion: m['osVersion'] as String?,
        model: m['model'] as String?,
      );
      _state.value = next;
      if (!before.active || !next.active) return;
      if (next.route != before.route || next.mode != before.mode) {
        _diagnostics.record('voice.audio_route', {
          'route': next.route.name,
          'mode': next.mode,
        });
        _changes.add(null);
      }
      if (next.hold != before.hold) {
        _diagnostics.record('voice.audio_hold', {
          'hold': next.hold?.name,
          'focus': focus,
        });
        _holds.add(next.hold);
      }
    } finally {
      _reading = false;
    }
  }

  Future<void> _applySpeaker(bool speaker) async {
    try {
      await _setSpeaker(speaker);
    } on Object catch (e) {
      _diagnostics.record('voice.audio_route_failed', {
        'error': e.runtimeType.toString(),
      });
    }
  }

  Future<void> dispose() async {
    _poll?.cancel();
    await _holds.close();
    await _changes.close();
    _state.dispose();
  }

  static NexaAudioRoute _route(Object? name) => NexaAudioRoute.values
      .firstWhere((r) => r.name == name, orElse: () => NexaAudioRoute.unknown);

  static Future<void> _liveKitSpeaker(bool speaker) async {
    if (kIsWeb) return;
    await lk.AudioManager.instance.setSpeakerOutputPreferred(speaker);
  }

  static Future<Map<String, String>> _liveKitProcessing() async {
    final s = await lk.AudioManager.instance.getAudioProcessingState();
    if (s == null) return const {};
    return {
      'aec': s.echoCancellation.effective.value,
      'ns': s.noiseSuppression.effective.value,
      'agc': s.autoGainControl.effective.value,
    };
  }
}
