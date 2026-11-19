// Plan C-01: the turns of a call, recorded by the gateway in the shared
// conversation, appear in the open chat once the call ends (no restart,
// no resume).
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';

import '../helpers.dart';

ChatMessage voiceMsg(int n) => ChatMessage(
  id: MessageId('v$n'),
  role: n.isOdd ? MessageRole.user : MessageRole.assistant,
  status: n.isOdd ? MessageStatus.sent : MessageStatus.completed,
  createdAt: DateTime.utc(2026, 1, 1, 0, 0, n * 10),
  text: 'spoken $n',
  origin: MessageOrigin.voice,
);

final class _Allow implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  late NexaClient client;
  late List<int?> fetches;

  setUp(() => fetches = []);
  tearDown(() => client.dispose());

  Future<ChatBloc> chatOpen() async {
    client = await Nexa.initialize(
      config: testConfig(),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: _Allow(),
      ),
      voiceOptions: const NexaVoiceOptions(
        postCallReconcileDelays: [Duration(milliseconds: 10)],
      ),
    );
    client.injector<SessionManager>().historyLoader = (cid, {beforeSeq}) async {
      fetches.add(beforeSeq);
      return ChatHistoryPage([voiceMsg(1), voiceMsg(2), voiceMsg(3)]);
    };
    final bloc = client.injector<ChatBloc>()..add(const ChatStarted());
    await waitFor(
      () => bloc.state.connection == ChatConnection.connected,
      reason: 'chat connected',
    );
    return bloc;
  }

  test(
    'persisted messages published by the coordinator reach the chat',
    () async {
      final bloc = await chatOpen();
      client.conversations.publishPersisted([voiceMsg(1), voiceMsg(2)]);
      await waitFor(() => bloc.state.conversation.messages.length == 2);
      expect(bloc.state.conversation.messages.map((m) => m.origin).toSet(), {
        MessageOrigin.voice,
      });
      // The same page again changes nothing.
      client.conversations.publishPersisted([voiceMsg(1), voiceMsg(2)]);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.conversation.messages, hasLength(2));
      await bloc.close();
    },
  );

  test(
    'a call ending triggers a fetch and the turns show in the open chat',
    () async {
      final bloc = await chatOpen();
      client.injector<SessionManager>().coordinator!.open('conv_1');
      await client.voice.start();
      await waitFor(
        () => client.voice.state.value.phase == VoiceState.listening,
        reason: 'listening',
      );
      expect(bloc.state.conversation.messages, isEmpty);

      await client.voice.end();
      await waitFor(
        () => bloc.state.conversation.messages.length == 3,
        reason: 'turns merged',
      );
      expect(fetches, isNotEmpty);
      expect(bloc.state.conversation.messages.first.text, 'spoken 1');
      await bloc.close();
    },
  );

  test('no conversation: nothing is fetched after a call', () async {
    final bloc = await chatOpen();
    client.injector<SessionManager>().coordinator!.startNew();
    await client.voice.start();
    await waitFor(() => client.voice.state.value.phase == VoiceState.listening);
    await client.voice.end();
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(fetches, isEmpty);
    await bloc.close();
  });
}
