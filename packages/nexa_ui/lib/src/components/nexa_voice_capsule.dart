import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/components/nexa_rich_text.dart';
import 'package:nexa_ui/src/components/nexa_status_banner.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';

/// Live Voice Capsule: the approved Mocha voice surface (design L1, "Live
/// conversation"). Captions of both sides fill the screen; a bottom panel
/// holds the voice capsule, whose width, colour and content change with the
/// state (mocha bars while the user speaks, slate-blue bars while the
/// assistant speaks, dots while thinking), the state label and hint, status
/// flags and the call controls.
///
/// Pure presentation: it renders a [VoiceState] plus transcript and raises
/// callbacks. State changes come from the voice controller (real connection
/// and agent events), never from timers inside this widget. Bars move only
/// in speaking states and stay still under reduced motion, where the text
/// label carries the state.
class NexaVoiceCapsule extends StatefulWidget {
  const NexaVoiceCapsule({
    required this.state,
    required this.transcript,
    required this.muted,
    this.agentPresent = false,
    this.eventsVerified = true,
    this.error,
    this.toolLabel,
    this.interruptConfirmed = false,
    this.showTranscript = true,
    this.onStart,
    this.onEnd,
    this.onToggleMute,
    this.onRetry,
    this.onOpenSettings,
    super.key,
  });

  final VoiceState state;
  final List<VoiceTranscriptEntry> transcript;
  final bool muted;

  /// Whether the assistant participant is in the room.
  final bool agentPresent;

  /// False when agent events are accepted unsigned (development mode).
  final bool eventsVerified;

  final NexaException? error;

  /// A call-scoped tool is running (e.g. "Working on it… Web search"). It
  /// replaces the state label unless the user or the assistant is speaking.
  final String? toolLabel;

  /// The agent confirmed that the user interrupted the assistant.
  final bool interruptConfirmed;

  /// Initial captions visibility; the user can toggle it in the panel.
  final bool showTranscript;

  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  /// Localised label for a voice state (also used by hosts and tests).
  static String voiceStateLabel(
    NexaLocalizations l10n,
    VoiceState state, {
    bool interruptConfirmed = false,
  }) => switch (state) {
    VoiceState.userSpeaking when interruptConfirmed =>
      l10n.voiceStateInterrupted,
    VoiceState.idle => l10n.voiceStateIdle,
    VoiceState.connecting => l10n.voiceStateConnecting,
    VoiceState.listening => l10n.voiceStateListening,
    VoiceState.userSpeaking => l10n.voiceStateUserSpeaking,
    VoiceState.transcribing => l10n.voiceStateTranscribing,
    VoiceState.thinking => l10n.voiceStateThinking,
    VoiceState.aiSpeaking => l10n.voiceStateAiSpeaking,
    VoiceState.bargeIn => l10n.voiceStateBargeIn,
    VoiceState.muted => l10n.voiceStateMuted,
    VoiceState.weakNetwork => l10n.voiceStateWeakNetwork,
    VoiceState.disconnected => l10n.voiceStateDisconnected,
    VoiceState.reconnecting => l10n.voiceStateReconnecting,
    VoiceState.modelBusy => l10n.voiceStateModelBusy,
    VoiceState.microphoneDenied => l10n.voiceStateMicrophoneDenied,
    VoiceState.quotaExceeded => l10n.voiceStateQuotaExceeded,
    VoiceState.ended => l10n.voiceStateEnded,
  };

  /// Plain-language text for a voice error (also used by compact panels).
  static String voiceErrorText(NexaLocalizations l10n, NexaException error) =>
      switch (error) {
        NetworkException() => l10n.offline,
        QuotaExceededException() => l10n.voiceStateQuotaExceeded,
        RateLimitedException() => l10n.rateLimited,
        PermissionDeniedException() => l10n.voiceStateMicrophoneDenied,
        AuthenticationException() => l10n.authError,
        SessionExpiredException() => l10n.sessionExpired,
        CapabilityNotGrantedException() => l10n.sessionError,
        // 503 at creation (no voice capacity / voice_unavailable), or the
        // agent was lost mid-call (contract v1 §7): "try again".
        ServerException(serverCode: 'voice_unavailable' || 'agent_lost') ||
        ServerException(statusCode: 503) => l10n.voiceUnavailable,
        _ => l10n.sessionError,
      };

