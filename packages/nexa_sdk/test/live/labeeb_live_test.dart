// LIVE checks against the real AWS gateway (labeeb.sdk/1). Skipped unless
// run with the developer's secrets file, which never enters the repo:
//
//   flutter test test/live/labeeb_live_test.dart \
//     --dart-define-from-file=$HOME/.nexa/nexa_dev.json
//
// Only E2E_VERIFIED features available to the token are exercised; every
// conversation created here is deleted again.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';

import '../helpers.dart';

const _live = bool.fromEnvironment('NEXA_REAL_BACKEND');
const _gateway = String.fromEnvironment('NEXA_GATEWAY_URL');
const _appId = String.fromEnvironment('NEXA_APP_ID');
const _token = String.fromEnvironment('NEXA_DEV_SDK_TOKEN');

final class _TokenAuth implements NexaAuthProvider {
  @override
  Future<SessionCredential> fetchSessionCredential() async => SessionCredential(
    token: _token,
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  );
}

void main() {
  setUpAll(() => HttpOverrides.global = null);

  NexaClient? client;
  tearDown(() async {
    await client?.dispose();
    client = null;
  });

  Future<NexaClient> start() async => client = await Nexa.initialize(
    config: NexaConfig(
      applicationId: _appId,
      gatewayBaseUri: Uri.parse(_gateway),
      environment: NexaEnvironment.staging,
      languageTag: 'en',
      requestedCapabilities: const {
        NexaCapability.textChat,
        NexaCapability.toolCalling,
        NexaCapability.liveVoice,
      },
    ),
    auth: _TokenAuth(),
    overrides: const NexaOverrides(logger: _PrintLogger()),
  );

  test('contract document is labeeb.sdk/1', () async {
    final c = await start();
    final doc = await c.api.contract();
    expect(doc['id'], 'labeeb.sdk/1');
  }, skip: !_live);

  test('assistant profile (GET /assistant)', () async {
    final c = await start();
    final p = await c.api.assistantProfile();
    expect(p.applicationId, _appId);
    // ignore: avoid_print
    print(
      'assistant: app=${p.applicationName} env=${p.environment} '
      'name=${p.assistantName ?? '-'} welcome=${p.welcomeMessage != null}',
    );
  }, skip: !_live);

  test(
    'conversation → session → chat → history → delete',
    () async {
      final c = await start();
      final bloc = c.injector<ChatBloc>()..add(const ChatStarted());
      await waitFor(
        () =>
            bloc.conversationId != null &&
            bloc.state.conversation.phase == ConversationPhase.active,
        timeout: const Duration(seconds: 30),
      );
      final cid = bloc.conversationId!;
      try {
        bloc.add(const ChatMessageSent('Reply with exactly one word: ready'));
        await waitFor(() {
          final m = bloc.state.conversation.messages;
          return m.length >= 2 && m.last.isTerminal;
        }, timeout: const Duration(seconds: 90));
        final reply = bloc.state.conversation.messages.last;
        expect(reply.role, MessageRole.assistant);
        expect(reply.text, isNotEmpty);

        final api = LabeebConversationsApi(c.api);
        final page = await api.list();
        expect(page.items.map((e) => e.id), contains(cid));
        final messages = await api.open(cid);
        expect(messages.first.fromUser, isTrue);
        expect(messages.last.text, reply.text);
        await api.rename(cid, 'SDK live check');
        expect((await c.api.conversation(cid)).title, 'SDK live check');

        final prefs = await c.api.preferences();
        expect(prefs, isA<Map<String, Object?>>());
      } finally {
        await c.api.deleteConversation(cid);
      }
      await expectLater(
        c.api.conversation(cid),
        throwsA(
          isA<NexaException>().having(
            gatewayErrorCode,
            'code',
            'conversation_not_found',
          ),
        ),
      );
    },
    skip: !_live,
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test('tool catalogue answers honestly for this token', () async {
    final c = await start();
    await c.toolCalls.refreshCatalogue();
    // Today's token has no `tools:use` scope: the SDK must report it.
    if (c.toolCalls.catalogue == null) {
      expect(c.toolCalls.catalogueUnavailable, isNotNull);
    } else {
      expect(c.toolCalls.catalogue!.tools, isNotEmpty);
    }
    // ignore: avoid_print
    print(
      'tools: ${c.toolCalls.catalogue == null ? 'unavailable (${c.toolCalls.catalogueUnavailable})' : '${c.toolCalls.catalogue!.tools.where((t) => t.available).length} available'}',
    );
  }, skip: !_live);

  test(
    'voice session (nexa.voice.v1): granted, tools reported honestly',
    () async {
      final c = await start();
      final conv = await c.api.createConversation(kind: 'voice');
      final voice = c.injector<VoiceProvisioner>();
      VoiceGrant? grant;
      try {
        grant = await voice.create(
          languageTag: 'en',
          conversationId: conv.id,
          clientTools: await c.toolCalls.declaredTools(),
        );
        expect(grant.voiceSessionId, startsWith('vs_'));
        expect(grant.voicePath, anyOf('realtime', 'standard'));
        // Tools need `tools:use`; without it the call still starts.
        if (!grant.tools.enabled) expect(grant.tools.reason, isNotNull);
        // Spoken turns join the conversation (same id shape as the SDK).
        await c.api.reportVoiceTurns(
          conv.id,
          voiceSessionId: grant.voiceSessionId,
          turns: [
            LabeebVoiceTurn(
              role: 'user',
              text: 'hello',
              clientTurnId: '${grant.voiceSessionId}_1',
            ),
          ],
        );
        // ignore: avoid_print
        print(
          'voice: path=${grant.voicePath} tools=${grant.tools.enabled}'
          '${grant.tools.reason == null ? '' : ' (${grant.tools.reason})'}',
        );
      } finally {
        if (grant != null) await voice.end(grant.voiceSessionId);
        await c.api.deleteConversation(conv.id);
      }
    },
    skip: !_live,
  );
}

final class _PrintLogger implements NexaLogger {
  const _PrintLogger();
  @override
  void log(
    NexaLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    // ignore: avoid_print
    print('[nexa ${level.name}] $message${error == null ? '' : ' $error'}');
  }
}
