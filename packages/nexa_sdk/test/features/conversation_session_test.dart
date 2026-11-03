import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/session/session_manager.dart';

import '../helpers.dart';

/// Opens sessions on demand; fails the first `startSession` when asked
/// (the 429-after-create path), counting attempts.
final class _FlakyTransport implements ChatTransport {
  _FlakyTransport({this.failFirst = false});

  final bool failFirst;
  final List<String?> joined = [];

  @override
  Future<SessionHandle> startSession({
    required SessionCredential credential,
    required Set<NexaCapability> requestedCapabilities,
    required String languageTag,
    Map<String, String> clientMetadata = const {},
    List<String> clientTools = const [],
    String? conversationId,
  }) async {
    joined.add(conversationId);
    if (failFirst && joined.length == 1) {
      throw const NetworkException(NexaErrorCode.networkUnreachable, 'busy');
    }
    return SessionHandle(
      sessionId: SessionId('ses_${joined.length}'),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      grantedCapabilities: requestedCapabilities,
    );
  }

  @override
  Future<void> endSession(SessionId sessionId) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  late NexaClient client;
  late List<String> refs;

  ConversationCoordinator coordinator() => ConversationCoordinator(
    installationId: 'inst',
    create: ({required clientRef}) async {
      refs.add(clientRef);
      return 'conv_${refs.length}';
    },
  );

  setUp(() => refs = []);
  tearDown(() => client.dispose());

  Future<SessionManager> manager({
    ChatTransport? transport,
    bool withCoordinator = true,
  }) async {
    client = await initMockClient(transport: transport);
    final sessions = client.injector<SessionManager>();
    if (withCoordinator) sessions.coordinator = coordinator();
    return sessions;
  }

  test('start creates the conversation through the coordinator once', () async {
    final s = await manager();
    await s.start();
    expect(refs, hasLength(1));
    expect(s.conversationId, 'conv_1');
    expect(s.coordinator!.conversationId, 'conv_1');
  });

  test('a session failing after the create keeps the conversation: the '
      'retry joins it and does not create another', () async {
    final transport = _FlakyTransport(failFirst: true);
    final s = await manager(transport: transport);
    await expectLater(s.start(), throwsA(isA<NexaException>()));
    expect(s.conversationId, 'conv_1');
    await s.start();
    expect(refs, hasLength(1));
    expect(transport.joined, ['conv_1', 'conv_1']);
  });

  test(
    'canCreateConversation follows the coordinator or the provider',
    () async {
      final s = await manager(withCoordinator: false);
      expect(s.canCreateConversation, isFalse);
      s.conversationProvider = () async => 'conv_p';
      expect(s.canCreateConversation, isTrue);
      s
        ..conversationProvider = null
        ..coordinator = coordinator();
      expect(s.canCreateConversation, isTrue);
    },
  );

  test(
    'the deprecated setter still seeds and clears the conversation',
    () async {
      final s = await manager();
      // ignore: deprecated_member_use_from_same_package
      s.conversationId = 'conv_seed';
      expect(s.coordinator!.conversationId, 'conv_seed');
      // ignore: deprecated_member_use_from_same_package
      s.conversationId = null;
      expect(s.conversationId, isNull);
    },
  );

  test('a call started before the chat creates the conversation through '
      'the coordinator (panel cold start, no legacy provider)', () async {
    final transport = MockRealtimeVoiceTransport();
    final provisioner = MockVoiceProvisioner();
    client = await Nexa.initialize(
      config: testConfig(),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: transport,
        voiceProvisioner: provisioner,
        permissionHandler: _Allow(),
      ),
    );
    client.injector<SessionManager>()
      ..conversationProvider = null
      ..coordinator = coordinator();
    final v = client.voice;
    await v.start();
    await waitFor(() => v.state.value.phase == VoiceState.listening);
    expect(refs, hasLength(1));
    expect(provisioner.conversationIds.last, 'conv_1');
  });
}

final class _Allow implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}
