// Contract / integration tests: the SDK's real HTTP transport (Dio, SSE and
// long-poll) against the local reference gateway over real sockets.
//
// These are NOT tests against a production NEXA gateway (none exists). They
// prove that the SDK implements the proposed contract exactly as the
// reference server does, including interruption, duplication, cancellation,
// auth renewal, quota and session disposal.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';

import '../helpers.dart';
import 'reference_auth_provider.dart';

void main() {
  late ReferenceGateway gw;
  late ReferenceAuthProvider auth;
  late MemoryNexaLogger logger;
  NexaClient? client;

  setUpAll(() {
    // flutter_test installs an HttpOverrides that returns 400 for every
    // request; these tests need real sockets.
    HttpOverrides.global = null;
  });

  setUp(() async {
    gw = await ReferenceGateway.start(
      port: 0,
      options: const GatewayOptions(
        deltaDelay: Duration(milliseconds: 5),
        slowDeltaDelay: Duration(milliseconds: 80),
        thinkDelay: Duration(milliseconds: 10),
        keepAliveInterval: Duration(milliseconds: 500),
        quotaPerApplication: 20,
      ),
    );
    auth = ReferenceAuthProvider(gw.uri);
    logger = MemoryNexaLogger();
  });

  tearDown(() async {
    await client?.dispose();
    client = null;
    await gw.close();
  });

  Future<ChatBloc> start({
    NexaEventDelivery delivery = NexaEventDelivery.serverSentEvents,
    int maxReconnectAttempts = 5,
  }) async {
    client = await Nexa.initialize(
      config: testConfig(
        gateway: gw.uri,
        delivery: delivery,
        maxReconnectAttempts: maxReconnectAttempts,
      ),
      auth: auth,
      overrides: NexaOverrides(logger: logger),
    );
    final bloc = client!.injector<ChatBloc>()..add(const ChatStarted());
    await waitFor(
      () => bloc.state.conversation.phase == ConversationPhase.active,
      reason: 'session_started over ${delivery.name}',
    );
    return bloc;
  }

  Future<ChatMessage> lastAssistant(ChatBloc bloc) async {
    await waitFor(() {
      final m = bloc.state.conversation.messages;
      return m.isNotEmpty &&
          m.last.role == MessageRole.assistant &&
          !m.last.isInProgress;
    }, reason: 'assistant reply terminal');
    return bloc.state.conversation.messages.last;
  }

  for (final delivery in NexaEventDelivery.values) {
    group('journey over ${delivery.name}', () {
      test('send → incremental stream → completed with full_text', () async {
        final bloc = await start(delivery: delivery);
        expect(
          client!.currentSession!.grantedCapabilities,
          containsAll([NexaCapability.textChat, NexaCapability.toolCalling]),
        );
        bloc.add(const ChatMessageSent('hello gateway'));
        // Partial delivery is observable: text grows before completion.
        await waitFor(() {
          final s = bloc.state.generating;
          return s != null && s.text.isNotEmpty;
        }, reason: 'streaming text visible');
        final partial = bloc.state.generating!.text;
        final reply = await lastAssistant(bloc);
        expect(reply.status, MessageStatus.completed);
        expect(reply.text.length, greaterThan(partial.length));
        expect(reply.text, contains('You said: "hello gateway"'));
        final user = bloc.state.conversation.messages.first;
        expect(user.role, MessageRole.user);
        expect(user.status, MessageStatus.sent);
        expect(user.id.value, startsWith('msg_user'));
        expect(bloc.state.canSend, isTrue);
        await bloc.close();
      });

      test('stop cancels generation mid-stream', () async {
        final bloc = await start(delivery: delivery);
        bloc.add(const ChatMessageSent('slow please'));
        await waitFor(
          () => (bloc.state.generating?.text.length ?? 0) > 5,
          reason: 'streaming started',
        );
        bloc.add(const ChatGenerationCancelled());
        final reply = await lastAssistant(bloc);
        expect(reply.status, MessageStatus.cancelled);
        expect(reply.text, isNotEmpty, reason: 'partial text kept');
        expect(bloc.state.canSend, isTrue);
        await bloc.close();
      });

      test('end session: DELETE, session_ended, disposal', () async {
        final bloc = await start(delivery: delivery);
        bloc.add(const ChatMessageSent('bye'));
        await lastAssistant(bloc);
        final sessionId = client!.currentSession!.sessionId;
        bloc.add(const ChatEnded());
        await waitFor(
          () => bloc.state.conversation.phase == ConversationPhase.ended,
        );
        expect(client!.currentSession, isNull);
        expect(gw.store.sessions[sessionId.value]!.ended, isTrue);
        await bloc.close();
        await client!.dispose();
        client = null;
        expect(Nexa.isInitialized, isFalse);
      });
    });
  }

  group('reliability (SSE)', () {
    test(
      'interrupted stream reconnects from the cursor; no text lost',
      () async {
        final bloc = await start();
        final seen = <ChatConnection>{};
        final sub = bloc.stream.listen((s) => seen.add(s.connection));
        bloc.add(const ChatMessageSent('interrupt'));
        final reply = await lastAssistant(bloc);
        await sub.cancel();
        expect(seen, contains(ChatConnection.reconnecting));
        expect(bloc.state.connection, ChatConnection.connected);
        expect(reply.status, MessageStatus.completed);
        expect(reply.text, contains('resumes once the SDK reconnects'));
        expect(bloc.state.conversation.messages.length, 2);
        expect(logger.lines.any((l) => l.contains('reconnect')), isTrue);
        await bloc.close();
      },
    );

    test('duplicated events produce exactly one bubble', () async {
      final bloc = await start();
      bloc.add(const ChatMessageSent('duplicate'));
      final reply = await lastAssistant(bloc);
      expect(reply.status, MessageStatus.completed);
      expect(bloc.state.conversation.messages.length, 2);
      expect(reply.text, contains('You said: "duplicate"'));
      await bloc.close();
    });

    test('long-poll transient 503 is retried transparently', () async {
      final bloc = await start(delivery: NexaEventDelivery.longPolling);
      bloc.add(const ChatMessageSent('interrupt'));
      final reply = await lastAssistant(bloc);
      expect(reply.status, MessageStatus.completed);
      expect(bloc.state.connection, ChatConnection.connected);
      await bloc.close();
    });

    test(
      'gateway going away exhausts reconnects and surfaces an error',
      () async {
        final bloc = await start(maxReconnectAttempts: 2);
        await gw.close();
        await waitFor(
          () => bloc.state.connection == ChatConnection.disconnected,
          reason: 'disconnected after budget',
        );
        expect(bloc.state.error, isNotNull);
        expect(bloc.state.error!.retryable, isTrue);
        expect(bloc.state.reconnectAttempt, 0);
        await bloc.close();
        // tearDown closes gw again; closing twice is safe.
      },
    );
  });

  group('retry, idempotency and duplicate submission', () {
    test(
      '429 marks the message failed; retry reuses the key and succeeds',
      () async {
        final bloc = await start();
        bloc.add(const ChatMessageSent('ratelimit'));
        await waitFor(() {
          final m = bloc.state.conversation.messages;
          return m.length == 1 && m.single.status == MessageStatus.failed;
        });
        final failed = bloc.state.conversation.messages.single;
        expect(failed.retryable, isTrue);
        expect(failed.errorCode, NexaErrorCode.rateLimited.name);
        bloc.add(ChatMessageRetried(failed.clientMessageId!));
        final reply = await lastAssistant(bloc);
        expect(reply.status, MessageStatus.completed);
        expect(
          bloc.state.conversation.messages.length,
          2,
          reason: 'no dup bubble',
        );
        final session = gw.store.sessions.values.single;
        expect(session.idempotency.keys.single, failed.clientMessageId!.value);
        await bloc.close();
      },
    );

    test('rapid double send produces one message', () async {
      final bloc = await start();
      bloc
        ..add(const ChatMessageSent('first'))
        ..add(const ChatMessageSent('second'));
      await lastAssistant(bloc);
      final users = bloc.state.conversation.messages.where(
        (m) => m.role == MessageRole.user,
      );
      expect(users.length, 1);
      expect(users.single.text, 'first');
      expect(gw.store.sessions.values.single.idempotency.length, 1);
      await bloc.close();
    });

    test('upstream failure marks the assistant message failed', () async {
      final bloc = await start();
      bloc.add(const ChatMessageSent('fail'));
      final reply = await lastAssistant(bloc);
      expect(reply.status, MessageStatus.failed);
      expect(reply.errorCode, 'upstream_error');
      expect(bloc.state.canSend, isTrue);
      await bloc.close();
    });
  });

  group('auth', () {
    test('short-lived token is renewed proactively before expiry', () async {
      auth.ttlSeconds = 2;
      final bloc = await start();
      expect(auth.issued, 1);
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      bloc.add(const ChatMessageSent('after expiry'));
      final reply = await lastAssistant(bloc);
      expect(reply.status, MessageStatus.completed);
      expect(auth.issued, 2, reason: 'exactly one renewal');
      expect(bloc.state.error, isNull);
      await bloc.close();
    });

    test(
      'server-side invalidation: 401 → forced refresh → retried once',
      () async {
        final bloc = await start();
        expect(auth.issued, 1);
        gw.store.tokens.clear(); // the gateway no longer knows the token
        bloc.add(const ChatMessageSent('still works'));
        final reply = await lastAssistant(bloc);
        expect(reply.status, MessageStatus.completed);
        expect(auth.issued, 2, reason: 'one forced refresh after 401');
        expect(bloc.state.error, isNull);
        await bloc.close();
      },
    );

    test('auth provider failure surfaces as AuthenticationException', () async {
      auth.failNextWith = StateError('host backend down');
      client = await Nexa.initialize(
        config: testConfig(gateway: gw.uri),
        auth: auth,
        overrides: NexaOverrides(logger: logger),
      );
      final bloc = client!.injector<ChatBloc>()..add(const ChatStarted());
      await waitFor(() => bloc.state.connection == ChatConnection.disconnected);
      expect(bloc.state.error, isA<AuthenticationException>());
      // Retry succeeds once the host backend is back.
      bloc.add(const ChatStarted());
      await waitFor(
        () => bloc.state.conversation.phase == ConversationPhase.active,
      );
      await bloc.close();
    });

    test('a token for another application is rejected server-side', () async {
      auth = ReferenceAuthProvider(gw.uri, applicationId: 'app_other');
      client = await Nexa.initialize(
        config: testConfig(gateway: gw.uri),
        auth: auth,
        overrides: NexaOverrides(logger: logger),
      );
      await expectLater(
        client!.startSession(),
        throwsA(isA<AuthenticationException>()),
      );
    });

    test('the bearer token never appears in SDK logs', () async {
      final bloc = await start();
      bloc.add(const ChatMessageSent('hello'));
      await lastAssistant(bloc);
      final token = gw.store.tokens.keys.single;
      for (final line in logger.lines) {
        expect(line, isNot(contains(token)));
      }
      expect(logger.lines, isNotEmpty, reason: 'verbose logging was on');
      await bloc.close();
    });
  });

  group('quota and session expiry', () {
    test(
      'quota exceeded: banner state, session ended, new session 402',
      () async {
        final bloc = await start();
        bloc.add(const ChatMessageSent('quota'));
        await waitFor(
          () => bloc.state.conversation.phase == ConversationPhase.ended,
        );
        expect(bloc.state.conversation.quotaExceeded, isTrue);
        expect(
          bloc.state.conversation.endReason,
          SessionEndReason.quotaExceeded,
        );
        expect(bloc.state.canSend, isFalse);
        await expectLater(
          client!.startSession(),
          throwsA(isA<QuotaExceededException>()),
        );
        await bloc.close();
      },
    );

    test('server-side expiry ends the chat with reason expired', () async {
      final bloc = await start();
      bloc.add(const ChatMessageSent('expire'));
      await waitFor(
        () => bloc.state.conversation.phase == ConversationPhase.ended,
      );
      expect(bloc.state.conversation.endReason, SessionEndReason.expired);
      expect(client!.currentSession, isNull);
      await bloc.close();
    });
  });

  group('tools over HTTP', () {
    test(
      'booking confirmation round trip renders a text tool result',
      () async {
        final bloc = await start();
        bloc.add(const ChatMessageSent('book a table'));
        await waitFor(() => bloc.state.conversation.awaitingUser.isNotEmpty);
        final call = bloc.state.conversation.awaitingUser.single;
        bloc.add(
          ChatToolActionSubmitted(
            ToolAction.confirmed(
              toolCallId: call.request.id,
              confirmationId: call.pendingConfirmation!.id,
            ),
          ),
        );
        final reply = await lastAssistant(bloc);
        expect(reply.status, MessageStatus.completed);
        final resolved = bloc.state.conversation.toolCalls[call.request.id]!;
        expect(resolved.result, isA<TextToolResult>());
        await bloc.close();
      },
    );

    test(
      'weather tool result passes validation and renders typed data',
      () async {
        final bloc = await start();
        bloc.add(const ChatMessageSent('weather'));
        await lastAssistant(bloc);
        final tool = bloc.state.conversation.toolCalls.values.single;
        expect(tool.result, isA<WeatherToolResult>());
        await bloc.close();
      },
    );
  });
}
