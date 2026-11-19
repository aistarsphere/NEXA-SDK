import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_call_card.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_idle_timeout.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_output.dart';
import 'package:nexa_sdk/src/features/voice/presentation/nexa_voice_orb.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Why the compact panel closed the call.
enum NexaPanelCloseReason {
  /// The user tapped close.
  userClosed('user_closed'),

  /// No conversation for the idle timeout.
  idleTimeout('idle_timeout'),

  /// The call ended on its own (server, error, quota).
  callEnded('call_ended'),

  /// The user opened the full screen (the call continues there).
  expanded('expanded');

  const NexaPanelCloseReason(this.code);
  final String code;
}

/// Where the host shows the panel; changes its internal layout.
enum NexaPanelPlacement { bottom, top, left, right }

/// A compact live-voice surface for a partial-screen assistant window.
///
/// Drives the existing [NexaVoiceController] and tool calls of the client
/// (no separate voice pipeline): the call it starts is the same call the
/// full assistant shows. Ends the call itself on close and on the idle
/// timeout, then reports why through [onClosed]; on expand it leaves the
/// call running and calls [onExpand].
class NexaCompactVoicePanel extends StatefulWidget {
  const NexaCompactVoicePanel({
    required this.voice,
    required this.onClosed,
    this.tools,
    this.title,
    this.onExpand,
    this.placement = NexaPanelPlacement.bottom,
    this.idleTimeout = const Duration(seconds: 60),
    this.autoStart = true,
    this.voiceVerified = false,
    this.activationSource,
    super.key,
  });

  final NexaVoiceController voice;
  final LabeebToolCallController? tools;

  /// Host brand name shown in the header.
  final String? title;
  final void Function(NexaPanelCloseReason reason) onClosed;
  final VoidCallback? onExpand;
  final NexaPanelPlacement placement;

  /// Null turns the idle timeout off.
  final Duration? idleTimeout;
  final bool autoStart;

  /// The wake phrase was accepted in the owner's voice (shows a chip).
  final bool voiceVerified;

  /// How the panel was opened (`wake`, `system`, ...): `wake` starts with
  /// the orb's wake bloom.
  final String? activationSource;

  @override
  State<NexaCompactVoicePanel> createState() => _NexaCompactVoicePanelState();
}

class _NexaCompactVoicePanelState extends State<NexaCompactVoicePanel> {
  NexaVoiceIdleTimeout? _idle;
  final ValueNotifier<double> _level = ValueNotifier(0);
  bool _closing = false;
  bool _wasActive = false;
  bool _woke = false;

  /// The assistant presented choices or a card (`ui_presented`) that the
  /// compact panel cannot show: offer the full view.
  bool _hasUi = false;
  StreamSubscription<NexaVoiceToolEvent>? _uiEvents;
  Timer? _wakeTimer;

  NexaVoiceController get _voice => widget.voice;

