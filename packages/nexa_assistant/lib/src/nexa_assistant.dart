import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nexa_assistant/src/nexa_assistant_models.dart';
import 'package:nexa_assistant/src/nexa_assistant_setup.dart';
import 'package:nexa_assistant/src/nexa_voice_setup_models.dart';

/// Android assistant integration for a NEXA host app.
///
/// * The system assistant role (the user picks the app in Android's own
///   "Default digital assistant" screen) and its assist gesture/button.
/// * An optional wake phrase detected **on the device** from the owner's
///   own recorded samples, with an optional owner-voice check. Nothing is
///   sent to a server and nothing is stored as audio.
/// * Activations arrive on [activations]; the host then opens its voice
///   conversation. The plugin never connects to a backend itself.
///
/// On other platforms everything reports [NexaAssistantStatus.unsupported].
class NexaAssistant {
  NexaAssistant({MethodChannel? methods, EventChannel? events, bool? supported})
    : _methods = methods ?? const MethodChannel('nexa_assistant/methods'),
      _eventChannel = events ?? const EventChannel('nexa_assistant/events'),
      supported =
          supported ??
          (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final MethodChannel _methods;
  final EventChannel _eventChannel;
  final bool supported;

  late final Stream<NexaAssistantEvent> events = supported
      ? _eventChannel
            .receiveBroadcastStream()
            .map((e) => NexaAssistantEvent.fromMap(e as Map<Object?, Object?>))
            .where((e) => e != null)
            .cast<NexaAssistantEvent>()
            .asBroadcastStream()
      : const Stream.empty();

  Stream<NexaAssistantActivation> get activations =>
      events.where((e) => e is NexaAssistantActivation).cast();

  Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    if (!supported) return null;
    return _methods.invokeMethod<T>(method, args);
  }

  Future<Map<Object?, Object?>> _map(
    String m, [
    Map<String, Object?>? a,
  ]) async => await _call<Map<Object?, Object?>>(m, a) ?? const {'ok': false};

  Future<NexaAssistantStatus> status() async {
    final m = await _call<Map<Object?, Object?>>('status');
    return m == null
        ? NexaAssistantStatus.unsupported
        : NexaAssistantStatus.fromMap(m);
  }

  /// How the host names its wake phrase in the listening notification.
  Future<void> configure({String? phraseLabel}) =>
      _call<void>('configure', {'phraseLabel': phraseLabel});

  /// The activation that cold-started the app, if any (once).
  Future<NexaAssistantActivation?> takePendingActivation() async {
    final m = await _call<Map<Object?, Object?>>('takePendingActivation');
    return m == null ? null : NexaAssistantActivation.fromMap(m);
  }

  /// What the system assistant window shows right now (for a cold start
  /// straight into the panel).
  Future<NexaAssistantSurface> surface() async {
    final m = await _call<Map<Object?, Object?>>('surface');
    return m == null
        ? NexaAssistantSurface.none
        : NexaAssistantSurface.fromMap(m);
  }

  /// Hides the panel after the host ended the call ([reason] is recorded:
  /// `user_closed`, `idle_timeout`, `call_ended`).
  Future<void> closePanel(String reason) =>
      _call<void>('closePanel', {'reason': reason});

  /// Hides the panel and opens the full app; the call continues there.
  Future<void> expandPanel() => _call<void>('expandPanel');

  Future<void> setPanelPosition(NexaPanelPosition value) =>
      _call<void>('setPanelPosition', {'value': value.name});

  /// 0 turns the panel's idle timeout off.
  Future<void> setIdleTimeout(int seconds) =>
      _call<void>('setIdleTimeout', {'seconds': seconds});

  /// Records why a panel conversation ended (diagnostics).
  Future<void> reportSessionEnd(String reason) =>
      _call<void>('reportSessionEnd', {'reason': reason});

  /// Android's own default-assistant chooser. The user decides.
  Future<bool> openAssistantSettings() async =>
      await _call<bool>('openAssistantSettings') ?? false;

  Future<bool> openBatterySettings() async =>
      await _call<bool>('openBatterySettings') ?? false;

  /// The manufacturer's background/autostart screen where one exists.
  Future<bool> openBackgroundSettings() async =>
      await _call<bool>('openBackgroundSettings') ?? false;

  Future<bool> openAppSettings() async =>
      await _call<bool>('openAppSettings') ?? false;

  /// Starts or stops listening for the wake phrase. Starting needs the
  /// microphone permission, an enrolled phrase and the app on screen.
  Future<NexaAssistantToggle> setWakeEnabled(bool enabled) async =>
      NexaAssistantToggle.parse(
        await _call<String>('setWakeEnabled', {'enabled': enabled}),
      );

