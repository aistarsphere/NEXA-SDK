import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart' show PluginUrlOpener;
import 'package:nexa_sdk/src/data/network/error_mapper.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_controller.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_presentation.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_ui_view.dart';
import 'package:nexa_sdk/src/features/history/nexa_history.dart';
import 'package:nexa_sdk/src/features/media/nexa_conversation_media.dart';
import 'package:nexa_sdk/src/features/media/nexa_device_actions.dart';
import 'package:nexa_sdk/src/features/media/nexa_media_widgets.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_device_tools.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_call_card.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
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
    this.suggestions,
    this.onVoice,
    this.media,
    this.deviceActions,
    this.history,
    this.surfaces,
    this.toolCalls,
    super.key,
  });

  /// Host-local Dynamic UI surfaces (e.g. the theme picker).
  final NexaSurfaceController? surfaces;

  /// labeeb.sdk/1 tool calls, jobs, assets and `nexa.ui/1` documents.
  final LabeebToolCallController? toolCalls;

  /// Records the conversation in the local history (null: off).
  final NexaHistoryController? history;

  /// Attachments / tool runs shared with live voice (null: text only).
  final NexaConversationMedia? media;

  /// Device actions behind the composer's attach button (null: hidden).
  final NexaDeviceActions? deviceActions;

  /// Factory for the screen's bloc (injected from the SDK container).
  final ChatBloc Function() createBloc;

  /// Live presentation settings.
  final ValueListenable<sdk.NexaUiSettings> settings;

  /// Whether an "end chat" affordance is rendered inside the view.
  final bool showEndAction;

  /// Called after the user ends the chat.
  final VoidCallback? onEnded;

  /// Suggested first messages for the empty conversation, per language code
  /// (`en`, `ar`). Tapping one sends it.
  final List<String> Function(String languageCode)? suggestions;

  /// When set, the composer shows a live-voice button that calls this.
  final VoidCallback? onVoice;

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
        final theme = settings.resolveTheme(context, locale);
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
                  suggestions:
                      widget.suggestions?.call(locale.languageCode) ?? const [],
                  onVoice: widget.onVoice,
                  media: widget.media,
                  actions: widget.deviceActions,
                  history: widget.history,
                  surfaces: widget.surfaces,
                  toolCalls: widget.toolCalls,
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
  const _ChatBody({
    required this.showEndAction,
    required this.suggestions,
    this.onEnded,
    this.onVoice,
    this.media,
    this.actions,
    this.history,
    this.surfaces,
    this.toolCalls,
  });
  final NexaSurfaceController? surfaces;
  final LabeebToolCallController? toolCalls;
  final NexaHistoryController? history;
  final NexaConversationMedia? media;
  final NexaDeviceActions? actions;
  final bool showEndAction;
  final VoidCallback? onEnded;
  final List<String> suggestions;
  final VoidCallback? onVoice;

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

  int _mediaCount = 0;
  StreamSubscription<ConversationEvent>? _toolEvents;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<ChatBloc>();
    final tc = widget.toolCalls;
    if (tc != null && _toolEvents == null) {
      // Tool calls are answered in this chat's session; device UI
      // (camera, pickers) is presented from this view.
      tc
        ..chatSession = (() => bloc.sessionId?.value)
        ..conversation = (() => bloc.conversationId)
        ..presenter = (() => mounted ? context : null)
        ..uiEventSink = bloc.sendUiEvent;
      _toolEvents = bloc.toolEvents.listen(tc.ingest);
    }
  }

  Future<bool> _openExternal(Uri url) {
    final opener = widget.actions?.options.urlOpener ?? const PluginUrlOpener();
    return opener.openInBrowser(url);
  }

  /// Sends [text]; an image the message refers to is uploaded to the
  /// conversation first and sent as an attachment (labeeb.sdk/1).
  Future<void> _send(ChatBloc bloc, String text) async {
    final media = widget.media;
    final ref = media?.reference.value;
    final tc = widget.toolCalls;
    var attachments = const <String>[];
    if (ref != null && ref.localPath != null && tc != null) {
      final l10n = NexaLocalizations.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      final cid = bloc.conversationId;
      if (cid == null) {
        messenger?.showSnackBar(
          SnackBar(content: Text(l10n.tcUploadUnavailable)),
        );
        return;
      }
      try {
        final name = ref.name ?? ref.localPath!.split('/').last;
        final asset = await tc.api.uploadAsset(
          cid,
          await File(ref.localPath!).readAsBytes(),
          mime: uploadMimeFor(name) ?? ref.mimeType,
          filename: name,
        );
        attachments = [asset.id];
        media!.reference.value = ref.copyWith(
          remoteId: asset.id,
          status: NexaAttachmentStatus.uploaded,
        );
      } on Object catch (e) {
        final code = gatewayErrorCode(e);
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              code == 'forbidden' || code == null
                  ? l10n.tcUploadUnavailable
                  : labeebErrorText(l10n, code),
            ),
          ),
        );
        return;
      }
    }
    bloc.add(ChatMessageSent(text, attachments: attachments));
    widget.actions?.onMessageSent(text);
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    widget.media?.addListener(_onMedia);
    _mediaCount = widget.media?.items.length ?? 0;
  }

  @override
  void dispose() {
    widget.media?.removeListener(_onMedia);
    unawaited(_toolEvents?.cancel());
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onMedia() {
    if (!mounted) return;
    final n = widget.media!.items.length;
    final added = n > _mediaCount;
    _mediaCount = n;
    setState(() {});
    if (added) _scrollToEnd(force: true);
  }

  Future<void> _directions(
    BuildContext context,
    NexaDeviceActions actions,
    NexaPlace place,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final failed = NexaLocalizations.of(context).directionsFailed;
    final r = await actions.openDirections(context, place);
    if (!r.isSuccess) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  /// Messages and media items in time order.
  List<Object> _timeline(List<ChatMessage> messages) {
    final items = widget.media?.items ?? const <NexaConversationItem>[];
    if (items.isEmpty) return messages;
    final out =
        <(DateTime, int, Object)>[
          for (final (i, m) in messages.indexed) (m.createdAt, i, m),
          for (final (i, it) in items.indexed)
            (it.createdAt, messages.length + i, it),
        ]..sort((a, b) {
          final c = a.$1.compareTo(b.$1);
          return c != 0 ? c : a.$2.compareTo(b.$2);
        });
    return [for (final e in out) e.$3];
  }

  Widget _mediaRow(BuildContext context, NexaConversationItem item) {
    final actions = widget.actions;
    return switch (item) {
      NexaAttachmentItem() => NexaAttachmentBubble(
        item: item,
        onOpen: () => openNexaImage(context, item.attachment, actions),
      ),
      NexaToolRunItem() => NexaToolRunCard(item: item, actions: actions),
      NexaPlacesItem() => NexaPlacesCard(
        item: item,
        selectedPlaceId: widget.media?.selectedPlaceId,
        onSelect: widget.media?.selectPlace,
        onDirections: actions == null || !actions.canOpenDirections
            ? null
            : (place) => _directions(context, actions, place),
        onRetry: actions == null || !actions.canShareLocation
            ? null
            : () => actions.shareLocation(context),
        onOpenSettings: actions?.options.onOpenSettings,
      ),
      NexaSurfaceItem(:final surfaceId) => _surfaceRow(context, surfaceId),
      NexaTranscriptRefItem() => const SizedBox.shrink(),
      NexaToolCallItem(:final toolCallId) => switch (widget.toolCalls) {
        final tc? => LabeebToolCallCard(
          toolCallId: toolCallId,
          controller: tc,
          openExternal: _openExternal,
        ),
        null => const SizedBox.shrink(),
      },
      NexaUiDocumentItem(:final uiId) => switch (widget.toolCalls) {
        final tc? => NexaUiDocumentCard(
          uiId: uiId,
          controller: tc,
          openExternal: _openExternal,
        ),
        null => const SizedBox.shrink(),
      },
      NexaAssetItem(:final asset, :final toolCallId) =>
        // Shown inside its tool card when that card is on screen.
        widget.toolCalls == null ||
                (toolCallId != null &&
                    widget.toolCalls!.activity(toolCallId) != null)
            ? const SizedBox.shrink()
            : LabeebAssetView(
                asset: asset,
                bytes: widget.toolCalls!.assetBytes,
                onDelete: widget.toolCalls!.deleteAsset,
              ),
    };
  }

  Widget _surfaceRow(BuildContext context, String surfaceId) {
    final surfaces = widget.surfaces;
    final s = surfaces?.surface(surfaceId);
    if (surfaces == null || s == null) return const SizedBox.shrink();
    if (s.presentation == NexaPresentation.expandable) {
      return NexaSurfaceExpandable(surfaceId: surfaceId, controller: surfaces);
    }
    final overlay = const {
      NexaPresentation.bottomSheet,
      NexaPresentation.modal,
      NexaPresentation.fullScreen,
      NexaPresentation.floatingPanel,
    }.contains(s.presentation);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NexaSurfaceCard(surfaceId: surfaceId, controller: surfaces),
        if (overlay)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: Key('nexa_surface_open_$surfaceId'),
              onPressed: () => showNexaSurface(context, surfaces, surfaceId),
              icon: const Icon(Icons.open_in_full_rounded),
              label: Text(NexaLocalizations.of(context).duiOpen),
            ),
          ),
      ],
    );
  }

  /// Older messages were added in front (not a new message).
  bool _prepended(ChatState prev, ChatState now) {
    final a = prev.conversation.messages;
    final b = now.conversation.messages;
    return a.isNotEmpty &&
        b.length > a.length &&
        b.first.id != a.first.id &&
        b.last.id == a.last.id;
  }

  /// A prepend grows the list above the viewport: move by the added height
  /// so the message being read stays where it is.
  void _keepPositionAfterPrepend() {
    if (!_scroll.hasClients) return;
    final oldMax = _scroll.position.maxScrollExtent;
    final oldPixels = _scroll.position.pixels;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(oldPixels + (_scroll.position.maxScrollExtent - oldMax));
    });
  }

  ChatBloc? _bloc;

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final bloc = _bloc;
    if (bloc != null &&
        bloc.state.olderBefore != null &&
        !bloc.state.loadingOlder &&
        _scroll.position.pixels <= _scroll.position.minScrollExtent + 200) {
      bloc.add(const ChatOlderRequested());
    }
    final distance = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    final atBottom = distance <= _nearBottomThreshold;
    if (atBottom != _atBottom || (atBottom && _unseen)) {
      setState(() {
        _atBottom = atBottom;
        if (atBottom) _unseen = false;
      });
    }
  }

  void _scrollToEnd({bool force = false, int retries = 2}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      // The list may have attached this frame (first message after the
      // empty state) without being laid out yet: try again next frame.
      if (!_scroll.position.hasContentDimensions) {
        if (retries > 0) _scrollToEnd(force: force, retries: retries - 1);
        return;
      }
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
        if (_prepended(prev, state)) {
          _keepPositionAfterPrepend();
        } else if (prev.conversation.messages != state.conversation.messages) {
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
        final history = widget.history;
        if (history != null &&
            prev.conversation.messages != state.conversation.messages) {
          history.recordChat(
            state.conversation,
            conversationId: context.read<ChatBloc>().conversationId,
          );
        }
      },
      builder: (context, state) {
        final bloc = _bloc = context.read<ChatBloc>();
        final conv = state.conversation;
        final timeline = _timeline(conv.messages);
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
                      if (conv.messages.isEmpty &&
                          (widget.media?.items.isEmpty ?? true))
                        _EmptyState(
                          l10n: l10n,
                          suggestions: widget.suggestions,
                          onSuggestion: state.canSend
                              ? (text) => bloc.add(ChatMessageSent(text))
                              : null,
                        )
                      else
                        ListView.separated(
                          key: const Key('nexa_message_list'),
                          controller: _scroll,
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          itemCount: timeline.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) => switch (timeline[i]) {
                            final ChatMessage m => _MessageRow(
                              message: m,
                              state: state,
                              onRetry: (id) => bloc.add(ChatMessageRetried(id)),
                              onToolAction: (a) =>
                                  bloc.add(ChatToolActionSubmitted(a)),
                            ),
                            final NexaConversationItem it => _mediaRow(
                              context,
                              it,
                            ),
                            _ => const SizedBox.shrink(),
                          },
                        ),
                      if (state.loadingOlder)
                        const Align(
                          alignment: AlignmentDirectional.topCenter,
                          child: LinearProgressIndicator(
                            key: Key('nexa_older_loading'),
                            minHeight: 2,
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
                else ...[
                  if (widget.media case final media?)
                    ValueListenableBuilder(
                      valueListenable: media.reference,
                      builder: (context, ref, _) => ref == null
                          ? const SizedBox.shrink()
                          : NexaReferenceChip(
                              attachment: ref,
                              onClear: () => media.reference.value = null,
                            ),
                    ),
                  NexaComposer(
                    enabled: state.canSend,
                    isGenerating: state.generating != null,
                    onSend: (text) => _send(bloc, text),
                    onStop: () => bloc.add(const ChatGenerationCancelled()),
                    onVoice: widget.onVoice,
                    onAttach: widget.actions == null
                        ? null
                        : () => showNexaAttachSheet(context, widget.actions!),
                  ),
                ],
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

/// Design (NEXA Assistant Phone, empty conversation): a greeting anchored
/// to the bottom, near the composer, with optional suggested prompts.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.l10n,
    required this.suggestions,
    this.onSuggestion,
  });
  final NexaLocalizations l10n;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const Key('nexa_chat_empty'),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: math.max(0, constraints.maxHeight - 28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(16),
                    topEnd: Radius.circular(24),
                    bottomStart: Radius.circular(24),
                    bottomEnd: Radius.circular(24),
                  ),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.chatEmptyTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.chatEmptyBody,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 18),
                for (final (i, s) in suggestions.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _Suggestion(
                    key: Key('nexa_suggestion_$i'),
                    text: s,
                    onTap: onSuggestion == null ? null : () => onSuggestion!(s),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Suggestion extends StatelessWidget {
  const _Suggestion({required this.text, this.onTap, super.key});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
