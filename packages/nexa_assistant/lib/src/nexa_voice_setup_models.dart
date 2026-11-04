/// Guided voice setup (consent → recorded prompts → calibrated profile).
library;

/// Objective numbers measured on one take (never audio).
final class NexaClipMetrics {
  const NexaClipMetrics({
    required this.durationMs,
    required this.speechMs,
    required this.peakDb,
    required this.speechRmsDb,
    required this.noiseDb,
    required this.snrDb,
  });

  factory NexaClipMetrics.fromMap(Map<Object?, Object?> m) => NexaClipMetrics(
    durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
    speechMs: (m['speechMs'] as num?)?.toInt() ?? 0,
    peakDb: (m['peakDb'] as num?)?.toDouble() ?? -120,
    speechRmsDb: (m['speechRmsDb'] as num?)?.toDouble() ?? -120,
    noiseDb: (m['noiseDb'] as num?)?.toDouble() ?? -120,
    snrDb: (m['snrDb'] as num?)?.toDouble() ?? 0,
  );

  final int durationMs;
  final int speechMs;
  final double peakDb;
  final double speechRmsDb;
  final double noiseDb;
  final double snrDb;
}

/// How the owner threshold was chosen. [mode] `owner_only` measures false
/// rejection only; `with_guests` also measured strangers.
final class NexaSpeakerCalibration {
  const NexaSpeakerCalibration({
    required this.mode,
    required this.threshold,
    required this.ownerP05,
    required this.ownerMedian,
    this.impostorMax,
    this.separable = true,
    this.ownerSamples = 0,
    this.impostorSamples = 0,
    this.identitySamples = 0,
    this.conditions = 0,
  });

  factory NexaSpeakerCalibration.fromMap(Map<Object?, Object?> m) =>
      NexaSpeakerCalibration(
        mode: m['mode'] as String? ?? 'owner_only',
        threshold: (m['threshold'] as num?)?.toDouble() ?? 0,
        ownerP05: (m['ownerP05'] as num?)?.toDouble() ?? 0,
        ownerMedian: (m['ownerMedian'] as num?)?.toDouble() ?? 0,
        impostorMax: (m['impostorMax'] as num?)?.toDouble(),
        separable: m['separable'] != false,
        ownerSamples: (m['ownerSamples'] as num?)?.toInt() ?? 0,
        impostorSamples: (m['impostorSamples'] as num?)?.toInt() ?? 0,
        identitySamples: (m['identitySamples'] as num?)?.toInt() ?? 0,
        conditions: (m['conditions'] as num?)?.toInt() ?? 0,
      );

  final String mode;
  final double threshold;
  final double ownerP05;
  final double ownerMedian;
  final double? impostorMax;

  /// False when strangers' scores overlap the owner's: the model cannot
  /// separate them with these samples.
  final bool separable;
  final int ownerSamples;
  final int impostorSamples;
  final int identitySamples;
  final int conditions;

  bool get measuredStrangers => mode == 'with_guests';
}

final class NexaVoiceSetupStatus {
  const NexaVoiceSetupStatus({
    this.consented = false,
    this.keepClips = false,
    this.clips = const {},
    this.stagedEmbeddings = 0,
    this.calibration,
    this.modelAvailable = false,
    this.profileExists = false,
  });

  factory NexaVoiceSetupStatus.fromMap(Map<Object?, Object?> m) =>
      NexaVoiceSetupStatus(
        consented: m['consented'] == true,
        keepClips: m['keepClips'] == true,
        clips: {
          for (final e in ((m['clips'] as Map?) ?? const {}).entries)
            e.key as String: (e.value as num).toInt(),
        },
        stagedEmbeddings: (m['stagedEmbeddings'] as num?)?.toInt() ?? 0,
        calibration: m['calibration'] is Map
            ? NexaSpeakerCalibration.fromMap(m['calibration'] as Map)
            : null,
        modelAvailable: m['modelAvailable'] == true,
        profileExists: m['profileExists'] == true,
      );

  final bool consented;
  final bool keepClips;

  /// Takes kept so far, keyed `speaker:kind` (e.g. `owner:wake`).
  final Map<String, int> clips;
  final int stagedEmbeddings;
  final NexaSpeakerCalibration? calibration;
  final bool modelAvailable;
  final bool profileExists;

  int count(String speaker, String kind) => clips['$speaker:$kind'] ?? 0;
}

/// One recorded prompt. [reason]: `consent_required`, `permission_denied`,
/// `busy`, `microphone_unavailable`, `no_speech`, `too_short`, `too_long`,
/// `too_quiet`, `too_noisy`, `clipped`.
final class NexaSetupTake {
  const NexaSetupTake({
    required this.ok,
    this.reason,
    this.metrics,
    this.status,
    this.embedded = false,
    this.saved = false,
  });

  factory NexaSetupTake.fromMap(Map<Object?, Object?> m) => NexaSetupTake(
    ok: m['ok'] == true,
    reason: m['reason'] as String?,
    metrics: m['metrics'] is Map
        ? NexaClipMetrics.fromMap(m['metrics'] as Map)
        : null,
    status: m['status'] is Map
        ? NexaVoiceSetupStatus.fromMap(m['status'] as Map)
        : null,
    embedded: m['embedded'] == true,
    saved: m['saved'] == true,
  );

  final bool ok;
  final String? reason;
  final NexaClipMetrics? metrics;
  final NexaVoiceSetupStatus? status;
  final bool embedded;
  final bool saved;
}

/// Result of building the owner profile. [reason]: `consent_required`,
/// `too_few_samples`, `too_few_identity_sentences`, `too_few_conditions`,
/// `busy`, `save_failed`; [have] is how many the plugin has of what is short.
final class NexaSetupFinish {
  const NexaSetupFinish({
    required this.ok,
    this.reason,
    this.have = 0,
    this.calibration,
  });

  factory NexaSetupFinish.fromMap(Map<Object?, Object?> m) => NexaSetupFinish(
    ok: m['ok'] == true,
    reason: m['reason'] as String?,
    have: (m['have'] as num?)?.toInt() ?? 0,
    calibration: m['ok'] == true ? NexaSpeakerCalibration.fromMap(m) : null,
  );

  final bool ok;
  final String? reason;
  final int have;
  final NexaSpeakerCalibration? calibration;
}