  /// Accept the wake phrase only in the enrolled owner's voice.
  Future<NexaAssistantToggle> setRequireOwnerVoice(bool enabled) async =>
      NexaAssistantToggle.parse(
        await _call<String>('setRequireOwnerVoice', {'enabled': enabled}),
      );

  // ----------------------------------------------- assistant setup facts

  /// What Android says about this device right now (never cached).
  Future<NexaAssistantCapabilities> capabilities() async {
    final m = await _call<Map<Object?, Object?>>('capabilities');
    return m == null
        ? const NexaAssistantCapabilities()
        : NexaAssistantCapabilities.fromMap(m);
  }

  /// Asks Android for the assistant role (the official request). The map
  /// carries `started`, `resultCode` and `held` as read from the system after
  /// the screen closed; [reason] explains why nothing opened (`already_held`,
  /// `role_unavailable`, `not_resolvable`, `api_too_old`...).
  Future<NexaRoleRequest> requestAssistantRole() async =>
      NexaRoleRequest.fromMap(await _map('requestAssistantRole'));

  /// Opens a settings destination only if this device can resolve it:
  /// `opened`, `not_resolvable`, `failed` or `unknown`.
  Future<String> openSetting(String id) async =>
      (await _call<String>('openSetting', {'id': id})) ?? 'unknown';

  // ------------------------------------------------------ guided voice setup

  /// Records the owner's explicit consent. Nothing records before this with
  /// `accepted: true`; `accepted: false` deletes everything. [keepClips]
  /// keeps the recordings on this phone (USB-readable, for training the
  /// wake model) instead of only measuring them.
  Future<NexaVoiceSetupStatus> voiceSetupConsent({
    required bool accepted,
    bool keepClips = false,
  }) async => NexaVoiceSetupStatus.fromMap(
    await _map('voiceSetupConsent', {
      'accepted': accepted,
      'keepClips': keepClips,
    }),
  );

  Future<NexaVoiceSetupStatus> voiceSetupStatus() async =>
      NexaVoiceSetupStatus.fromMap(await _map('voiceSetupStatus'));

  /// Holds the wake listener off the microphone while the setup is open.
  Future<void> voiceSetupBegin() => _call<void>('voiceSetupBegin');
  Future<void> voiceSetupEnd() => _call<void>('voiceSetupEnd');

  /// Records one prompt. [kind] `wake`, `identity`, `negative` or
  /// `background`; [speaker] `owner` or `guest_N`; [tags] describe the
  /// condition (`normal`, `quiet`, `loud`, `fast`, `slow`, `near`, `far`,
  /// `noise`) and relax the quality checks accordingly.
  Future<NexaSetupTake> voiceSetupRecord({
    required String kind,
    required String promptId,
    List<String> tags = const [],
    String speaker = 'owner',
    int maxMs = 6000,
  }) async => NexaSetupTake.fromMap(
    await _map('voiceSetupRecord', {
      'kind': kind,
      'promptId': promptId,
      'tags': tags,
      'speaker': speaker,
      'maxMs': maxMs,
    }),
  );

  /// Builds the owner profile. [quick] asks for fewer takes (the two-minute
  /// setup); the full protocol is for calibration and testing.
  /// Live recorder status while [voiceSetupRecord] runs.
  Stream<NexaSetupEvent> get setupEvents =>
      events.where((e) => e is NexaSetupEvent).cast();

  /// Stops the recording in progress (it ends as `interrupted`).
  Future<void> voiceSetupCancel() => _call<void>('voiceSetupCancel');

  Future<NexaSetupFinish> voiceSetupFinish({bool quick = false}) async =>
      NexaSetupFinish.fromMap(await _map('voiceSetupFinish', {'quick': quick}));

  /// Deletes recordings, the voice profile and its key, the calibration and
  /// the consent.
  Future<NexaVoiceSetupStatus> voiceSetupDelete() async =>
      NexaVoiceSetupStatus.fromMap(await _map('voiceSetupDelete'));

  /// Listens for [seconds] with the acoustic model of phrase [id] and reports
  /// detections and the best score; nothing opens and nothing is stored.
  Future<NexaWakeTest> wakeTest({String? id, int seconds = 10}) async =>
      NexaWakeTest.fromMap(
        await _map('wakeTest', {'id': id, 'seconds': seconds}),
      );

  Stream<NexaWakeTestEvent> get wakeTestEvents =>
      events.where((e) => e is NexaWakeTestEvent).cast();

