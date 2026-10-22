import 'package:flutter/material.dart';

/// Approved host customisation points.
///
/// Hosts may re-brand within these bounds; everything else (contrast pairs,
/// shapes, typography, motion) is owned by the SDK so readability and
/// component behaviour cannot be broken by an integration.
@immutable
final class NexaThemeOverrides {
  const NexaThemeOverrides({
    this.seedColor,
    this.userBubbleColor,
    this.cornerScale = 1.0,
    this.brightnessOverride,
  }) : assert(
         cornerScale >= 0.5 && cornerScale <= 1.25,
         'cornerScale must stay within 0.5..1.25 to preserve M3 Expressive shapes',
       );

  /// Brand seed. When set, the primary/secondary/tertiary roles are derived
  /// from it with M3 tonal palettes; surfaces keep the Mocha neutrals.
  final Color? seedColor;

  /// Overrides the outgoing bubble colour. `onUserBubble` is recomputed for
  /// contrast automatically.
  final Color? userBubbleColor;

  /// Multiplies corner radii (0.5..1.25).
  final double cornerScale;

  /// Forces light/dark regardless of the platform.
  final Brightness? brightnessOverride;

  /// No overrides.
  static const none = NexaThemeOverrides();
}
