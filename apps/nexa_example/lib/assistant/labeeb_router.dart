import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexa_example/assistant/app_strings.dart';
import 'package:nexa_example/brand/labeeb_brand.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_permission_handler.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// The LABEEB assistant view: the SDK's pages, with the call route owned by
/// the app router (`/c/:id/call`) instead of an SDK push.
NexaAssistantView labeebAssistantView(
  BuildContext context,
  NexaClient client, {
  Stream<void>? voiceRequests,
}) => client.assistantView(
  brand: Labeeb.brand,
  launchMode: ExampleConfig.launchMode,
  features: ExampleConfig.features,
  suggestions: AppStrings.suggestionsFor,
  onOpenSettings: () => context.push('/settings'),
  onOpenMicrophoneSettings: HostPermissionHandler.openSettings,
  headerBadge: ExampleConfig.devTools ? const _DevBadge() : null,
  voiceRequests: voiceRequests,
  onOpenCall: (ctx, {required fromHome}) =>
      unawaited(openLabeebCall(ctx, client, fromHome: fromHome)),
);

/// The conversation list (`/`): New opens `/c/new`, an entry resumes at
/// `/c/:id`, Call opens the call over a chat over the list.
Widget labeebListPage(
  BuildContext context,
  NexaClient client, {
  Stream<void>? voiceRequests,
}) =>
    labeebAssistantView(context, client, voiceRequests: voiceRequests).listPage(
      onNew: (ctx) => unawaited(_startNew(ctx, client)),
      onOpen: (ctx, entry) =>
          unawaited(ctx.push<void>('/c/${entry.conversationId}')),
      onCall: (ctx) => unawaited(openLabeebCall(ctx, client, fromList: true)),
    );

Future<void> _startNew(BuildContext context, NexaClient client) async {
  final router = GoRouter.of(context);
  await client.newConversation();
  unawaited(router.push<void>('/c/new'));
}

bool _opening = false;

// `state` follows the top (also imperatively pushed) route; `uri` of the
// configuration ignores pushes.
bool _inCall(GoRouter router) => router.state.uri.path.endsWith('/call');

/// Opens `/c/:id/call` once. The conversation is created first (stable
/// `client_ref`) when this client keeps server conversations; without one
/// (offline, mock) the route uses `new` and the call joins or creates its
/// own. Closing the call pops to the conversation.
Future<void> openLabeebCall(
  BuildContext context,
  NexaClient client, {
  bool fromHome = false,
  bool fromList = false,
}) async {
  final router = GoRouter.of(context);
  if (_opening || _inCall(router)) return;
  _opening = true;
  try {
    String? id = client.conversationId;
    if (id == null && client.hasServerConversations) {
      try {
        // Never make the button wait on the network: after a short grace the
        // call opens anyway and the voice start creates the conversation
        // itself through the same coordinator (one shared in-flight create).
        id = await client.conversations
            .ensureConversation(reason: fromHome ? 'call_from_root' : 'call')
            .timeout(const Duration(milliseconds: 1500));
      } on NexaException {
        id = null; // the call still works, without tools or saved turns
      } on TimeoutException {
        id = null;
      }
    }
    if (_inCall(router)) return;
    final target = id ?? 'new';
    if (fromHome) router.go('/c/$target');
    if (fromList) unawaited(router.push<void>('/c/$target'));
    unawaited(router.push<void>('/c/$target/call'));
  } finally {
    _opening = false;
  }
}

/// `/c/:id`: continues conversation [conversationId] (`new` = the current
/// or next one) and shows the chat.
class RouteConversation extends StatefulWidget {
  const RouteConversation({
    required this.client,
    required this.conversationId,
    required this.builder,
    this.alwaysResume = false,
    super.key,
  });

  final NexaClient client;
  final String conversationId;
  final WidgetBuilder builder;

  /// Reload the conversation even when it is already current (a chat page
  /// mounting again needs its history; a call page over the chat must not
  /// restart the chat session).
  final bool alwaysResume;

  @override
  State<RouteConversation> createState() => _RouteConversationState();
}

class _RouteConversationState extends State<RouteConversation> {
  late Future<void> _ready = Future<void>.microtask(_open);

  Future<void> _open() async {
    final id = widget.conversationId;
    if (id != 'new' &&
        (widget.alwaysResume || widget.client.conversationId != id)) {
      await widget.client.resumeConversation(id);
    }
  }

  @override
  void didUpdateWidget(RouteConversation old) {
    super.didUpdateWidget(old);
    if (old.conversationId != widget.conversationId) {
      _ready = Future<void>.microtask(_open);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, snapshot) =>
        snapshot.connectionState == ConnectionState.done
        ? widget.builder(context)
        : const Scaffold(body: Center(child: CircularProgressIndicator())),
  );
}

/// Marks development builds (design: the "DEMO" tag in the chat header).
class _DevBadge extends StatelessWidget {
  const _DevBadge();

  @override
  Widget build(BuildContext context) {
    final colors = NexaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'DEV',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
