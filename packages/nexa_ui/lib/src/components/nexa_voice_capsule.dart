import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/components/nexa_status_banner.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_motion.dart';
import 'package:nexa_ui/src/theme/nexa_shapes.dart';

/// Live Voice Capsule: the approved Mocha voice surface. Pure presentation:
/// it renders a [VoiceState] plus transcript and raises callbacks. State
/// changes come from the voice controller (real connection and agent
/// events), never from timers inside this widget.
class NexaVoiceCapsule extends StatelessWidget {
  const NexaVoiceCapsule({
    required this.state,
    required this.transcript,
    required this.muted,
    this.agentPresent = false,
    this.eventsVerified = true,
    this.error,
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
  final bool showTranscript;

  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final label = voiceStateLabel(l10n, state);
    final active =
        state != VoiceState.idle &&
        state != VoiceState.ended &&
        state != VoiceState.microphoneDenied &&
        state != VoiceState.quotaExceeded &&
        state != VoiceState.disconnected;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        children: [
          if (!eventsVerified && active)
            NexaStatusBanner(
              key: const Key('nexa_voice_unverified_banner'),
              tone: NexaBannerTone.warning,
              message: l10n.voiceUnverifiedEvents,
            ),
          if (error != null)
            NexaStatusBanner(
              key: const Key('nexa_voice_error_banner'),
              tone: NexaBannerTone.error,
              message: switch (error!) {
                NetworkException() => l10n.offline,
                QuotaExceededException() => l10n.voiceStateQuotaExceeded,
                PermissionDeniedException() => l10n.voiceStateMicrophoneDenied,
                AuthenticationException() => l10n.authError,
                SessionExpiredException() => l10n.sessionExpired,
                CapabilityNotGrantedException() => l10n.sessionError,
                // 503 voice_unavailable at creation, or the agent was lost
                // mid-call (contract v1 §7): "try again".
                ServerException(
                  serverCode: 'voice_unavailable' || 'agent_lost',
                ) =>
                  l10n.voiceUnavailable,
                _ => l10n.sessionError,
              },
              actionLabel: state == VoiceState.microphoneDenied
                  ? (onOpenSettings == null ? null : l10n.voiceOpenSettings)
                  : (onRetry == null ? null : l10n.voiceRetry),
              onAction: state == VoiceState.microphoneDenied
                  ? onOpenSettings
                  : onRetry,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Column(
                children: [
                  _VoiceOrb(state: state, muted: muted, label: label),
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      label,
                      key: const Key('nexa_voice_state_label'),
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (active && !agentPresent) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n.voiceAgentWaiting,
                      key: const Key('nexa_voice_agent_waiting'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (showTranscript)
                    Expanded(child: _Transcript(entries: transcript)),
                ],
              ),
            ),
          ),
          _Controls(
            state: state,
            muted: muted,
            // The error banner already offers "Try again"; avoid two.
            retryLabel: error == null,
            onStart: onStart,
            onEnd: onEnd,
            onToggleMute: onToggleMute,
          ),
        ],
      ),
    );
  }

  /// Localised label for a voice state (also used by hosts and tests).
  static String voiceStateLabel(NexaLocalizations l10n, VoiceState state) =>
      switch (state) {
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
}

/// The animated orb: colour and ring encode the state; pulses only while
/// someone is speaking; static under reduced motion.
class _VoiceOrb extends StatefulWidget {
  const _VoiceOrb({
    required this.state,
    required this.muted,
    required this.label,
  });
  final VoiceState state;
  final bool muted;
  final String label;

