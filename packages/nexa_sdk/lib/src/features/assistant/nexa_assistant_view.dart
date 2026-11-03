import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart' show PluginUrlOpener;
import 'package:nexa_sdk/src/features/assistant/nexa_assistant_options.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_presentation.dart';
import 'package:nexa_sdk/src/features/history/nexa_history_view.dart';
import 'package:nexa_sdk/src/features/media/nexa_media_widgets.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_voice_companion.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';
import 'package:nexa_sdk/src/features/voice/presentation/nexa_voice_identity_note.dart';
import 'package:nexa_sdk/src/nexa.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// The complete, brand-neutral assistant experience: header with the host's
/// [NexaBrand], text chat, live voice and (optionally) a home screen, in one
/// widget. Obtain through `NexaClient.assistantView`.
///
/// Navigation inside the assistant (home → chat, chat → live voice) is
/// pushed on the host's navigator; everything else (settings screens, sign
/// in) stays with the host through callbacks.
class NexaAssistantView extends StatelessWidget {
  const NexaAssistantView({
    required this.client,
    required this.brand,
    this.launchMode = NexaLaunchMode.chat,
    this.features = const NexaAssistantFeatures(),
    this.suggestions,
    this.onOpenSettings,
    this.onOpenMicrophoneSettings,
    this.headerBadge,
    this.voiceRequests,
    this.onOpenCall,
    super.key,
  });

  final NexaClient client;
  final NexaBrand brand;
  final NexaLaunchMode launchMode;
  final NexaAssistantFeatures features;
  final List<String> Function(String languageCode)? suggestions;

  /// Shows a settings action in the header (host screen). Null hides it.
  final VoidCallback? onOpenSettings;

  /// Opens the OS settings after the microphone was denied.
  final VoidCallback? onOpenMicrophoneSettings;

  /// Small widget after the brand name (e.g. a "DEV" tag).
  final Widget? headerBadge;

  /// Each event opens live voice (e.g. the host's assistant button or wake
  /// phrase), unless a call is already open. The host decides when to fire
  /// it; the SDK never listens to the microphone for it.
  final Stream<void>? voiceRequests;

  /// Lets the host's router own the call route. Called instead of the
  /// SDK's own push whenever the user (or [voiceRequests]) opens live
  /// voice; the host shows [callPage] and must not open a second one.
  ///
  /// [fromHome] is true when the user started the call on the home splash:
  /// the host should show the conversation first so closing the call lands
  /// on it.
  final void Function(BuildContext context, {required bool fromHome})?
  onOpenCall;

  /// The chat page without the launch-mode switch, for a host route such as
  /// `/c/:id`.
  Widget chatPage() => _AssistantScope(
    client: client,
    child: _VoiceRequests(
      assistant: this,
      child: _ChatPage(assistant: this),
    ),
  );

  /// The live-call page for a host route such as `/c/:id/call`. The call
  /// starts on open and ends when the page is disposed; [onClose] is the
  /// close button (the host pops its route).
  Widget callPage({VoidCallback? onClose}) => _AssistantScope(
    client: client,
    child: _LiveVoicePage(assistant: this, onClose: onClose),
  );

  /// Voice is offered only when the host allows it **and** requested the
  /// capability; the backend still decides whether a call may start.
  bool get voiceEnabled =>
      features.voice &&
      client.config.requestedCapabilities.contains(NexaCapability.liveVoice);

  @override
  Widget build(BuildContext context) => _AssistantScope(
    client: client,
    child: _VoiceRequests(
      assistant: this,
      child: switch (launchMode) {
        NexaLaunchMode.chat => _ChatPage(assistant: this),
        NexaLaunchMode.voice => _LiveVoicePage(assistant: this, root: true),
        NexaLaunchMode.home => _HomePage(assistant: this),
      },
    ),
  );

  /// Opens live voice. At most one call page per client; from the home
  /// splash the chat is opened first so closing the call lands on the
  /// conversation.
  void _openVoice(BuildContext context, {bool fromHome = false}) {
    final host = onOpenCall;
    if (host != null) {
      host(context, fromHome: fromHome);
      return;
    }
    if (_callRouteOpen[client] ?? false) return;
    _callRouteOpen[client] = true;
    final nav = Navigator.of(context);
    if (fromHome) unawaited(nav.push(_chatRoute()));
    unawaited(
      nav
          .push(_liveVoiceRoute(this))
          .whenComplete(() => _callRouteOpen[client] = false),
    );
  }

  Route<void> _chatRoute() => MaterialPageRoute<void>(
    builder: (_) => _AssistantScope(
      client: client,
      child: _ChatPage(assistant: this, pushed: true),
    ),
  );

