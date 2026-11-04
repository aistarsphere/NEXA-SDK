/// How strict local activation is (both the phrase and the voice check).
enum NexaWakeSensitivity { strict, normal, relaxed }

/// Where the compact assistant panel appears.
enum NexaPanelPosition { bottom, top, left, right }

/// Device and setup state for the assistant settings screen.
final class NexaAssistantStatus {
  const NexaAssistantStatus({
    required this.platformSupported,
    this.sdkInt,
    this.release,
    this.manufacturer,
    this.model,
    this.assistantRoleAvailable = false,
    this.isDefaultAssistant = false,
    this.assistantServiceBound = false,
    this.hardwareHotword = 'unavailable',
    this.microphonePermission = false,
    this.notificationsEnabled = false,
    this.ignoringBatteryOptimizations = false,
    this.wakeEnabled = false,
    this.listenerState = 'stopped',
    this.listenerReason,
    this.enrolled = false,
    this.enrolledSamples = 0,
    this.speakerEnrolled = false,
    this.speakerModelAvailable = false,
    this.speakerModel,
    this.requireOwnerVoice = false,
    this.sensitivity = NexaWakeSensitivity.normal,
    this.wakeDetector = 'template',
    this.wakePhraseId = 'yaameer',
    this.wakePhrases = const [],
    this.locked = false,
    this.assistantRoleHeld,
    this.assistantSetting,
    this.voiceInteractionSetting,
    this.panelPosition = NexaPanelPosition.bottom,
    this.idleTimeoutSeconds = 60,
    this.lastActivation,
    this.lastEnd,
  });

  /// Not Android: nothing here applies.
  static const unsupported = NexaAssistantStatus(platformSupported: false);

  factory NexaAssistantStatus.fromMap(Map<Object?, Object?> m) =>
      NexaAssistantStatus(
        platformSupported: m['platformSupported'] == true,
        sdkInt: m['sdkInt'] as int?,
        release: m['release'] as String?,
        manufacturer: m['manufacturer'] as String?,
        model: m['model'] as String?,
        assistantRoleAvailable: m['assistantRoleAvailable'] == true,
        isDefaultAssistant: m['isDefaultAssistant'] == true,
        assistantServiceBound: m['assistantServiceBound'] == true,
        hardwareHotword: m['hardwareHotword'] as String? ?? 'unavailable',
        microphonePermission: m['microphonePermission'] == true,
        notificationsEnabled: m['notificationsEnabled'] == true,
        ignoringBatteryOptimizations: m['ignoringBatteryOptimizations'] == true,
        wakeEnabled: m['wakeEnabled'] == true,
        listenerState: m['listenerState'] as String? ?? 'stopped',
        listenerReason: m['listenerReason'] as String?,
        enrolled: m['enrolled'] == true,
        enrolledSamples: m['enrolledSamples'] as int? ?? 0,
        speakerEnrolled: m['speakerEnrolled'] == true,
        speakerModelAvailable: m['speakerModelAvailable'] == true,
        speakerModel: m['speakerModel'] as String?,
        requireOwnerVoice: m['requireOwnerVoice'] == true,
        wakeDetector: m['wakeDetector'] as String? ?? 'template',
        wakePhraseId: m['wakePhraseId'] as String? ?? 'yaameer',
        wakePhrases: [
          for (final p in (m['wakePhrases'] as List? ?? const []))
            NexaWakePhrase(
              id: (p as Map)['id'] as String,
              label: p['label'] as String,
              installed: p['installed'] == true,
            ),
        ],
        sensitivity: NexaWakeSensitivity.values.firstWhere(
          (s) => s.name == m['sensitivity'],
          orElse: () => NexaWakeSensitivity.normal,
        ),
        locked: m['locked'] == true,
        assistantRoleHeld: m['assistantRoleHeld'] as bool?,
        assistantSetting: m['assistantSetting'] as bool?,
        voiceInteractionSetting: m['voiceInteractionSetting'] as bool?,
        panelPosition: NexaPanelPosition.values.firstWhere(
          (p) => p.name == m['panelPosition'],
          orElse: () => NexaPanelPosition.bottom,
        ),
        idleTimeoutSeconds: m['idleTimeoutSeconds'] as int? ?? 60,
        lastActivation: m['lastActivation'] as String?,
        lastEnd: m['lastEnd'] as String?,
      );

  final bool platformSupported;
  final int? sdkInt;
  final String? release;
  final String? manufacturer;
  final String? model;
  final bool assistantRoleAvailable;
  final bool isDefaultAssistant;

  /// Android has bound our assistant service (it is the active assistant).
  final bool assistantServiceBound;

  /// `requires_system_app`: Android's always-on hotword API is reserved
  /// for preinstalled assistants; the software listener is used instead.
  final String hardwareHotword;
  final bool microphonePermission;
  final bool notificationsEnabled;
  final bool ignoringBatteryOptimizations;
  final bool wakeEnabled;