  @override
  State<_VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<_VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  bool get _shouldPulse =>
      widget.state == VoiceState.userSpeaking ||
      widget.state == VoiceState.aiSpeaking ||
      widget.state == VoiceState.bargeIn ||
      widget.state == VoiceState.connecting ||
      widget.state == VoiceState.reconnecting ||
      widget.state == VoiceState.thinking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _VoiceOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (NexaMotion.reduced(context) || !_shouldPulse) {
      _pulse
        ..stop()
        ..value = 0;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    final l10n = NexaLocalizations.of(context);
    final (fill, ring, icon) = switch (widget.state) {
      VoiceState.aiSpeaking => (
        scheme.primary,
        scheme.primaryContainer,
        Icons.graphic_eq_rounded,
      ),
      VoiceState.userSpeaking || VoiceState.bargeIn => (
        scheme.tertiary,
        scheme.tertiaryContainer,
        Icons.mic_rounded,
      ),
      VoiceState.listening => (
        scheme.primaryContainer,
        scheme.surfaceContainerHighest,
        Icons.mic_none_rounded,
      ),
      VoiceState.muted => (
        scheme.surfaceContainerHighest,
        scheme.outlineVariant,
        Icons.mic_off_rounded,
      ),
      VoiceState.thinking ||
      VoiceState.transcribing ||
      VoiceState.modelBusy => (
        scheme.secondaryContainer,
        scheme.surfaceContainerHighest,
        Icons.more_horiz_rounded,
      ),
      VoiceState.weakNetwork ||
      VoiceState.reconnecting ||
      VoiceState.connecting => (
        colors.warning,
        scheme.surfaceContainerHighest,
        Icons.wifi_tethering_rounded,
      ),
      VoiceState.disconnected ||
      VoiceState.microphoneDenied ||
      VoiceState.quotaExceeded => (
        scheme.errorContainer,
        scheme.surfaceContainerHighest,
        Icons.error_outline_rounded,
      ),
      VoiceState.idle || VoiceState.ended => (
        scheme.surfaceContainerHigh,
        scheme.outlineVariant,
        Icons.mic_none_rounded,
      ),
    };
    final onFill = ThemeData.estimateBrightnessForColor(fill) == Brightness.dark
        ? Colors.white
        : scheme.onSurface;
    return Semantics(
      label: l10n.semanticsVoiceOrb(widget.label),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final scale = 1 + 0.08 * _pulse.value;
            return SizedBox(
              width: 160,
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scale: scale,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ring.withValues(alpha: 0.55),
                      ),
                      child: const SizedBox(width: 160, height: 160),
                    ),
                  ),
                  AnimatedContainer(
                    key: const Key('nexa_voice_orb'),
                    duration: NexaMotion.of(context, NexaMotion.medium),
                    curve: NexaMotion.emphasized,
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fill,
                      borderRadius: null,
                    ),
                    child: Icon(
                      widget.muted && widget.state != VoiceState.muted
                          ? Icons.mic_off_rounded
                          : icon,
                      size: 44,
                      color: onFill,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.entries});
  final List<VoiceTranscriptEntry> entries;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final colors = NexaColors.of(context);
    final theme = Theme.of(context);
    if (entries.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      key: const Key('nexa_voice_transcript'),
      reverse: true,
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[entries.length - 1 - i];
        final isUser = e.speaker == VoiceSpeaker.user;
        return Align(
          alignment: isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.8,
            ),
            decoration: BoxDecoration(
              color: isUser ? colors.userBubble : colors.assistantBubble,
              borderRadius: isUser
                  ? NexaShapes.userBubble
                  : NexaShapes.assistantBubble,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUser
                      ? l10n.voiceTranscriptYou
                      : l10n.voiceTranscriptAssistant,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isUser
                        ? colors.onUserBubble
                        : colors.onAssistantBubble,
                  ),
                ),
                Text(
                  e.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isUser
                        ? colors.onUserBubble
                        : colors.onAssistantBubble,
                    fontStyle: e.isFinal ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.muted,
    required this.retryLabel,
    this.onStart,
    this.onEnd,
    this.onToggleMute,
  });
  final VoiceState state;
  final bool muted;
  final bool retryLabel;
  final VoidCallback? onStart;
  final VoidCallback? onEnd;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final inCall =
        state != VoiceState.idle &&
        state != VoiceState.ended &&
        state != VoiceState.microphoneDenied &&
        state != VoiceState.quotaExceeded &&
        state != VoiceState.disconnected;
    final canMute =
        inCall &&
        state != VoiceState.connecting &&
        state != VoiceState.reconnecting;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: inCall
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    key: const Key('nexa_voice_mute'),
                    tooltip: muted
                        ? l10n.semanticsUnmuteButton
                        : l10n.semanticsMuteButton,
                    onPressed: canMute ? onToggleMute : null,
                    iconSize: 28,
                    icon: Icon(
                      muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filled(
                    key: const Key('nexa_voice_end'),
                    tooltip: l10n.semanticsEndCallButton,
                    onPressed: onEnd,
                    iconSize: 28,
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    ),
                    icon: const Icon(Icons.call_end_rounded),
                  ),
                ],
              )
            : FilledButton.icon(
                key: const Key('nexa_voice_start'),
                onPressed: onStart,
                icon: const Icon(Icons.mic_rounded),
                label: Text(
                  retryLabel &&
                          (state == VoiceState.disconnected ||
                              state == VoiceState.ended)
                      ? l10n.voiceRetry
                      : l10n.voiceStart,
                ),
              ),
      ),
    );
  }
}