  void _openChat(BuildContext context) =>
      Navigator.of(context).push(_chatRoute());
}

/// Clients with an SDK-pushed call page open (a second push would end the
/// call under the first when either closes).
final Expando<bool> _callRouteOpen = Expando<bool>('nexa call route open');

/// Locale, direction and theme of the assistant chrome (the chat and voice
/// views apply the same themselves).
class _AssistantScope extends StatelessWidget {
  const _AssistantScope({required this.client, required this.child});

  final NexaClient client;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: client.uiSettings,
    builder: (context, settings, _) {
      final locale = NexaLocale.fromTag(settings.languageTag);
      return Localizations.override(
        context: context,
        locale: locale,
        delegates: NexaLocale.delegates,
        child: Directionality(
          textDirection: NexaLocale.directionOf(locale),
          child: Theme(
            data: settings.resolveTheme(context, locale),
            child: child,
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ header

class _BrandTitle extends StatelessWidget {
  const _BrandTitle({required this.assistant});
  final NexaAssistantView assistant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final brand = assistant.brand;
    final subtitle = brand.subtitleFor(lang);
    return Row(
      children: [
        NexaBrandMark(brand: brand),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      brand.nameFor(lang),
                      key: const Key('assistant_brand_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (assistant.headerBadge case final badge?) ...[
                    const SizedBox(width: 8),
                    badge,
                  ],
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Widget? _historyAction(
  BuildContext context,
  NexaAssistantView a, {
  void Function()? onResumed,
}) {
  final history = a.client.history;
  if (history == null || !a.features.history) return null;
  return IconButton(
    key: const Key('assistant_history'),
    tooltip: NexaLocalizations.of(context).historyTitle,
    onPressed: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AssistantScope(
          client: a.client,
          child: NexaHistoryView(
            history: history,
            deleteLocalMedia: a.client.deviceActions.deleteLocalMedia,
            onResume: onResumed == null
                ? null
                : (entry) async {
                    final nav = Navigator.of(context);
                    final chat = ModalRoute.of(context);
                    await a.client.resumeConversation(entry.sessionId);
                    // Back to the chat, which mounts on that conversation.
                    nav.popUntil((r) => r == chat || r.isFirst);
                    onResumed();
                  },
          ),
        ),
      ),
    ),
    icon: const Icon(Icons.history_rounded),
  );
}

Widget? _settingsAction(BuildContext context, NexaAssistantView a) {
  final open = a.onOpenSettings;
  if (open == null) return null;
  return IconButton(
    key: const Key('assistant_settings'),
    tooltip: NexaLocalizations.of(context).assistantSettings,
    onPressed: open,
    icon: const Icon(Icons.tune_rounded),
  );
}

// -------------------------------------------------------------------- chat

class _ChatPage extends StatefulWidget {
  const _ChatPage({required this.assistant, this.pushed = false});
  final NexaAssistantView assistant;
  final bool pushed;

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  /// Bumped to mount a fresh chat view after "New conversation".
  int _conversation = 0;

  Future<void> _newConversation() async {
    final l10n = NexaLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    await widget.assistant.client.newConversation();
    if (!mounted) return;
    setState(() => _conversation++);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.assistantNewConversationStarted)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assistant;
    final l10n = NexaLocalizations.of(context);
    final voice = a.voiceEnabled;
    final settings = _settingsAction(context, a);
    final history = _historyAction(
      context,
      a,
      onResumed: () {
        if (mounted) setState(() => _conversation++);
      },
    );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: widget.pushed ? 0 : 16,
        title: _BrandTitle(assistant: a),
        actions: [
          if (voice)
            IconButton(
              key: const Key('assistant_voice'),
              tooltip: l10n.assistantLiveVoice,
              onPressed: () => a._openVoice(context),
              icon: const Icon(Icons.graphic_eq_rounded),
            ),
          if (a.features.newConversation)
            IconButton(
              key: const Key('assistant_new_conversation'),
              tooltip: l10n.assistantNewConversation,
              onPressed: _newConversation,
              icon: const Icon(Icons.edit_square),
            ),
          ?history,
          ?settings,
          const SizedBox(width: 4),
        ],
      ),
      body: a.client.chatView(
        key: ValueKey('conversation_$_conversation'),
        suggestions: a.features.suggestions ? a.suggestions : null,
        onVoice: voice ? () => a._openVoice(context) : null,
      ),
    );
  }
}

// -------------------------------------------------------------------- home

class _HomePage extends StatelessWidget {
  const _HomePage({required this.assistant});
  final NexaAssistantView assistant;

  @override
  Widget build(BuildContext context) {
    final a = assistant;
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final settings = _settingsAction(context, a);
    return Scaffold(
      appBar: AppBar(actions: [?settings, const SizedBox(width: 4)]),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            key: const Key('assistant_home'),
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NexaBrandMark(brand: a.brand, size: 72),
                  const SizedBox(height: 20),
                  Text(
                    a.brand.nameFor(lang),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (a.brand.subtitleFor(lang) case final subtitle?) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    a.voiceEnabled
                        ? l10n.assistantHomeBody
                        : l10n.chatEmptyTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('assistant_home_chat'),
                      onPressed: () => a._openChat(context),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text(l10n.assistantStartChat),
                    ),
                  ),
                  if (a.voiceEnabled) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: const Key('assistant_home_voice'),
                        onPressed: () => a._openVoice(context, fromHome: true),
                        icon: const Icon(Icons.graphic_eq_rounded),
                        label: Text(l10n.assistantStartVoice),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- voice

/// Opens live voice for each [NexaAssistantView.voiceRequests] event, at
/// most one page at a time (the call itself is the client's single voice
/// controller). In [NexaLaunchMode.voice] the root page is the call, so a
/// request starts it there.
class _VoiceRequests extends StatefulWidget {
  const _VoiceRequests({required this.assistant, required this.child});
  final NexaAssistantView assistant;
  final Widget child;

  @override
  State<_VoiceRequests> createState() => _VoiceRequestsState();
}

class _VoiceRequestsState extends State<_VoiceRequests> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(_VoiceRequests old) {
    super.didUpdateWidget(old);
    if (old.assistant.voiceRequests != widget.assistant.voiceRequests) {
      unawaited(_sub?.cancel());
      _listen();
    }
  }

  void _listen() =>
      _sub = widget.assistant.voiceRequests?.listen((_) => _onRequest());

  /// Opens the live-voice page; a call already running elsewhere (e.g. a
  /// compact assistant panel) continues on it.
  void _onRequest() {
    final a = widget.assistant;
    if (!mounted || !a.voiceEnabled) return;
    final voice = a.client.voice;
    if (a.launchMode == NexaLaunchMode.voice) {
      if (!voice.state.value.isActive) unawaited(voice.start());
      return;
    }
    a._openVoice(context);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens live voice over the current page with a short rise-and-fade
/// (emphasized decelerate in, accelerate out).
Route<void> _liveVoiceRoute(NexaAssistantView assistant) =>
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, _) => _AssistantScope(
        client: assistant.client,
        child: _LiveVoicePage(assistant: assistant),
      ),
      transitionsBuilder: (context, animation, _, child) {
        if (NexaMotion.reduced(context)) return child;
        final curved = CurvedAnimation(
          parent: animation,
          curve: NexaMotion.emphasizedDecelerate,
          reverseCurve: NexaMotion.emphasizedAccelerate,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

/// Live conversation (design L1): status dot, title and elapsed time over
/// the SDK voice view. Pushed: the call starts on open and ends when the
/// page closes. As the root ([NexaLaunchMode.voice]): the user starts it.
class _LiveVoicePage extends StatefulWidget {
  const _LiveVoicePage({
    required this.assistant,
    this.root = false,
    this.onClose,
  });
  final NexaAssistantView assistant;
  final bool root;

  /// Close button action; null pops the enclosing navigator route.
  final VoidCallback? onClose;

  @override
  State<_LiveVoicePage> createState() => _LiveVoicePageState();
}

class _LiveVoicePageState extends State<_LiveVoicePage> {
  late final NexaVoiceController _voice = widget.assistant.client.voice;
  DateTime? _since;
  Duration _elapsed = Duration.zero;
  Timer? _tick;

  static bool _isLive(VoiceState s) => switch (s) {
    VoiceState.idle ||
    VoiceState.ended ||
    VoiceState.microphoneDenied ||
    VoiceState.quotaExceeded ||
    VoiceState.disconnected ||
    VoiceState.connecting => false,
    _ => true,
  };

  BuildContext? Function()? _previousPresenter;

  @override
  void initState() {
    super.initState();
    _voice.state.addListener(_onState);
    // Device tools requested during the call open above this page.
    final tc = widget.assistant.client.toolCalls;
    _previousPresenter = tc.presenter;
    tc.presenter = () => mounted ? context : _previousPresenter?.call();
  }

  String? _voiceSessionId;

  /// Surfaces the user dismissed during this call.
  final Set<String> _dismissedSurfaces = {};

  @override
  void dispose() {
    final previous = _previousPresenter;
    if (previous != null) {
      widget.assistant.client.toolCalls.presenter = previous;
    }
    _voice.state.removeListener(_onState);
    _tick?.cancel();
    _recordVoice();
    // Leaving the page ends the call.
    unawaited(_voice.end());
    super.dispose();
  }

  /// Keeps the call in the local history (voice session id + final
  /// transcript lines when transcripts are kept).
  void _recordVoice() {
    final id = _voiceSessionId;
    final history = widget.assistant.client.history;
    if (id == null || history == null) return;
    history.recordVoice(id, _voice.state.value.transcript);
  }

  void _onState() {
    _voiceSessionId = _voice.currentGrant?.voiceSessionId ?? _voiceSessionId;
    final phase = _voice.state.value.phase;
    if (phase == VoiceState.ended || phase.isTerminal) _recordVoice();
    final live = _isLive(_voice.state.value.phase);
    if (live && _since == null) {
      _since = DateTime.now();
      _elapsed = Duration.zero;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _elapsed = DateTime.now().difference(_since!));
        }
      });
    } else if (!live &&
        _since != null &&
        _voice.state.value.phase != VoiceState.reconnecting) {
      _tick?.cancel();
      _since = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.assistant;
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = NexaColors.of(context);
    final phase = _voice.state.value.phase;
    final dot = switch (phase) {
      VoiceState.reconnecting ||
      VoiceState.weakNetwork ||
      VoiceState.connecting ||
      VoiceState.modelBusy => colors.warning,
      VoiceState.disconnected ||
      VoiceState.microphoneDenied ||
      VoiceState.quotaExceeded => scheme.error,
      VoiceState.idle || VoiceState.ended => scheme.outline,
      _ => colors.success,
    };
    final mm = _elapsed.inMinutes.toString().padLeft(2, '0');
    final ss = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    final settings = widget.root ? _settingsAction(context, a) : null;
    final actions = a.client.deviceActions;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: widget.root
            ? null
            : IconButton(
                key: const Key('live_voice_close'),
                tooltip: l10n.assistantClose,
                onPressed:
                    widget.onClose ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
        titleSpacing: widget.root ? 16 : 0,
        title: widget.root
            ? _BrandTitle(assistant: a)
            : Row(
                children: [
                  AnimatedContainer(
                    duration: NexaMotion.of(context, NexaMotion.medium),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.assistantLiveConversation,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
        actions: [
          if (_since != null || _elapsed > Duration.zero)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  '$mm:$ss',
                  key: const Key('live_voice_timer'),
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          // Showing something keeps the call running: the camera, picker
          // and location prompt open above this page.
          if (actions.anyEnabled)
            IconButton(
              key: const Key('live_voice_show'),
              tooltip: l10n.voiceShowSomething,
              onPressed: () => showNexaAttachSheet(
                context,
                actions,
                surface: NexaItemSurface.voice,
              ),
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
          ?settings,
          if (settings != null) const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          NexaVoiceIdentityNote(controller: _voice),
          ListenableBuilder(
            listenable: a.client.media,
            builder: (context, _) {
              final items = a.client.media.items;
              final tool = items.whereType<NexaToolRunItem>().lastOrNull;
              final places = a.client.media.latestPlaces;
              final surface = items
                  .whereType<NexaSurfaceItem>()
                  .where((i) => !_dismissedSurfaces.contains(i.surfaceId))
                  .lastOrNull;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rich content during the call; mic/audio controls stay
                  // below and the call keeps running.
                  if (surface != null)
                    NexaSurfaceCompanion(
                      surfaceId: surface.surfaceId,
                      controller: a.client.surfaces,
                      onDismiss: () => setState(
                        () => _dismissedSurfaces.add(surface.surfaceId),
                      ),
                    ),
                  LabeebVoiceCompanion(
                    media: a.client.media,
                    controller: a.client.toolCalls,
                    openExternal: (u) =>
                        (actions.options.urlOpener ?? const PluginUrlOpener())
                            .openInBrowser(u),
                  ),
                  NexaMediaTray(
                    items: [...items.whereType<NexaAttachmentItem>()],
                    onOpen: (att) => openNexaImage(context, att, actions),
                  ),
                  if (places != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: NexaPlacesCard(
                        item: places,
                        compact: true,
                        selectedPlaceId: a.client.media.selectedPlaceId,
                        onSelect: a.client.media.selectPlace,
                        onDirections: actions.canOpenDirections
                            ? (p) => actions.openDirections(
                                context,
                                p,
                                surface: NexaItemSurface.voice,
                              )
                            : null,
                      ),
                    ),
                  if (tool != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: NexaToolRunCard(item: tool, actions: actions),
                    ),
                ],
              );
            },
          ),
          Expanded(
            child: a.client.voiceView(
              key: const Key('live_voice_view'),
              autoStart: !widget.root,
              onOpenSettings: a.onOpenMicrophoneSettings,
            ),
          ),
        ],
      ),
    );
  }
}
