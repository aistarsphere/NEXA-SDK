import 'package:flutter/material.dart';
import 'package:nexa_ui/src/theme/mocha_palette.dart';

/// Chat-specific semantic colours that Material's [ColorScheme] does not
/// cover. Exposed as a [ThemeExtension] so components read
/// `NexaColors.of(context)` instead of hard-coding palette values.
@immutable
final class NexaColors extends ThemeExtension<NexaColors> {
  const NexaColors({
    required this.userBubble,
    required this.onUserBubble,
    required this.assistantBubble,
    required this.onAssistantBubble,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.voiceActive,
    required this.successContainer,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
  });

  /// Light default.
  static const light = NexaColors(
    userBubble: MochaPalette.lightUserBubble,
    onUserBubble: MochaPalette.lightOnUserBubble,
    assistantBubble: MochaPalette.lightAssistantBubble,
    onAssistantBubble: MochaPalette.lightOnAssistantBubble,
    success: MochaPalette.lightSuccess,
    onSuccess: MochaPalette.lightOnSuccess,
    warning: MochaPalette.lightWarning,
    onWarning: MochaPalette.lightOnWarning,
    voiceActive: MochaPalette.lightVoiceActive,
    successContainer: MochaPalette.lightSuccessContainer,
    warningContainer: MochaPalette.lightWarningContainer,
    info: MochaPalette.lightInfo,
    infoContainer: MochaPalette.lightInfoContainer,
  );

  /// Dark default.
  static const dark = NexaColors(
    userBubble: MochaPalette.darkUserBubble,
    onUserBubble: MochaPalette.darkOnUserBubble,
    assistantBubble: MochaPalette.darkAssistantBubble,
    onAssistantBubble: MochaPalette.darkOnAssistantBubble,
    success: MochaPalette.darkSuccess,
    onSuccess: MochaPalette.darkOnSuccess,
    warning: MochaPalette.darkWarning,
    onWarning: MochaPalette.darkOnWarning,
    voiceActive: MochaPalette.darkVoiceActive,
    successContainer: MochaPalette.darkSuccessContainer,
    warningContainer: MochaPalette.darkWarningContainer,
    info: MochaPalette.darkInfo,
    infoContainer: MochaPalette.darkInfoContainer,
  );

  /// Derives the SDK roles from a host [scheme] (used when the SDK inherits
  /// the host's `ThemeData` and the host supplies no [NexaColors]): bubbles
  /// follow the host's primary and surfaces; status colours keep the SDK's
  /// accessible defaults for that brightness.
  factory NexaColors.fromScheme(ColorScheme scheme) {
    final base = scheme.brightness == Brightness.dark ? dark : light;
    return base.copyWith(
      userBubble: scheme.primary,
      onUserBubble: scheme.onPrimary,
      assistantBubble: scheme.surfaceContainerHigh,
      onAssistantBubble: scheme.onSurface,
      voiceActive: scheme.primary,
    );
  }

  final Color userBubble;
  final Color onUserBubble;
  final Color assistantBubble;
  final Color onAssistantBubble;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color voiceActive;

  /// Tonal containers for status surfaces (banners, chips, voice capsule).
  final Color successContainer;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  /// Reads the extension, falling back to [light].
  static NexaColors of(BuildContext context) =>
      Theme.of(context).extension<NexaColors>() ?? light;

  @override
  NexaColors copyWith({
    Color? userBubble,
    Color? onUserBubble,
    Color? assistantBubble,
    Color? onAssistantBubble,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? voiceActive,
    Color? successContainer,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
  }) => NexaColors(
    userBubble: userBubble ?? this.userBubble,
    onUserBubble: onUserBubble ?? this.onUserBubble,
    assistantBubble: assistantBubble ?? this.assistantBubble,
    onAssistantBubble: onAssistantBubble ?? this.onAssistantBubble,
    success: success ?? this.success,
    onSuccess: onSuccess ?? this.onSuccess,
    warning: warning ?? this.warning,
    onWarning: onWarning ?? this.onWarning,
    voiceActive: voiceActive ?? this.voiceActive,
    successContainer: successContainer ?? this.successContainer,
    warningContainer: warningContainer ?? this.warningContainer,
    info: info ?? this.info,
    infoContainer: infoContainer ?? this.infoContainer,
  );

  @override
  NexaColors lerp(ThemeExtension<NexaColors>? other, double t) {
    if (other is! NexaColors) return this;
    return NexaColors(
      userBubble: Color.lerp(userBubble, other.userBubble, t)!,
      onUserBubble: Color.lerp(onUserBubble, other.onUserBubble, t)!,
      assistantBubble: Color.lerp(assistantBubble, other.assistantBubble, t)!,
      onAssistantBubble: Color.lerp(
        onAssistantBubble,
        other.onAssistantBubble,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      voiceActive: Color.lerp(voiceActive, other.voiceActive, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}