  /// Localised one-line hint under the state label.
  static String voiceStateHint(NexaLocalizations l10n, VoiceState state) =>
      switch (state) {
        VoiceState.idle => l10n.voiceHintIdle,
        VoiceState.connecting => l10n.voiceHintConnecting,
        VoiceState.listening => l10n.voiceHintListening,
        VoiceState.userSpeaking => l10n.voiceHintUserSpeaking,
        VoiceState.transcribing => l10n.voiceHintTranscribing,
        VoiceState.thinking => l10n.voiceHintThinking,
        VoiceState.aiSpeaking => l10n.voiceHintAiSpeaking,
        VoiceState.bargeIn => l10n.voiceHintBargeIn,
        VoiceState.muted => l10n.voiceHintMuted,
        VoiceState.weakNetwork => l10n.voiceHintWeakNetwork,
        VoiceState.disconnected => l10n.voiceHintDisconnected,
        VoiceState.reconnecting => l10n.voiceHintReconnecting,
        VoiceState.modelBusy => l10n.voiceHintModelBusy,
        VoiceState.microphoneDenied => l10n.voiceHintMicrophoneDenied,
        VoiceState.quotaExceeded => l10n.voiceHintQuotaExceeded,
        VoiceState.ended => l10n.voiceHintEnded,
      };

  @override
  State<NexaVoiceCapsule> createState() => _NexaVoiceCapsuleState();
}

class _NexaVoiceCapsuleState extends State<NexaVoiceCapsule> {
  late bool _captions = widget.showTranscript;

  bool get _inCall => switch (widget.state) {
    VoiceState.idle ||
    VoiceState.ended ||
    VoiceState.microphoneDenied ||
    VoiceState.quotaExceeded ||
    VoiceState.disconnected => false,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = widget.state;
    final error = widget.error;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          // The controls keep their natural height at the bottom. The area
          // above them is shared: banners take their own height (at most
          // half of it, scrolling inside; they can be tall at large text) and
          // the captions get the rest. A Flexible banner area would take half
          // of the free space even when empty and lift the controls.
          Expanded(
            child: LayoutBuilder(
              builder: (context, area) => Column(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: area.maxHeight * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (!widget.eventsVerified && _inCall)
                            NexaStatusBanner(
                              key: const Key('nexa_voice_unverified_banner'),
                              tone: NexaBannerTone.warning,
                              message: l10n.voiceUnverifiedEvents,
                            ),
                          if (error != null)
                            NexaStatusBanner(
                              key: const Key('nexa_voice_error_banner'),
                              tone: NexaBannerTone.error,
                              message: NexaVoiceCapsule.voiceErrorText(
                                l10n,
                                error,
                              ),
                              actionLabel: state == VoiceState.microphoneDenied
                                  ? (widget.onOpenSettings == null
                                        ? null
                                        : l10n.voiceOpenSettings)
                                  : (widget.onRetry == null
                                        ? null
                                        : l10n.voiceRetry),
                              onAction: state == VoiceState.microphoneDenied
                                  ? widget.onOpenSettings
                                  : widget.onRetry,
                            )
                          else if (state == VoiceState.weakNetwork ||
                              state == VoiceState.reconnecting)
                            // One notice for connection trouble, weak or lost.
                            NexaStatusBanner(
                              key: const Key('nexa_voice_connection_banner'),
                              tone: NexaBannerTone.warning,
                              message: state == VoiceState.weakNetwork
                                  ? l10n.voiceHintWeakNetwork
                                  : l10n.voiceHintReconnecting,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: _captions
                        ? _Captions(entries: widget.transcript)
                        : Center(
                            child: Text(
                              l10n.voiceCaptionsHidden,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          _Panel(
            state: state,
            muted: widget.muted,
            inCall: _inCall,
            agentPresent: widget.agentPresent,
            toolLabel: widget.toolLabel,
            interruptConfirmed: widget.interruptConfirmed,
            captions: _captions,
            // The error banner already offers "Try again"; avoid two.
            retryLabel: error == null,
            onStart: widget.onStart,
            onEnd: widget.onEnd,
            onToggleMute: widget.onToggleMute,
            onToggleCaptions: () => setState(() => _captions = !_captions),
          ),
        ],
      ),
    );
  }
}

class _Captions extends StatelessWidget {
  const _Captions({required this.entries});
  final List<VoiceTranscriptEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            l10n.voiceCaptionsEmpty,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('nexa_voice_transcript'),
      reverse: true,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        final e = entries[entries.length - 1 - i];
        return _Turn(entry: e, key: ValueKey('turn_${e.at}_${e.speaker}'));
      },
    );
  }
}

