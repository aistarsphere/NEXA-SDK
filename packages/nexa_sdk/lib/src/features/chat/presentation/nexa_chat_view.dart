import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';
import 'package:nexa_sdk/src/nexa_ui_settings.dart' as sdk;
import 'package:nexa_ui/nexa_ui.dart';

/// Embeddable chat body. Self-contained: installs the NEXA theme,
/// localisations and text direction so it renders correctly inside any host
/// widget tree, with or without the host's own localisation setup.
///
/// Obtain it via `NexaClient.chatView()`; do not construct directly.
class NexaChatView extends StatefulWidget {
  const NexaChatView({
    required this.createBloc,
    required this.settings,
    this.showEndAction = false,
    this.onEnded,
    super.key,
  });

  /// Factory for the screen's bloc (injected from the SDK container).
  final ChatBloc Function() createBloc;

  /// Live presentation settings.
  final ValueListenable<sdk.NexaUiSettings> settings;

  /// Whether an "end chat" affordance is rendered inside the view.
  final bool showEndAction;

  /// Called after the user ends the chat.
  final VoidCallback? onEnded;

  @override
  State<NexaChatView> createState() => _NexaChatViewState();
}

class _NexaChatViewState extends State<NexaChatView> {
  late final ChatBloc _bloc = widget.createBloc()..add(const ChatStarted());

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<sdk.NexaUiSettings>(
      valueListenable: widget.settings,
      builder: (context, settings, _) {
        final locale = NexaLocale.fromTag(settings.languageTag);
        _bloc.languageTag = locale.languageCode;
        final platformBrightness = MediaQuery.platformBrightnessOf(context);
        final brightness = switch (settings.themeMode) {
          sdk.NexaThemeMode.light => Brightness.light,
          sdk.NexaThemeMode.dark => Brightness.dark,
          sdk.NexaThemeMode.system => platformBrightness,
        };
        final theme = NexaTheme.forBrightness(
          brightness,
          locale,
          overrides: settings.themeOverrides,
        );
        return Localizations(
          locale: locale,
          delegates: NexaLocale.delegates,
          child: Directionality(
            textDirection: NexaLocale.directionOf(locale),
            child: Theme(
              data: theme,
              child: BlocProvider.value(
                value: _bloc,
                child: _ChatBody(
                  showEndAction: widget.showEndAction,
                  onEnded: widget.onEnded,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ChatBody extends StatefulWidget {
  const _ChatBody({required this.showEndAction, this.onEnded});
  final bool showEndAction;
  final VoidCallback? onEnded;

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  static const _nearBottomThreshold = 72.0;

  final _scroll = ScrollController();
  final Set<String> _promptedPermissions = {};

  /// Whether the viewport is pinned to the newest message.
  bool _atBottom = true;

  /// New content arrived while scrolled up.
  bool _unseen = false;

  /// Last accessibility announcement (only changes are announced).
  String? _announcement;
  ChatConnection? _announcedConnection;
  final Set<MessageId> _announcedCompleted = {};
  final Set<ClientMessageId> _announcedFailed = {};

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final distance = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    final atBottom = distance <= _nearBottomThreshold;
    if (atBottom != _atBottom || (atBottom && _unseen)) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _unseen = false;
      });
    }
  }

  void _scrollToEnd({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (!force && !_atBottom) {
        if (!_unseen) setState(() => _unseen = true);
        return;
      }
      final target = _scroll.position.maxScrollExtent;
      final duration = NexaMotion.of(context, NexaMotion.medium);
      if (duration == Duration.zero) {
        _scroll.jumpTo(target);
      } else {
        _scroll.animateTo(
          target,
          duration: duration,
          curve: NexaMotion.emphasizedDecelerate,
        );
      }
      if (_unseen) setState(() => _unseen = false);
    });
  }

  Future<void> _promptPermission(
    BuildContext context,
    PendingPermission p,
  ) async {
    if (!_promptedPermissions.add(p.requestId)) return;
    final bloc = context.read<ChatBloc>();
    final proceed = await showNexaPermissionRationale(
      context,
      permission: p.permission,
      reason: p.reason,
    );
    bloc.add(ChatPermissionAnswered(requestId: p.requestId, proceed: proceed));
  }

  /// Derives the next live-region announcement from a state transition.
  void _announce(ChatState prev, ChatState next, NexaLocalizations l10n) {
    String? text;
    if (next.connection != _announcedConnection) {
      _announcedConnection = next.connection;
      text = switch (next.connection) {
        ChatConnection.reconnecting => l10n.reconnecting,
        ChatConnection.connected =>
          prev.connection == ChatConnection.reconnecting
              ? l10n.connected
              : null,
        _ => null,
      };
    }
    for (final m in next.conversation.messages) {
      if (m.role == MessageRole.assistant &&
          m.status == MessageStatus.completed &&
          _announcedCompleted.add(m.id)) {
        text = l10n.semanticsAssistantFinished;
      }
      final cid = m.clientMessageId;
      if (cid != null &&
          m.status == MessageStatus.failed &&
          _announcedFailed.add(cid)) {
        text = l10n.semanticsMessageFailed;
      }
    }
    if (text != null && text != _announcement) {
      setState(() => _announcement = text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    return BlocConsumer<ChatBloc, ChatState>(
      listener: (context, state) {
        final prev = _lastState ?? state;
        _lastState = state;
        if (prev.conversation.messages != state.conversation.messages) {
          final last = state.conversation.messages.lastOrNull;
          final ownNew =
              last != null &&
              last.role == MessageRole.user &&
              last.status == MessageStatus.pending &&
              prev.conversation.messages.length <
                  state.conversation.messages.length;
          _scrollToEnd(force: ownNew);
        }
        for (final p in state.conversation.pendingPermissions) {
          _promptPermission(context, p);
        }
        _announce(prev, state, l10n);
      },
      builder: (context, state) {
        final bloc = context.read<ChatBloc>();
        final conv = state.conversation;
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            // Keyboard: when the host did not wrap us in a Scaffold the inset
            // is still here; a Scaffold body sees 0 (already consumed).
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              children: [
                NexaLiveAnnouncer(message: _announcement),
                _Banners(state: state, l10n: l10n),
                Expanded(
                  child: Stack(
                    alignment: AlignmentDirectional.bottomCenter,
                    children: [
                      if (conv.messages.isEmpty)
                        _EmptyState(connection: state.connection, l10n: l10n)
                      else
                        ListView.separated(
                          key: const Key('nexa_message_list'),
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: conv.messages.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => _MessageRow(
                            message: conv.messages[i],
                            state: state,
                            onRetry: (id) => bloc.add(ChatMessageRetried(id)),
                            onToolAction: (a) =>
                                bloc.add(ChatToolActionSubmitted(a)),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: NexaJumpToLatestButton(
                          visible: !_atBottom && _unseen,
                          onPressed: () => _scrollToEnd(force: true),
                        ),
                      ),
                    ],
                  ),
                ),
                if (conv.phase == ConversationPhase.ended)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      switch (conv.endReason) {
                        SessionEndReason.quotaExceeded =>
                          l10n.sessionEndedQuota,
                        SessionEndReason.expired => l10n.sessionExpired,
                        _ => l10n.sessionEnded,
                      },
                      key: const Key('nexa_session_ended'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else
                  NexaComposer(
                    enabled: state.canSend,
                    isGenerating: state.generating != null,
                    onSend: (text) => bloc.add(ChatMessageSent(text)),
                    onStop: () => bloc.add(const ChatGenerationCancelled()),
                  ),
                if (widget.showEndAction &&
                    conv.phase != ConversationPhase.ended)
                  TextButton(
                    key: const Key('nexa_end_session'),
                    onPressed: () {
                      bloc.add(const ChatEnded());
                      widget.onEnded?.call();
                    },
                    child: Text(l10n.endSession),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  ChatState? _lastState;
}

class _Banners extends StatelessWidget {
  const _Banners({required this.state, required this.l10n});
  final ChatState state;
  final NexaLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final error = state.error;
    final quota = state.conversation.quota;
    final ended = state.conversation.phase == ConversationPhase.ended;
    final canRetry = state.connection == ChatConnection.disconnected && !ended;
    return Column(
      children: [
        if (state.connection == ChatConnection.connecting)
          NexaStatusBanner(
            key: const Key('nexa_connecting_banner'),
            message: l10n.connecting,
          ),
        if (state.connection == ChatConnection.reconnecting)
          NexaStatusBanner(
            key: const Key('nexa_reconnecting_banner'),
            tone: NexaBannerTone.warning,
            message: l10n.reconnecting,
          ),
        if (error != null)
          NexaStatusBanner(
            key: const Key('nexa_error_banner'),
            tone: NexaBannerTone.error,
            message: switch (error) {
              NetworkException() => l10n.offline,
              QuotaExceededException() => l10n.sessionEndedQuota,
              AuthenticationException() => l10n.authError,
              SessionExpiredException() => l10n.sessionExpired,
              RateLimitedException() => l10n.rateLimited,
              _ => l10n.sessionError,
            },
            actionLabel: canRetry ? l10n.retry : null,
            onAction: canRetry
                ? () => context.read<ChatBloc>().add(const ChatStarted())
                : null,
          ),
        if (quota != null &&
            !state.conversation.quotaExceeded &&
            (quota.remaining ?? 99) <= 5)
          NexaStatusBanner(
            tone: NexaBannerTone.warning,
            message: l10n.quotaWarning(quota.remaining ?? 0),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.connection, required this.l10n});
  final ChatConnection connection;
  final NexaLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text(
            l10n.poweredBy,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.message,
    required this.state,
    required this.onRetry,
    required this.onToolAction,
  });

  final ChatMessage message;
  final ChatState state;
  final ValueChanged<ClientMessageId> onRetry;
  final NexaToolActionCallback onToolAction;

  @override
  Widget build(BuildContext context) {
    final tools = [
      for (final id in message.toolCallIds) ?state.conversation.toolCalls[id],
    ];
    final showBubble =
        message.role == MessageRole.user ||
        message.text.isNotEmpty ||
        (message.isInProgress && tools.isEmpty);
    final canRetry =
        message.clientMessageId != null &&
        message.retryable &&
        !state.hasPendingUserMessage;
    return Column(
      crossAxisAlignment: message.role == MessageRole.user
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (showBubble)
          NexaMessageBubble(
            message: message,
            onRetry: canRetry ? () => onRetry(message.clientMessageId!) : null,
          ),
        for (final t in tools) ...[
          const SizedBox(height: 8),
          if (t.result case final r?)
            NexaToolResultCard(
              toolCallId: t.request.id,
              result: r,
              resolved: state.resolvedToolCalls.contains(t.request.id),
              onAction: onToolAction,
            )
          else if (t.pendingConfirmation case final c?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: NexaConfirmationCard(
                  confirmation: c,
                  enabled: !state.resolvedToolCalls.contains(t.request.id),
                  onConfirm: () => onToolAction(
                    ToolAction.confirmed(
                      toolCallId: t.request.id,
                      confirmationId: c.id,
                    ),
                  ),
                  onDecline: () => onToolAction(
                    ToolAction.declined(
                      toolCallId: t.request.id,
                      confirmationId: c.id,
                    ),
                  ),
                ),
              ),
            )
          else
            NexaToolCallTile(toolCall: t),
        ],
      ],
    );
  }
}
