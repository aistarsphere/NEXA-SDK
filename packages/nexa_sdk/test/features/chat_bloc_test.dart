import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';

import '../helpers.dart';

final class _GrantAll implements NexaPermissionHandler {
  int calls = 0;
  @override
  Future<bool> request(NexaPermission permission) async {
    calls++;
    return true;
  }
}

void main() {
  late MockChatTransport transport;
  late NexaClient client;
  late _GrantAll permissions;

  setUp(() async {
    transport = fastMock();
    permissions = _GrantAll();
    client = await initMockClient(
      transport: transport,
      permissions: permissions,
    );
  });

  tearDown(() => client.dispose());

  ChatBloc bloc() => client.injector<ChatBloc>();

  Future<ChatBloc> started() async {
    final b = bloc()..add(const ChatStarted());
    await settle();
    expect(b.state.connection, ChatConnection.connected);
    return b;
  }

  group('ChatBloc', () {
    test('start connects and reduces sessionStarted', () async {
      final b = await started();
      expect(b.state.conversation.phase, ConversationPhase.active);
      expect(b.state.canSend, isTrue);
      await b.close();
    });

    test('send -> pending -> accepted -> streamed -> completed', () async {
      final b = await started();
      b.add(const ChatMessageSent('hello there'));
      await settle(60);
      final msgs = b.state.conversation.messages;
      expect(msgs.first.role, MessageRole.user);
      expect(msgs.first.status, MessageStatus.sent);
      expect(msgs.first.id.value, startsWith('mock-user'));
      expect(msgs.last.role, MessageRole.assistant);
      expect(msgs.last.status, MessageStatus.completed);
      expect(transport.sentMessages.single.languageTag, 'en');
      await b.close();
    });

    test(
      'send failure marks message retryable; retry reuses the same key',
      () async {
        final b = await started();
        await transport.dispose(); // force sendMessage to throw
        b.add(const ChatMessageSent('x'));
        await settle();
        final failed = b.state.conversation.messages.single;
        expect(failed.status, MessageStatus.failed);
        expect(failed.retryable, isTrue);
        b.add(ChatMessageRetried(failed.clientMessageId!));
        await settle();
        expect(
          b.state.conversation.messages.length,
          1,
          reason: 'retry must not duplicate',
        );
        await b.close();
      },
    );

    test('cancel marks the streaming message cancelled', () async {
      final slow = MockChatTransport(
        tokenDelay: const Duration(milliseconds: 15),
        thinkDelay: Duration.zero,
      );
      await client.dispose();
      client = await initMockClient(transport: slow);
      final b = await started();
      b.add(const ChatMessageSent('slow reply please'));
      await settle(40);
      expect(b.state.generating, isNotNull);
      b.add(const ChatGenerationCancelled());
      await settle(200);
      expect(b.state.generating, isNull);
      expect(
        b.state.conversation.messages.last.status,
        MessageStatus.cancelled,
      );
      await b.close();
    });

    test('tool confirmation round trip', () async {
      final b = await started();
      b.add(const ChatMessageSent('please book a table'));
      await settle(60);
      final tool = b.state.conversation.toolCalls.values.single;
      expect(tool.status, ToolExecutionStatus.awaitingConfirmation);
      expect(tool.pendingConfirmation, isNotNull);
      b.add(
        ChatToolActionSubmitted(
          ToolAction.confirmed(
            toolCallId: tool.request.id,
            confirmationId: tool.pendingConfirmation!.id,
          ),
        ),
      );
      await settle(80);
      expect(b.state.resolvedToolCalls, contains(tool.request.id));
      final after = b.state.conversation.toolCalls[tool.request.id]!;
      expect(after.status, ToolExecutionStatus.succeeded);
      expect(after.result, isA<TextToolResult>());
      expect(transport.receivedActions.single, isA<ConfirmedAction>());
      await b.close();
    });

    test(
      'permission request -> host handler -> reported to transport',
      () async {
        final b = await started();
        b.add(const ChatMessageSent('turn on the mic'));
        await settle(60);
        final pending = b.state.conversation.pendingPermissions.single;
        b.add(
          ChatPermissionAnswered(requestId: pending.requestId, proceed: true),
        );
        await settle();
        expect(permissions.calls, 1);
        expect(b.state.conversation.pendingPermissions, isEmpty);
        await b.close();
      },
    );

    test('quota exceeded ends the session and blocks sending', () async {
      final b = await started();
      b.add(const ChatMessageSent('quota check'));
      await settle(60);
      expect(b.state.conversation.quotaExceeded, isTrue);
      expect(b.state.conversation.phase, ConversationPhase.ended);
      expect(b.state.canSend, isFalse);
      expect(client.currentSession, isNull, reason: 'session manager notified');
      await b.close();
    });

    test('assistant error is reflected on the message', () async {
      final b = await started();
      b.add(const ChatMessageSent('cause an error'));
      await settle(60);
      expect(b.state.conversation.messages.last.status, MessageStatus.failed);
      await b.close();
    });

    blocTest<ChatBloc, ChatState>(
      'start failure emits disconnected with error',
      build: () {
        return ChatBloc(
          client.injector(),
          const ConversationReducer(),
          const DenyAllPermissionHandler(),
          const NoopNexaLogger(),
          testConfig(),
        );
      },
      setUp: () async => transport.dispose(),
      act: (b) => b.add(const ChatStarted()),
      wait: const Duration(milliseconds: 30),
      verify: (b) {
        expect(b.state.connection, ChatConnection.disconnected);
        expect(b.state.error, isA<NexaException>());
      },
    );
  });
}
