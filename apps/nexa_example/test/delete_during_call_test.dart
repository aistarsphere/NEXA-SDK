// Deleting conversations while a call is running (mock voice transport).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

final class _Server implements NexaConversationsApi {
  final ids = ['conv_1', 'conv_2'];
  final calls = <String>[];
  @override
  bool get canList => true;
  @override
  bool supportsDeletion(NexaDeletionScope scope) => true;
  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) async =>
      NexaHistoryPage([
        for (final id in ids)
          NexaHistoryEntry(
            id: id,
            kind: NexaHistoryKind.chat,
            sessionId: id,
            startedAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
            title: 'Talk $id',
            messageCount: 2,
          ),
      ]);
  @override
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  }) async {
    calls.add('${scope.name}:${conversationId ?? '-'}');
    ids.remove(conversationId);
    return const NexaDeletionReceipt(state: NexaDeletionState.completed);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}

final class _AllowMicrophone implements NexaPermissionHandler {
  const _AllowMicrophone();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  testWidgets('during a call no delete action can be reached, and the call '
      'goes on', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final server = _Server();
    final client = await Nexa.initialize(
      history: NexaHistoryOptions(
        cache: InMemoryHistoryStore(),
        server: server,
      ),
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
      ),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: MockChatTransport(
          tokenDelay: Duration.zero,
          thinkDelay: Duration.zero,
        ),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: const _AllowMicrophone(),
      ),
    );
    addTearDown(client.dispose);
    final app = ExampleApp(client: client, auth: MockAuthProvider());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('nexa_list_menu_conv_1')).hitTestable(),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nexa_list_call')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(app.router.state.uri.path, endsWith('/call'));
    expect(client.voice.state.value.isActive, isTrue);

    // The call page covers the list and Settings: nothing to delete with.
    expect(
      find.byKey(const Key('nexa_list_menu_conv_1')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const Key('nexa_list_conv_1')).hitTestable(),
      findsNothing,
    );
    expect(
      find.byKey(const Key('settings_delete_all_conversations')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('nexa_list_settings')).hitTestable(),
      findsNothing,
    );
    expect(server.calls, isEmpty);
    expect(client.voice.state.value.isActive, isTrue);

    // The only way a deletion can arrive now is from outside the call page
    // (another device, the service). The app's reaction is the conversation
    // reset the list performs after a deletion. This pins today's behaviour:
    // the call is not dropped and stays on screen, without a conversation.
    await client.newConversation();
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(client.voice.state.value.isActive, isTrue);
    expect(app.router.state.uri.path, endsWith('/call'));
    expect(client.conversationId, isNull);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('live_voice_close')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(client.voice.state.value.isActive, isFalse);
    expect(find.byKey(const Key('live_voice_close')), findsNothing);
  });
}
