import 'package:flutter/material.dart';

/// Material 3 Expressive shape scale. Chat bubbles use asymmetric corners
/// (the "tail" corner is small) and are mirrored automatically under RTL via
/// [BorderRadiusDirectional].
abstract final class NexaShapes {
  static const double extraSmall = 4;
  static const double small = 8;
  static const double medium = 12;
  static const double large = 16;
  static const double extraLarge = 28;
  static const double full = 999;

  /// Cards and tool results.
  static const BorderRadius card = BorderRadius.all(
    Radius.circular(extraLarge),
  );

  /// Composer and chips.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(full));

  /// Outgoing (user) bubble. Tail at the bottom-end corner.
  static const BorderRadiusDirectional userBubble =
      BorderRadiusDirectional.only(
        topStart: Radius.circular(extraLarge),
        topEnd: Radius.circular(extraLarge),
        bottomStart: Radius.circular(extraLarge),
        bottomEnd: Radius.circular(small),
      );

  /// Incoming (assistant) bubble. Tail at the bottom-start corner.
  static const BorderRadiusDirectional assistantBubble =
      BorderRadiusDirectional.only(
        topStart: Radius.circular(extraLarge),
        topEnd: Radius.circular(extraLarge),
        bottomStart: Radius.circular(small),
        bottomEnd: Radius.circular(extraLarge),
      );
}