  /// `running`, `paused`, `stopped` or `error`.
  final String listenerState;
  final String? listenerReason;
  final bool enrolled;
  final int enrolledSamples;
  final bool speakerEnrolled;
  final bool speakerModelAvailable;
  final String? speakerModel;
  final bool requireOwnerVoice;

  /// `neural` (a trained acoustic model for the phrase) or `template` (the
  /// older personal enrolment).
  final String wakeDetector;
  final String wakePhraseId;

  /// Phrases the plugin knows; only [NexaWakePhrase.installed] ones have an
  /// acoustic model and can be selected.
  final List<NexaWakePhrase> wakePhrases;

  /// Label of the selected phrase, or null when none is listed.
  String? get wakePhraseLabel =>
      wakePhrases.where((p) => p.id == wakePhraseId).firstOrNull?.label;
  final NexaWakeSensitivity sensitivity;
  final bool locked;

  /// The individual Android signals behind [isDefaultAssistant] (null:
  /// Android does not let the app read that one).
  final bool? assistantRoleHeld;
  final bool? assistantSetting;
  final bool? voiceInteractionSetting;

  final NexaPanelPosition panelPosition;

  /// Panel conversation idle timeout; 0 = off.
  final int idleTimeoutSeconds;

  /// Diagnostics: `source@epochMs` of the last activation and
  /// `reason@epochMs` of the last panel call end.
  final String? lastActivation;
  final String? lastEnd;

  bool get listening => listenerState == 'running';
}

/// Events from the device.
sealed class NexaAssistantEvent {
  const NexaAssistantEvent();

  static NexaAssistantEvent? fromMap(Map<Object?, Object?> m) =>
      switch (m['type']) {
        'activation' => NexaAssistantActivation.fromMap(m),
        'listener' => NexaWakeListenerChanged(
          m['state'] as String? ?? 'stopped',
          m['reason'] as String?,
        ),
        'decision' || 'test' => NexaWakeDecision.fromMap(m),
        'recording' => NexaRecordingChanged(active: m['active'] == true),
        'setup' => NexaSetupEvent(
          stage: m['stage'] as String? ?? '',
          levelDb: (m['db'] as num?)?.toDouble(),
          speaking: m['speaking'] == true,
        ),
        'surface' => NexaAssistantSurface.fromMap(m),
        'call' when m['event'] == 'end_requested' => NexaCallEndRequested(
          reason: m['reason'] as String? ?? 'notification',
        ),
        _ => null,
      };
}

/// The assistant was opened: assist gesture/button (`system`), from the
/// lock screen (`keyguard`), the wake phrase (`wake`) or an assist intent.
final class NexaAssistantActivation extends NexaAssistantEvent {
  const NexaAssistantActivation({
    required this.source,
    required this.locked,
    this.verified,
    this.at,
  });

  factory NexaAssistantActivation.fromMap(Map<Object?, Object?> m) =>
      NexaAssistantActivation(
        source: m['source'] as String? ?? 'system',
        locked: m['locked'] == true,
        verified: m['verified'] as bool?,
        at: switch (m['at']) {
          final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
          _ => null,
        },
      );

  final String source;

  /// The device was locked: show nothing private until [NexaAssistant.requestUnlock].
  final bool locked;

  /// Owner-voice result for the wake phrase; null when not checked.
  final bool? verified;
  final DateTime? at;
}

/// The system assistant window: the compact panel is showing (render it)
/// or was hidden (`dismissed` by the system or user, `closed` by the host,
/// `expand` to the full app).
final class NexaAssistantSurface extends NexaAssistantEvent {
  const NexaAssistantSurface({
    required this.panel,
    this.position = NexaPanelPosition.bottom,
    this.source,
    this.verified,
    this.reason,
  });

  static const none = NexaAssistantSurface(panel: false, reason: 'none');

  factory NexaAssistantSurface.fromMap(Map<Object?, Object?> m) =>
      NexaAssistantSurface(
        panel: m['surface'] == 'panel',
        position: NexaPanelPosition.values.firstWhere(
          (p) => p.name == m['position'],
          orElse: () => NexaPanelPosition.bottom,
        ),
        source: m['source'] as String?,
        verified: m['verified'] as bool?,
        reason: m['reason'] as String?,
      );

  final bool panel;
  final NexaPanelPosition position;
  final String? source;
  final bool? verified;
  final String? reason;
}

final class NexaWakeListenerChanged extends NexaAssistantEvent {
  const NexaWakeListenerChanged(this.state, this.reason);
  final String state;
  final String? reason;
}

/// One local decision (diagnostics and the settings "Test").
final class NexaWakeDecision extends NexaAssistantEvent {
  const NexaWakeDecision({
    required this.ok,
    required this.accepted,
    required this.reason,
    this.keywordDistance,
    this.keywordThreshold,
    this.speakerScore,
    this.speakerThreshold,
    this.durationMs,
  });

