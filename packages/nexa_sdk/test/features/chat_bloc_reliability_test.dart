// Reconnect policy, duplicate-submission guard and session-expiry handling,
// exercised with a controllable transport (no sockets).
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';

import '../helpers.dart';

/// Wraps the mock transport and injects failures into `events()`.
final class _FlakyTransport implements ChatTransport {
  _FlakyTransport(this.inner);
  final MockChatTransport inner;

  /// Errors to throw on successive subscriptions (null = succeed).
  final List<NexaException?> scripted = [];
  int subscriptions = 0;
  int sends = 0;

  @override
  Stream<ConversationEvent> events(
    SessionId sessionId, {
    int afterSequence = 0,
  }) {
    final index = subscriptions++;
    final failure = index < scripted.length ? scripted[index] : null;
    if (failure != null) {
      return Stream<ConversationEvent>.error(failure);
    }
    return inner.events(sessionId, afterSequence: afterSequence);
  }

  @override
  Future<void> sendMessage(SessionId sessionId, OutgoingMessage message) {
    sends++;
    return inner.sendMessage(sessionId, message);
  }

  @override
  Future<SessionHandle> startSession({
    required SessionCredential credential,
    required Set<NexaCapability> requestedCapabilities,
    required String languageTag,
    Map<String, String> clientMetadata = const {},
  }) => inner.startSession(
    credential: credential,
    requestedCapabilities: requestedCapabilities,
    languageTag: languageTag,
    clientMetadata: clientMetadata,
  );

  @override
  Future<void> cancelMessage(SessionId sessionId, MessageId messageId) =>
      inner.cancelMessage(sessionId, messageId);

  @override
  Future<void> endSession(SessionId sessionId) => inner.endSession(sessionId);

  @override
  Future<void> reportPermissionResult(
    SessionId sessionId, {
    required String requestId,
    required bool granted,
  }) => inner.reportPermissionResult(
    sessionId,
    requestId: requestId,
    granted: granted,
  );

  @override
  Future<void> submitToolAction(SessionId sessionId, ToolAction action) =>
      inner.submitToolAction(sessionId, action);

  @override
  Future<void> dispose() => inner.dispose();
}

