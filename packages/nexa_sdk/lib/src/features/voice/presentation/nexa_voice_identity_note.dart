import 'package:flutter/material.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Which voice the call speaks with, as the gateway reported it at start
/// (`voice_identity`), or that the call is restarting for a new voice.
/// Shows nothing when the gateway reports nothing.
class NexaVoiceIdentityNote extends StatelessWidget {
  const NexaVoiceIdentityNote({required this.controller, super.key});

  final NexaVoiceController controller;

  /// The note for [s], or null.
  static String? textFor(NexaLocalizations l10n, NexaVoiceState s) {
    if (s.switchingVoice) return l10n.voiceSwitching;
    final id = s.voiceIdentity;
    if (id == null || !s.isActive) return null;
    return id.applied
        ? l10n.voiceIdentityApplied
        : l10n.voiceIdentityNotApplied;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    return ValueListenableBuilder<NexaVoiceState>(
      valueListenable: controller.state,
      builder: (context, s, _) {
        final text = textFor(l10n, s);
        if (text == null) return const SizedBox.shrink();
        return NexaStatusBanner(
          key: const Key('nexa_voice_identity_note'),
          tone: s.voiceIdentity?.applied ?? false
              ? NexaBannerTone.success
              : NexaBannerTone.info,
          message: text,
        );
      },
    );
  }
}
