import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_state.dart';
import 'package:nexa_sdk/src/nexa_ui_settings.dart' as sdk;
import 'package:nexa_ui/nexa_ui.dart';

/// Embeddable Live Voice Capsule bound to the SDK's voice controller. Like
/// `NexaChatView` it installs its own theme, localisations and direction.
///
/// Obtain through `NexaClient.voiceView()`.
class NexaVoiceView extends StatelessWidget {
  const NexaVoiceView({
    required this.controller,
    required this.settings,
    this.showTranscript = true,
    this.autoStart = false,
    this.onEnded,
    this.onOpenSettings,
    super.key,
  });

  final NexaVoiceController controller;
  final ValueListenable<sdk.NexaUiSettings> settings;
  final bool showTranscript;

  /// Start the call as soon as the view is shown.
  final bool autoStart;

  /// Called when the call reaches `ended`.
  final VoidCallback? onEnded;

  /// Host hook to open OS settings when the microphone was denied.
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<sdk.NexaUiSettings>(
      valueListenable: settings,
      builder: (context, ui, _) {
        final locale = NexaLocale.fromTag(ui.languageTag);
        controller.languageTag = locale.languageCode;
        final brightness = switch (ui.themeMode) {
          sdk.NexaThemeMode.light => Brightness.light,
          sdk.NexaThemeMode.dark => Brightness.dark,
          sdk.NexaThemeMode.system => MediaQuery.platformBrightnessOf(context),
        };
        return Localizations(
          locale: locale,
          delegates: NexaLocale.delegates,
          child: Directionality(
            textDirection: NexaLocale.directionOf(locale),
            child: Theme(
              data: NexaTheme.forBrightness(
                brightness,
                locale,
                overrides: ui.themeOverrides,
              ),
              child: _VoiceBody(
                controller: controller,
                showTranscript: showTranscript,
                autoStart: autoStart,
                onEnded: onEnded,
                onOpenSettings: onOpenSettings,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VoiceBody extends StatefulWidget {
  const _VoiceBody({
    required this.controller,
    required this.showTranscript,
    required this.autoStart,
    this.onEnded,
    this.onOpenSettings,
  });
  final NexaVoiceController controller;
  final bool showTranscript;
  final bool autoStart;
  final VoidCallback? onEnded;
  final VoidCallback? onOpenSettings;

  @override
  State<_VoiceBody> createState() => _VoiceBodyState();
}

class _VoiceBodyState extends State<_VoiceBody> {
  VoiceState? _lastPhase;

  @override
  void initState() {
    super.initState();
    widget.controller.state.addListener(_onState);
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.controller.start(),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.state.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    final phase = widget.controller.state.value.phase;
    if (phase == VoiceState.ended && _lastPhase != VoiceState.ended) {
      widget.onEnded?.call();
    }
    _lastPhase = phase;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<NexaVoiceState>(
      valueListenable: widget.controller.state,
      builder: (context, s, _) => NexaVoiceCapsule(
        state: s.phase,
        transcript: s.transcript,
        muted: s.muted,
        agentPresent: s.agentPresent,
        eventsVerified: s.eventsVerified,
        error: s.error,
        showTranscript: widget.showTranscript,
        onStart: widget.controller.start,
        onEnd: widget.controller.end,
        onToggleMute: widget.controller.toggleMute,
        onRetry: widget.controller.start,
        onOpenSettings: widget.onOpenSettings,
      ),
    );
  }
}