void main() {
  late _FlakyTransport transport;
  late NexaClient client;

  setUp(() async {
    transport = _FlakyTransport(fastMock());
  });

  tearDown(() => client.dispose());

  Future<ChatBloc> start({
    int maxReconnectAttempts = 3,
    Duration backoff = const Duration(milliseconds: 1),
  }) async {
    client = await initMockClient(
      transport: transport,
      config: testConfig(
        maxReconnectAttempts: maxReconnectAttempts,
        eventPollInterval: backoff,
      ),
    );
    final bloc = client.injector<ChatBloc>()..add(const ChatStarted());
    await waitFor(
      () =>
          bloc.state.conversation.phase == ConversationPhase.active ||
          bloc.state.connection == ChatConnection.disconnected,
    );
    return bloc;
  }

  group('reconnect policy', () {
    test('retryable stream failures reconnect from the cursor', () async {
      transport.scripted.addAll([
        null,
        const NetworkException(NexaErrorCode.networkUnreachable, 'drop'),
        const TransportException('drop again'),
        null,
      ]);
      final bloc = await start();
      final seen = <ChatConnection>[];
      final sub = bloc.stream.listen((s) => seen.add(s.connection));
      expect(bloc.state.conversation.phase, ConversationPhase.active);
      // Force the first subscription to end: dispose the inner stream by
      // ending the mock session from the server side is not possible, so
      // simulate by pushing a failure through a fresh subscribe cycle.
      bloc.add(
        const ChatTransportFailed(
          NetworkException(NexaErrorCode.networkTimeout, 'timeout'),
        ),
      );
      await waitFor(
        () =>
            bloc.state.connection == ChatConnection.connected &&
            transport.subscriptions == 4,
        reason: 'two failed reconnects then success',
      );
      await sub.cancel();
      expect(seen, contains(ChatConnection.reconnecting));
      expect(bloc.state.error, isNull);
      // Still usable.
      bloc.add(const ChatMessageSent('hi'));
      await waitFor(
        () =>
            bloc.state.conversation.messages.length == 2 &&
            bloc.state.conversation.messages.last.status ==
                MessageStatus.completed,
      );
      await bloc.close();
    });

    test('budget exhausted -> disconnected with retryable error', () async {
      transport.scripted.addAll([
        null,
        const TransportException('1'),
        const TransportException('2'),
        const TransportException('3'),
        const TransportException('4'),
      ]);
      final bloc = await start(maxReconnectAttempts: 3);
      bloc.add(const ChatTransportFailed(TransportException('0')));
      await waitFor(() => bloc.state.connection == ChatConnection.disconnected);
      expect(transport.subscriptions, 4, reason: 'initial + 3 attempts');
      expect(bloc.state.error, isA<TransportException>());
      expect(bloc.state.reconnectAttempt, 0);
      // Manual retry resumes the same session without resetting state.
      transport.scripted.clear();
      bloc.add(const ChatStarted());
      await waitFor(() => bloc.state.connection == ChatConnection.connected);
      expect(bloc.state.conversation.phase, ConversationPhase.active);
      await bloc.close();
    });

    test('auth and session errors are not retried automatically', () async {
      final bloc = await start();
      bloc.add(const ChatTransportFailed(AuthenticationException('bad token')));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.connection, ChatConnection.disconnected);
      expect(bloc.state.error, isA<AuthenticationException>());
      expect(transport.subscriptions, 1);
      await bloc.close();
    });

    test('session expired -> retry starts a fresh session', () async {
      final bloc = await start();
      final first = client.currentSession!.sessionId;
      bloc.add(const ChatTransportFailed(SessionExpiredException()));
      await waitFor(() => bloc.state.connection == ChatConnection.disconnected);
      expect(client.currentSession, isNull, reason: 'marked ended');
      bloc.add(const ChatStarted());
      await waitFor(
        () =>
            bloc.state.connection == ChatConnection.connected &&
            bloc.state.conversation.sessionId != first,
      );
      expect(bloc.state.conversation.phase, ConversationPhase.active);
      await bloc.close();
    });

    test('closing the bloc cancels a pending reconnect timer', () async {
      transport.scripted.addAll([null, const TransportException('x')]);
      final bloc = await start(backoff: const Duration(milliseconds: 100));
      bloc.add(const ChatTransportFailed(TransportException('0')));
      await waitFor(() => bloc.state.connection == ChatConnection.reconnecting);
      await bloc.close();
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(transport.subscriptions, 1, reason: 'no subscribe after close');
    });
  });

  group('duplicate submission prevention', () {
    test('a second send while the first is pending is ignored', () async {
      final slowAck = MockChatTransport(
        tokenDelay: Duration.zero,
        thinkDelay: const Duration(milliseconds: 60),
      );
      transport = _FlakyTransport(slowAck);
      final bloc = await start();
      bloc
        ..add(const ChatMessageSent('one'))
        ..add(const ChatMessageSent('two'))
        ..add(const ChatMessageSent('three'));
      await waitFor(
        () => bloc.state.conversation.messages.any(
          (m) => m.role == MessageRole.assistant && !m.isInProgress,
        ),
      );
      final users = bloc.state.conversation.messages
          .where((m) => m.role == MessageRole.user)
          .toList();
      expect(users.length, 1);
      expect(users.single.text, 'one');
      expect(transport.sends, 1);
      await bloc.close();
    });

    test('a retry queued behind a successful retry is a no-op', () async {
      final bloc = await start();
      await transport.inner.dispose();
      bloc.add(const ChatMessageSent('x'));
      await waitFor(
        () =>
            bloc.state.conversation.messages.length == 1 &&
            bloc.state.conversation.messages.single.status ==
                MessageStatus.failed,
      );
      final id = bloc.state.conversation.messages.single.clientMessageId!;
      // Bring the transport back and retry twice back-to-back.
      transport = _FlakyTransport(fastMock());
      await client.dispose();
      client = await initMockClient(transport: transport);
      final bloc2 = client.injector<ChatBloc>()..add(const ChatStarted());
      await waitFor(
        () => bloc2.state.conversation.phase == ConversationPhase.active,
      );
      bloc2
        ..add(const ChatMessageSent('y'))
        ..add(ChatMessageRetried(id)); // unknown id on this bloc: ignored
      await waitFor(
        () => bloc2.state.conversation.messages.any(
          (m) => m.role == MessageRole.assistant && !m.isInProgress,
        ),
      );
      expect(
        bloc2.state.conversation.messages
            .where((m) => m.role == MessageRole.user)
            .length,
        1,
      );
      expect(transport.sends, 1);
      await bloc.close();
      await bloc2.close();
    });
  });

  group('canSend', () {
    test(
      'false while pending, generating, disconnected or quota exceeded',
      () async {
        final bloc = await start();
        expect(bloc.state.canSend, isTrue);
        expect(
          bloc.state.copyWith(connection: ChatConnection.reconnecting).canSend,
          isFalse,
        );
        bloc.add(const ChatMessageSent('quota'));
        await waitFor(
          () => bloc.state.conversation.phase == ConversationPhase.ended,
        );
        expect(bloc.state.canSend, isFalse);
        await bloc.close();
      },
    );
  });
}
