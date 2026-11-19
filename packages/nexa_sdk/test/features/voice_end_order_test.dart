import 'dart:async';

// Defect REL-04 (docs/mobile/ENGINEERING_QA_REPORT_2026-11-18.md): ending a
// call waits for the server `DELETE` before it leaves the room, so the
// microphone stays published for as long as that request takes.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

/// The mock provisioner, with an `end` that answers only when released.
final class _SlowEnd implements VoiceProvisioner {
  final inner = MockVoiceProvisioner();
  final release = Completer<void>();
  bool endRequested = false;

  @override
  Future<VoiceGrant> create({
    required String languageTag,
    SessionId? chatSessionId,
    String? conversationId,
    List<String> clientTools = const [],
  }) => inner.create(
    languageTag: languageTag,
    chatSessionId: chatSessionId,
    conversationId: conversationId,
    clientTools: clientTools,
  );

  @override
  Future<VoiceGrant> refreshToken(VoiceGrant grant) =>
      inner.refreshToken(grant);

  @override
  Future<VoiceSessionStatus> status(String voiceSessionId) =>
      inner.status(voiceSessionId);

  @override
  Future<VoiceSessionStatus?> end(String voiceSessionId) async {
    endRequested = true;
    await release.future;
    return inner.end(voiceSessionId);
  }
}

final class _Allow implements NexaPermissionHandler {
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  test(
    'End releases the microphone without waiting for the server',
    () async {
      final transport = MockRealtimeVoiceTransport();
      final provisioner = _SlowEnd();
      final client = await Nexa.initialize(
        config: testConfig(),
        auth: MockAuthProvider(),
        overrides: NexaOverrides(
          chatTransport: fastMock(),
          voiceTransport: transport,
          voiceProvisioner: provisioner,
          permissionHandler: _Allow(),
        ),
      );
      addTearDown(client.dispose);
      final v = client.voice;
      await v.start();
      await waitFor(
        () => v.state.value.phase == VoiceState.listening,
        reason: 'listening',
      );
      expect(transport.isMicrophoneEnabled, isTrue);

      final ending = v.end();
      await waitFor(() => provisioner.endRequested, reason: 'DELETE sent');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // The server has not answered yet. The call is over for the user, so
      // the room must already be left and the microphone off.
      expect(transport.isConnected, isFalse);
      expect(transport.isMicrophoneEnabled, isFalse);

      provisioner.release.complete();
      await ending;
    },
    skip:
        'REL-04: fails today (teardown awaits DELETE before disconnect). '
        'Remove the skip with the fix.',
  );
}
