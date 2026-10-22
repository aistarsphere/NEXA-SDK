import 'package:flutter/material.dart';

/// Motion tokens (durations and curves) from the design contract, plus
/// reduced-motion support.
abstract final class NexaMotion {
  static const Duration short = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 500);
  static const Duration extraLong = Duration(milliseconds: 700);

  /// M3 emphasized curves.
  static const Curve emphasized = Cubic(0.2, 0, 0, 1);
  static const Curve emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const Curve emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
  static const Curve standard = Cubic(0.2, 0, 0, 1);

  /// True when the platform asks to reduce motion. Components must collapse
  /// their animations to [Duration.zero] when this is true.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Returns [duration], or zero under reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