  /// Switches the active acoustic detector to the installed phrase [id].
  /// `ok`, or `not_installed` when no trained model exists for it (a phrase
  /// cannot be made up from text).
  Future<String> setWakePhrase(String id) async =>
      (await _call<String>('setWakePhrase', {'id': id})) ?? 'not_installed';

  Future<void> setSensitivity(NexaWakeSensitivity value) =>
      _call<void>('setSensitivity', {'value': value.name});

  /// Releases the microphone (e.g. while the host's voice call runs).
  Future<void> suspendListening([String reason = 'host']) =>
      _call<void>('suspendListening', {'reason': reason});

  Future<void> resumeListening() => _call<void>('resumeListening');

  /// Keeps the wake listener off the microphone while [inUse] is true
  /// (the host's own voice conversation). Returns a function that stops
  /// following it.
  VoidCallback followMicrophoneUse(ValueListenable<bool> inUse) {
    var last = inUse.value;
    if (last) unawaited(suspendListening('conversation'));
    void sync() {
      final now = inUse.value;
      if (now == last) return;
      last = now;
      unawaited(now ? suspendListening('conversation') : resumeListening());
    }

    inUse.addListener(sync);
    return () => inUse.removeListener(sync);
  }

  // ------------------------------------------------------- call service

  /// Keeps the microphone alive while a call runs in the background (an
  /// Android foreground service with an ongoing notification and an "End
  /// call" action; its press arrives as [NexaCallEndRequested]). Android
  /// 14+ only allows the start while the app is on screen; otherwise the
  /// result says why and the call continues without it.
  Future<NexaCallServiceStart> callStarted({
    required String title,
    required String endLabel,
    String? conversationId,
  }) async {
    final m = await _call<Map<Object?, Object?>>('callStarted', {
      'title': title,
      'endLabel': endLabel,
      'conversationId': ?conversationId,
    });
    return m == null
        ? const NexaCallServiceStart(ok: false, reason: 'unsupported')
        : NexaCallServiceStart.fromMap(m);
  }

  /// Releases the call service (safe when none runs).
  Future<void> callEnded() => _call<void>('callEnded');

  // ---------------------------------------------------------- enrolment

  /// Begins a new local enrolment (pauses listening).
  Future<void> startEnrollment() => _call<void>('enrollmentStart');

  /// Records one sample of the phrase; audio stays in memory.
  Future<NexaEnrollmentSample> recordEnrollmentSample({
    Duration timeout = const Duration(seconds: 6),
  }) async => NexaEnrollmentSample.fromMap(
    await _map('enrollmentRecord', {'timeoutMs': timeout.inMilliseconds}),
  );

  /// Saves the encrypted profile and discards the audio.
  Future<NexaEnrollmentResult> finishEnrollment() async =>
      NexaEnrollmentResult.fromMap(await _map('enrollmentFinish'));

  Future<void> cancelEnrollment() => _call<void>('enrollmentCancel');

  /// Turns listening off and deletes the profile and its key.
  Future<void> deleteVoiceProfile() => _call<void>('deleteVoiceProfile');

  /// Developer benchmark: records [seconds] of audio as a labelled WAV in
  /// the app's own files folder (only after the user consented in a dev
  /// screen). Never uploaded.
  Future<Map<Object?, Object?>> benchRecord(String label, int seconds) =>
      _map('benchRecord', {'label': label, 'seconds': seconds});

  /// Developer benchmark: on-device speed of the speech-embedding wake
  /// detector (models pushed to files/models/ by the developer).
  Future<Map<Object?, Object?>> benchModelSpeed() => _map('benchModelSpeed');

  Future<int> benchClear() async => await _call<int>('benchClear') ?? 0;

  Future<int> benchCount() async => await _call<int>('benchCount') ?? 0;

  /// Listens once and reports what the detector decided (no activation).
  Future<NexaWakeDecision> testListen({
    Duration timeout = const Duration(seconds: 6),
  }) async => NexaWakeDecision.fromMap(
    await _map('testListen', {'timeoutMs': timeout.inMilliseconds}),
  );

  // --------------------------------------------------------- lock screen

  /// Asks Android to unlock (PIN, pattern or biometrics).
  Future<NexaUnlockResult> requestUnlock() async =>
      NexaUnlockResult.parse(await _call<String>('requestUnlock'));

  /// Stops showing above the lock screen; optionally leaves the app.
  Future<void> endLockScreenSession({bool moveToBack = false}) =>
      _call<void>('endLockScreenSession', {'moveToBack': moveToBack});
}