  @override
  void initState() {
    super.initState();
    _voice.state.addListener(_onState);
    _voice.levels.addListener(_onLevels);
    _voice.callAudio?.state.addListener(_onAudio);
    widget.tools?.addListener(_onTools);
    _uiEvents = _voice.toolEvents.listen((e) {
      if (e.type == 'ui_presented' && mounted) setState(() => _hasUi = true);
    });
    _wasActive = _voice.state.value.isActive;
    if (widget.activationSource == 'wake') {
      // The phrase (and voice, when required) was just accepted on the
      // device: a short bloom marks it before the call state takes over.
      _woke = true;
      _wakeTimer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _woke = false);
      });
    }
    if (widget.autoStart && !_wasActive) unawaited(_voice.start());
    final timeout = widget.idleTimeout;
    if (timeout != null) {
      _idle = NexaVoiceIdleTimeout(
        voice: _voice,
        tools: widget.tools,
        timeout: timeout,
        onTimeout: () => _close(NexaPanelCloseReason.idleTimeout),
      )..start();
    }
  }

  @override
  void dispose() {
    _idle?.dispose();
    _wakeTimer?.cancel();
    unawaited(_uiEvents?.cancel());
    _voice.state.removeListener(_onState);
    _voice.levels.removeListener(_onLevels);
    _voice.callAudio?.state.removeListener(_onAudio);
    widget.tools?.removeListener(_onTools);
    _level.dispose();
    super.dispose();
  }

  void _onState() {
    final active = _voice.state.value.isActive;
    // The call ended by itself (server end, error): close once.
    if (_wasActive && !active && !_closing) {
      final phase = _voice.state.value.phase;
      if (phase == VoiceState.ended || phase.isTerminal) {
        _closing = true;
        widget.onClosed(NexaPanelCloseReason.callEnded);
      }
    }
    _wasActive = active;
    _onLevels();
    if (mounted) setState(() {});
  }

  void _onTools() {
    if (mounted) setState(() {});
  }

  void _onAudio() {
    if (mounted) setState(() {});
  }

  /// The level of whoever matters right now.
  void _onLevels() {
    final l = _voice.levels.value;
    _level.value = _voice.state.value.phase == VoiceState.aiSpeaking
        ? l.agent
        : l.local;
  }

  Future<void> _close(NexaPanelCloseReason reason) async {
    if (_closing) return;
    _closing = true;
    _idle?.dispose();
    await _voice.end();
    widget.onClosed(reason);
  }

  void _expand() {
    if (_closing || widget.onExpand == null) return;
    _closing = true;
    _idle?.dispose();
    widget.onExpand!();
  }

  LabeebToolActivity? get _activeTool => widget.tools?.activities
      .where(
        (a) => switch (a.call.status) {
          NexaToolCallStatus.awaitingApproval ||
          NexaToolCallStatus.awaitingClient ||
          NexaToolCallStatus.running => true,
          _ => false,
        },
      )
      .lastOrNull;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = _voice.state.value;
    final tool = _activeTool;
    // A tool waits for the user: approve here, or continue in the full
    // app when it needs a screen (camera, pickers, permission prompts).
    final approval = widget.tools?.activities
        .where(
          (a) =>
              a.phase == LabeebLocalPhase.awaitingUser &&
              a.call.status == NexaToolCallStatus.awaitingApproval,
        )
        .lastOrNull;
    final needsApp = approval == null
        ? widget.tools?.activities
              .where(
                (a) =>
                    a.phase == LabeebLocalPhase.awaitingUser &&
                    a.call.status == NexaToolCallStatus.awaitingClient,
              )
              .lastOrNull
        : null;
    final error = state.error;
    // The call could not start or was lost: say why and offer Retry
    // instead of an endless "connecting".
    final failed =
        !state.isActive && error != null && state.phase != VoiceState.ended;
    final mode = _woke && !failed
        ? NexaOrbMode.wake
        : nexaOrbModeFor(state.phase, toolActive: tool != null, failed: failed);
    final waiting = approval ?? needsApp;
    final status = failed
        ? NexaVoiceCapsule.voiceErrorText(l10n, error)
        : waiting != null
        ? '${labeebToolTitle(l10n, waiting.call.tool)}: '
              '${approval != null ? l10n.panelNeedsApproval : l10n.panelOpenToContinue}'
        : tool != null
        ? '${l10n.panelWorking} ${labeebToolTitle(l10n, tool.call.tool)}'
        : state.phoneCallHold && state.isActive
        ? l10n.voicePhoneCallHold
        : NexaVoiceCapsule.voiceStateLabel(
            l10n,
            state.phase,
            interruptConfirmed: state.interruptConfirmed,
          );
    final output = state.isActive ? nexaVoiceOutputOf(_voice.callAudio) : null;
    final caption = state.transcript.isEmpty ? null : state.transcript.last;
    final vertical =
        widget.placement == NexaPanelPlacement.left ||
        widget.placement == NexaPanelPlacement.right;
    final orbSize = vertical ? 120.0 : 76.0;

    // After a failed or dropped call, the orb starts it again.
    final canRetry =
        !state.isActive && state.phase != VoiceState.ended && !_closing;
    final orb = Semantics(
      button: canRetry,
      label: canRetry ? l10n.voiceRetry : null,
      child: GestureDetector(
        onTap: canRetry ? () => unawaited(_voice.start()) : null,
        child: NexaVoiceOrb(
          key: const Key('nexa_panel_orb'),
          mode: mode,
          level: _level,
          size: orbSize,
          semanticLabel: status,
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: vertical
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: vertical ? MainAxisSize.min : MainAxisSize.max,
          children: [
            if (widget.title != null)
              Flexible(
                child: Text(
                  widget.title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (widget.voiceVerified) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.verified_user_rounded,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 2),
              Flexible(
                child: Text(
                  l10n.panelVoiceVerified,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Flexible(
          child: Semantics(
            liveRegion: true,
            child: Text(
              status,
              key: const Key('nexa_panel_status'),
              maxLines: failed ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (failed) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            key: const Key('nexa_panel_retry'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => unawaited(_voice.start()),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.voiceRetry),
          ),
        ] else if (approval != null) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(
                key: const Key('nexa_panel_allow'),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => unawaited(
                  widget.tools!.decide(approval.call.id, allow: true),
                ),
                child: Text(l10n.tcAllow),
              ),
              TextButton(
                key: const Key('nexa_panel_deny'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => unawaited(
                  widget.tools!.decide(approval.call.id, allow: false),
                ),
                child: Text(l10n.tcNotNow),
              ),
            ],
          ),
        ] else if (_hasUi && widget.onExpand != null) ...[
          const SizedBox(height: 4),
          FilledButton.tonalIcon(
            key: const Key('nexa_panel_show_options'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: _expand,
            icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
            label: Text(l10n.panelShowOptions),
          ),
        ] else if (needsApp != null && widget.onExpand != null) ...[
          const SizedBox(height: 4),
          FilledButton.tonalIcon(
            key: const Key('nexa_panel_open_to_continue'),
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: _expand,
            icon: const Icon(Icons.open_in_full_rounded, size: 18),
            label: Text(l10n.panelOpenToContinue),
          ),
        ] else if (caption != null) ...[
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              caption.text,
              key: const Key('nexa_panel_caption'),
              maxLines: vertical ? 6 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: vertical ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: caption.speaker == VoiceSpeaker.user
                    ? scheme.onSurfaceVariant
                    : scheme.onSurface,
              ),
            ),
          ),
        ],
      ],
    );
    final controls = [
      _PanelButton(
        key: const Key('nexa_panel_mute'),
        icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
        label: state.muted ? l10n.voiceUnmute : l10n.voiceMute,
        selected: state.muted,
        onPressed: state.isActive ? _voice.toggleMute : null,
      ),
      if (output != null)
        _PanelButton(
          key: const Key('nexa_panel_output'),
          icon: nexaVoiceOutputIcon(output),
          label: nexaVoiceOutputTooltip(l10n, output),
          selected: output == NexaVoiceOutput.speaker,
          onPressed: () => nexaToggleVoiceOutput(_voice.callAudio!),
        ),
      if (widget.onExpand != null)
        _PanelButton(
          key: const Key('nexa_panel_expand'),
          icon: Icons.open_in_full_rounded,
          label: l10n.panelExpand,
          onPressed: _closing ? null : _expand,
        ),
      _PanelButton(
        key: const Key('nexa_panel_close'),
        icon: Icons.close_rounded,
        label: l10n.panelClose,
        onPressed: () => _close(NexaPanelCloseReason.userClosed),
      ),
    ];

    return Material(
      key: const Key('nexa_compact_panel'),
      color: scheme.surfaceContainerHigh,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 6,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: vertical
            ? Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: controls.reversed.take(1).toList(),
                  ),
                  const Spacer(),
                  orb,
                  const SizedBox(height: 16),
                  text,
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: controls.take(controls.length - 1).toList(),
                  ),
                ],
              )
            : Row(
                children: [
                  orb,
                  const SizedBox(width: 12),
                  Expanded(child: text),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      controls.last,
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: controls.take(controls.length - 1).toList(),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _PanelButton extends StatelessWidget {
  const _PanelButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.selected = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    // Fixed size whatever the host's button theme says.
    dimension: 48,
    child: IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      icon: Icon(icon),
    ),
  );
}