class _Turn extends StatelessWidget {
  const _Turn({required this.entry, super.key});
  final VoiceTranscriptEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUser = entry.speaker == VoiceSpeaker.user;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isUser
                ? scheme.surfaceContainerHigh
                : scheme.primaryContainer,
            borderRadius: BorderRadius.circular(isUser ? 14 : 9),
          ),
          child: Icon(
            isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
            size: 16,
            color: isUser ? scheme.onSurfaceVariant : scheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    isUser
                        ? l10n.voiceTranscriptYou
                        : l10n.voiceTranscriptAssistant,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (!entry.isFinal) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        l10n.voicePartial,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.text,
                textDirection: nexaTextDirectionOf(entry.text),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: entry.isFinal
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                  fontStyle: entry.isFinal
                      ? FontStyle.normal
                      : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.state,
    required this.muted,
    required this.inCall,
    required this.agentPresent,
    required this.captions,
    required this.retryLabel,
    required this.onToggleCaptions,
    this.toolLabel,
    this.interruptConfirmed = false,
    this.onStart,
    this.onEnd,
    this.onToggleMute,
  });

  final bool interruptConfirmed;
  final String? toolLabel;
  final VoiceState state;
  final bool muted;
  final bool inCall;
  final bool agentPresent;
  final bool captions;
  final bool retryLabel;
  final VoidCallback onToggleCaptions;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = NexaColors.of(context);
    final showTool =
        toolLabel != null &&
        inCall &&
        state != VoiceState.aiSpeaking &&
        state != VoiceState.userSpeaking &&
        state != VoiceState.bargeIn;
    final label = showTool
        ? toolLabel!
        : NexaVoiceCapsule.voiceStateLabel(
            l10n,
            state,
            interruptConfirmed: interruptConfirmed,
          );
    final waiting = inCall && !agentPresent;
    final hint = NexaVoiceCapsule.voiceStateHint(l10n, state);
    final canMute =
        inCall &&
        state != VoiceState.connecting &&
        state != VoiceState.reconnecting;
    final weak = state == VoiceState.weakNetwork;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: l10n.semanticsVoiceOrb(label),
                child: ExcludeSemantics(
                  child: SizedBox(
                    height: 64,
                    child: Center(
                      child: _VoicePill(mode: _PillMode.of(state, muted)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Semantics(
                      liveRegion: true,
                      child: AnimatedSwitcher(
                        duration: NexaMotion.of(context, NexaMotion.medium),
                        switchInCurve: NexaMotion.emphasizedDecelerate,
                        transitionBuilder: (child, a) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.25),
                              end: Offset.zero,
                            ).animate(a),
                            child: child,
                          ),
                        ),
                        child: Text(
                          label,
                          key: const Key('nexa_voice_state_label'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _labelColor(state, scheme, colors),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      waiting ? l10n.voiceAgentWaiting : hint,
                      key: waiting
                          ? const Key('nexa_voice_agent_waiting')
                          : const Key('nexa_voice_state_hint'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 26,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (inCall && muted)
                      _Flag(
                        icon: Icons.mic_off_rounded,
                        text: l10n.voiceFlagMuted,
                        bg: scheme.errorContainer,
                        fg: scheme.onErrorContainer,
                      ),
                    if (inCall && muted && weak) const SizedBox(width: 6),
                    if (weak)
                      _Flag(
                        icon: Icons.network_check_rounded,
                        text: l10n.voiceFlagWeakNetwork,
                        bg: colors.warningContainer,
                        fg: colors.warning,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _Controls(
                inCall: inCall,
                canMute: canMute,
                muted: muted,
                captions: captions,
                startLabel:
                    retryLabel &&
                        (state == VoiceState.disconnected ||
                            state == VoiceState.ended)
                    ? l10n.voiceRetry
                    : l10n.voiceStart,
                onStart: onStart,
                onEnd: onEnd,
                onToggleMute: onToggleMute,
                onToggleCaptions: onToggleCaptions,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _labelColor(VoiceState s, ColorScheme scheme, NexaColors c) =>
      switch (s) {
        VoiceState.userSpeaking => scheme.primary,
        VoiceState.aiSpeaking => c.info,
        VoiceState.bargeIn ||
        VoiceState.reconnecting ||
        VoiceState.weakNetwork ||
        VoiceState.modelBusy => c.warning,
        VoiceState.microphoneDenied ||
        VoiceState.quotaExceeded ||
        VoiceState.disconnected => scheme.error,
        _ => scheme.onSurface,
      };
}

class _Flag extends StatelessWidget {
  const _Flag({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });
  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fg),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        ),
      ],
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.inCall,
    required this.canMute,
    required this.muted,
    required this.captions,
    required this.startLabel,
    required this.onToggleCaptions,
    this.onStart,
    this.onEnd,
    this.onToggleMute,
  });
  final bool inCall;
  final bool canMute;
  final bool muted;
  final bool captions;
  final String startLabel;
  final VoidCallback onToggleCaptions;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final duration = NexaMotion.of(context, NexaMotion.long);
    final round = IconButton.styleFrom(
      fixedSize: const Size(56, 56),
      backgroundColor: scheme.surfaceContainerHighest,
      foregroundColor: scheme.onSurface,
    );
    return Row(
      children: [
        if (inCall) ...[
          IconButton(
            key: const Key('nexa_voice_mute'),
            tooltip: muted
                ? l10n.semanticsUnmuteButton
                : l10n.semanticsMuteButton,
            isSelected: muted,
            onPressed: canMute ? onToggleMute : null,
            iconSize: 24,
            style: round.copyWith(
              backgroundColor: WidgetStatePropertyAll(
                muted ? scheme.errorContainer : scheme.surfaceContainerHighest,
              ),
              foregroundColor: WidgetStatePropertyAll(
                muted ? scheme.onErrorContainer : scheme.onSurface,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(muted ? 18 : 28),
                ),
              ),
            ),
            icon: Icon(muted ? Icons.mic_off_rounded : Icons.mic_rounded),
          ),
          const SizedBox(width: 12),
        ],
        IconButton(
          key: const Key('nexa_voice_captions'),
          tooltip: captions ? l10n.voiceHideCaptions : l10n.voiceShowCaptions,
          isSelected: captions,
          onPressed: onToggleCaptions,
          iconSize: 24,
          style: round.copyWith(
            backgroundColor: WidgetStatePropertyAll(
              captions
                  ? scheme.secondaryContainer
                  : scheme.surfaceContainerHighest,
            ),
            foregroundColor: WidgetStatePropertyAll(
              captions ? scheme.onSecondaryContainer : scheme.onSurface,
            ),
          ),
          icon: Icon(
            captions
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_off_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) => Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AnimatedContainer(
                duration: duration,
                curve: Curves.easeOutBack,
                height: 64,
                width: inCall ? math.min(172, box.maxWidth) : box.maxWidth,
                child: inCall
                    ? Tooltip(
                        message: l10n.semanticsEndCallButton,
                        child: FilledButton(
                          key: const Key('nexa_voice_end'),
                          onPressed: onEnd,
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.call_end_rounded, size: 26),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  l10n.voiceEnd,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : FilledButton.icon(
                        key: const Key('nexa_voice_start'),
                        onPressed: onStart,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                          ),
                          textStyle: Theme.of(context).textTheme.titleSmall,
                        ),
                        icon: const Icon(Icons.mic_rounded, size: 26),
                        label: Text(startLabel),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _PillKind { rest, bars, frozen, dots, icon }

/// Visual spec of the capsule per state (design `CAPS` table).
final class _PillMode {
  const _PillMode(
    this.width,
    this.kind, {
    required this.bg,
    required this.fg,
    this.radius = 32,
    this.icon,
    this.ring,
    this.sweep = false,
  });

  final double width;
  final _PillKind kind;
  final Color Function(ColorScheme, NexaColors) bg;
  final Color Function(ColorScheme, NexaColors) fg;
  final double radius;
  final IconData? icon;
  final Color Function(ColorScheme, NexaColors)? ring;
  final bool sweep;

  static _PillMode of(VoiceState s, bool muted) {
    if (muted &&
        (s == VoiceState.listening ||
            s == VoiceState.userSpeaking ||
            s == VoiceState.muted)) {
      return _muted;
    }
    return switch (s) {
      VoiceState.idle => _PillMode(
        80,
        _PillKind.rest,
        bg: (c, _) => c.surfaceContainerHigh,
        fg: (c, _) => c.onSurfaceVariant,
      ),
      VoiceState.connecting => _PillMode(
        124,
        _PillKind.dots,
        bg: (c, _) => c.surfaceContainerHigh,
        fg: (c, _) => c.primary,
        sweep: true,
      ),
      VoiceState.listening => _PillMode(
        112,
        _PillKind.rest,
        bg: (c, _) => c.surfaceContainerLowest,
        fg: (c, _) => c.primary,
        ring: (c, _) => c.primary,
      ),
      VoiceState.weakNetwork => _PillMode(
        112,
        _PillKind.rest,
        bg: (c, _) => c.surfaceContainerLowest,
        fg: (_, n) => n.warning,
        ring: (_, n) => n.warning,
      ),
      VoiceState.userSpeaking => _PillMode(
        208,
        _PillKind.bars,
        bg: (c, _) => c.primary,
        fg: (c, _) => c.onPrimary,
      ),
      VoiceState.transcribing => _PillMode(
        152,
        _PillKind.frozen,
        bg: (c, _) => c.primaryContainer,
        fg: (c, _) => c.onPrimaryContainer,
        sweep: true,
      ),
      VoiceState.thinking => _PillMode(
        128,
        _PillKind.dots,
        bg: (c, _) => c.surfaceContainerHighest,
        fg: (c, _) => c.onSurfaceVariant,
      ),
      VoiceState.aiSpeaking => _PillMode(
        208,
        _PillKind.bars,
        bg: (_, n) => n.infoContainer,
        fg: (_, n) => n.info,
      ),
      VoiceState.bargeIn => _PillMode(
        164,
        _PillKind.icon,
        bg: (_, n) => n.warningContainer,
        fg: (_, n) => n.warning,
        radius: 22,
        icon: Icons.front_hand_rounded,
      ),
      VoiceState.muted => _muted,
      VoiceState.reconnecting => _PillMode(
        152,
        _PillKind.dots,
        bg: (_, n) => n.warningContainer,
        fg: (_, n) => n.warning,
        ring: (_, n) => n.warning,
      ),
      VoiceState.disconnected => _PillMode(
        80,
        _PillKind.icon,
        bg: (c, _) => c.errorContainer,
        fg: (c, _) => c.error,
        radius: 20,
        icon: Icons.wifi_off_rounded,
      ),
      VoiceState.modelBusy => _PillMode(
        128,
        _PillKind.icon,
        bg: (c, _) => c.secondaryContainer,
        fg: (c, _) => c.onSecondaryContainer,
        icon: Icons.hourglass_top_rounded,
      ),
      VoiceState.microphoneDenied => _PillMode(
        80,
        _PillKind.icon,
        bg: (c, _) => c.errorContainer,
        fg: (c, _) => c.error,
        radius: 20,
        icon: Icons.mic_off_rounded,
      ),
      VoiceState.quotaExceeded => _PillMode(
        80,
        _PillKind.icon,
        bg: (c, _) => c.errorContainer,
        fg: (c, _) => c.error,
        radius: 20,
        icon: Icons.hourglass_disabled_rounded,
      ),
      VoiceState.ended => _PillMode(
        64,
        _PillKind.icon,
        bg: (_, n) => n.successContainer,
        fg: (_, n) => n.success,
        icon: Icons.call_end_rounded,
      ),
    };
  }

  static final _muted = _PillMode(
    112,
    _PillKind.icon,
    bg: (c, _) => c.errorContainer,
    fg: (c, _) => c.error,
    icon: Icons.mic_off_rounded,
  );
}

class _VoicePill extends StatefulWidget {
  const _VoicePill({required this.mode});
  final _PillMode mode;

  @override
  State<_VoicePill> createState() => _VoicePillState();
}

class _VoicePillState extends State<_VoicePill> with TickerProviderStateMixin {
  // One shared clock drives bars, dots and the sweep.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  bool get _animates {
    final m = widget.mode;
    return m.kind == _PillKind.bars || m.kind == _PillKind.dots || m.sweep;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _VoicePill oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (NexaMotion.reduced(context) || !_animates) {
      _clock
        ..stop()
        ..value = 0;
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mode;
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    final bg = m.bg(scheme, colors);
    final fg = m.fg(scheme, colors);
    final ring = m.ring?.call(scheme, colors);
    final reduced = NexaMotion.reduced(context);
    final shadow = m.kind == _PillKind.bars
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ];
    return AnimatedContainer(
      key: const Key('nexa_voice_pill'),
      duration: reduced ? Duration.zero : const Duration(milliseconds: 550),
      curve: Curves.easeOutBack,
      width: m.width,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(m.radius),
        border: ring == null ? null : Border.all(color: ring, width: 2),
        boxShadow: shadow,
      ),
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (m.sweep && !reduced)
                Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(t * 2.4 % 2 - 1, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            fg.withValues(alpha: 0),
                            fg.withValues(alpha: 0.22),
                            fg.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              _content(m, fg, t),
            ],
          );
        },
      ),
    );
  }

  Widget _content(_PillMode m, Color fg, double t) {
    switch (m.kind) {
      case _PillKind.icon:
        return Icon(m.icon, color: fg, size: 28);
      case _PillKind.dots:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Transform.translate(
                offset: Offset(0, -3 * _dot(t * 2.18 - i * 0.16)),
                child: Opacity(
                  opacity: 0.35 + 0.65 * _dot(t * 2.18 - i * 0.16),
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: fg,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      case _PillKind.bars:
      case _PillKind.frozen:
      case _PillKind.rest:
        // 13 bars (100 dp) are laid out regardless of the pill width; the
        // pill clips them in its narrow states, as in the design.
        return OverflowBox(
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 13; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                // Live bars follow the clock frame by frame; resting and
                // frozen bars ease between their fixed heights.
                AnimatedContainer(
                  duration: m.kind == _PillKind.bars
                      ? Duration.zero
                      : NexaMotion.of(context, NexaMotion.medium),
                  curve: NexaMotion.emphasized,
                  width: 4,
                  height: 32 * _barScale(m.kind, i, t),
                  decoration: BoxDecoration(
                    color: fg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }

  /// 0→1→0 bump for the thinking dots.
  static double _dot(double x) {
    final f = x - x.floorToDouble();
    return f < 0.5 ? math.sin(f * 2 * math.pi).abs() : 0;
  }

  static double _barScale(_PillKind kind, int i, double t) {
    switch (kind) {
      case _PillKind.rest:
        return 0.14;
      case _PillKind.frozen:
        return 0.22 + 0.3 * math.sin(i * 1.3).abs();
      case _PillKind.bars:
        final period = 0.36 + ((i * 7) % 5) * 0.08; // seconds, per design
        final phase = (t * 2.4 / period) + i * 0.035 / period;
        final f = phase - phase.floorToDouble();
        final tri = f < 0.5 ? f * 2 : 2 - f * 2; // alternate
        return 0.2 + 0.8 * Curves.easeInOut.transform(tri);
      case _PillKind.dots:
      case _PillKind.icon:
        return 0;
    }
  }
}
