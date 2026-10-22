import 'package:flutter/material.dart';

/// Invisible live region that announces state changes to assistive
/// technology (connection changes, "assistant finished", send failures).
///
/// Uses a semantics live region instead of `SemanticsService.announce` so
/// the behaviour is declarative, testable and consistent across platforms.
/// Pass a new [message] to announce; an unchanged message is not repeated.
class NexaLiveAnnouncer extends StatelessWidget {
  const NexaLiveAnnouncer({required this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      label: text,
      container: true,
      child: const SizedBox(width: 0, height: 0),
    );
  }
}
