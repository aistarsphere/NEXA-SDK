import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_call_card.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/presentation/nexa_voice_identity_note.dart';
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
    this.tools,
    super.key,
  });

  /// Call-scoped tools: a running one shows "Working on it…" in the capsule.
  final LabeebToolCallController? tools;

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
        return Localizations(
          locale: locale,
          delegates: NexaLocale.delegates,
          child: Directionality(
            textDirection: NexaLocale.directionOf(locale),
            child: Theme(
              data: ui.resolveTheme(context, locale),
              child: _VoiceBody(
                controller: controller,
                showTranscript: showTranscript,
                autoStart: autoStart,
                onEnded: onEnded,
                onOpenSettings: onOpenSettings,
                tools: tools,
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
    this.tools,
  });
  final LabeebToolCallController? tools;
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
    _announcementTimer?.cancel();
    super.dispose();
  }

  String? _announcement;
  Timer? _announcementTimer;

  /// "Reconnected" for assistive technology after a reconnect (a live
  /// region, shown for a few seconds).
  void _announceReconnected() {
    _announcementTimer?.cancel();
    setState(
      () => _announcement = NexaLocalizations.of(context).voiceReconnected,
    );
    _announcementTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _announcement = null);
    });
  }

  void _onState() {
    final phase = widget.controller.state.value.phase;
    if (_lastPhase == VoiceState.reconnecting &&
        phase != VoiceState.reconnecting &&
        widget.controller.state.value.isActive &&
        mounted) {
      _announceReconnected();
    }
    if (phase == VoiceState.ended && _lastPhase != VoiceState.ended) {
      widget.onEnded?.call();
    }
    _lastPhase = phase;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.controller.state, ?widget.tools]),
      builder: (context, _) {
        final s = widget.controller.state.value;
        return Column(
          children: [
            NexaLiveAnnouncer(message: _announcement),
            NexaVoiceIdentityNote(controller: widget.controller),
            Expanded(
              child: NexaVoiceCapsule(
                state: s.phase,
                transcript: s.transcript,
                muted: s.muted,
                agentPresent: s.agentPresent,
                eventsVerified: s.eventsVerified,
                error: s.error,
                interruptConfirmed: s.interruptConfirmed,
                toolLabel: labeebWorkingLabel(
                  NexaLocalizations.of(context),
                  widget.tools,
                ),
                showTranscript: widget.showTranscript,
                onStart: widget.controller.start,
                onEnd: widget.controller.end,
                onToggleMute: widget.controller.toggleMute,
                onRetry: widget.controller.start,
                onOpenSettings: widget.onOpenSettings,
              ),
            ),
          ],
        );
      },
    );
  }
}