  factory NexaWakeDecision.fromMap(Map<Object?, Object?> m) => NexaWakeDecision(
    ok: m['ok'] != false,
    accepted: m['accepted'] == true,
    reason: m['reason'] as String? ?? 'unknown',
    keywordDistance: (m['keywordDistance'] as num?)?.toDouble(),
    keywordThreshold: (m['keywordThreshold'] as num?)?.toDouble(),
    speakerScore: (m['speakerScore'] as num?)?.toDouble(),
    speakerThreshold: (m['speakerThreshold'] as num?)?.toDouble(),
    durationMs: m['durationMs'] as int?,
  );

  /// False when nothing could be evaluated (see [reason]).
  final bool ok;
  final bool accepted;

  /// `accepted`, `phrase_mismatch`, `speaker_mismatch`, `replay_suspected`,
  /// `speaker_unavailable`, `refractory`, `no_speech`, `not_enrolled`,
  /// `permission_denied`, `microphone_unavailable`.
  final String reason;
  final double? keywordDistance;
  final double? keywordThreshold;
  final double? speakerScore;
  final double? speakerThreshold;
  final int? durationMs;
}

/// The user asked to end the call outside the app: the "End call" action
/// of the call notification (`notification`) or the app was swiped away
/// (`task_removed`). The host ends the call.
final class NexaCallEndRequested extends NexaAssistantEvent {
  const NexaCallEndRequested({required this.reason});
  final String reason;
}

/// Result of asking for the in-call foreground service.
final class NexaCallServiceStart {
  const NexaCallServiceStart({required this.ok, this.reason});

  factory NexaCallServiceStart.fromMap(Map<Object?, Object?> m) =>
      NexaCallServiceStart(ok: m['ok'] == true, reason: m['reason'] as String?);

  /// The service holds the microphone while the app is in the background.
  final bool ok;

  /// Why not: `unsupported`, `not_foreground` (Android 14+ only allows the
  /// start while the app is on screen) or `fgs_blocked`.
  final String? reason;
}

final class NexaRecordingChanged extends NexaAssistantEvent {
  const NexaRecordingChanged({required this.active});
  final bool active;
}

/// Live status of the voice-setup recorder, in this order: `opening` (the
/// microphone is starting), `ready` (speak now), `level` (meter; [speaking]
/// is true while speech is detected), `speech` (speech detected), `processing`
/// (speech ended, finishing the take).
final class NexaSetupEvent extends NexaAssistantEvent {
  const NexaSetupEvent({
    required this.stage,
    this.levelDb,
    this.speaking = false,
  });
  final String stage;
  final double? levelDb;
  final bool speaking;
}

/// One enrolment recording.
final class NexaEnrollmentSample {
  const NexaEnrollmentSample({
    required this.ok,
    required this.count,
    this.reason,
    this.durationMs,
  });

  factory NexaEnrollmentSample.fromMap(Map<Object?, Object?> m) =>
      NexaEnrollmentSample(
        ok: m['ok'] == true,
        count: m['count'] as int? ?? 0,
        reason: m['reason'] as String?,
        durationMs: m['durationMs'] as int?,
      );

  final bool ok;

  /// Accepted samples so far.
  final int count;

  /// `no_speech`, `too_short`, `too_long`, `too_quiet`, `clipped`,
  /// `inconsistent`, `permission_denied`, `microphone_unavailable`, `busy`.
  final String? reason;
  final int? durationMs;
}

final class NexaEnrollmentResult {
  const NexaEnrollmentResult({
    required this.ok,
    this.count = 0,
    this.speaker = false,
    this.reason,
  });

  factory NexaEnrollmentResult.fromMap(Map<Object?, Object?> m) =>
      NexaEnrollmentResult(
        ok: m['ok'] == true,
        count: m['count'] as int? ?? 0,
        speaker: m['speaker'] == true,
        reason: m['reason'] as String?,
      );

  final bool ok;
  final int count;

  /// A voice (speaker) profile was created as well.
  final bool speaker;

  /// `too_few_samples`, `save_failed`.
  final String? reason;
}

/// Outcome of turning a feature on or off.
enum NexaAssistantToggle {
  on,
  off,
  permissionDenied,
  notEnrolled,
  notInForeground,
  modelUnavailable,
  unsupported;

  static NexaAssistantToggle parse(String? s) => switch (s) {
    'on' => on,
    'off' => off,
    'permission_denied' => permissionDenied,
    'not_enrolled' => notEnrolled,
    'not_in_foreground' => notInForeground,
    'model_unavailable' => modelUnavailable,
    _ => unsupported,
  };
}

enum NexaUnlockResult {
  unlocked,
  cancelled,
  error,
  unsupported;

  static NexaUnlockResult parse(String? s) => switch (s) {
    'unlocked' => unlocked,
    'cancelled' => cancelled,
    'error' => error,
    _ => unsupported,
  };
}

/// A wake phrase the plugin can listen for.
final class NexaWakePhrase {
  const NexaWakePhrase({
    required this.id,
    required this.label,
    required this.installed,
  });

  final String id;
  final String label;

  /// True when its trained acoustic model ships with the app.
  final bool installed;
}
