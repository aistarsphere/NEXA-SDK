import 'package:clock/clock.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/transport/voice_provisioner.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';

/// **MOCK - never ship.** Issues fake voice grants locally so the voice
/// controller and UI can run without a gateway or LiveKit.
final class MockVoiceProvisioner implements VoiceProvisioner {
  MockVoiceProvisioner({
    this.failWith,
    this.grantLifetime = const Duration(minutes: 10),
    this.eventVerificationKey = 'mock-key',
  });

  /// When set, [provision] throws this.
  Object? failWith;

  final Duration grantLifetime;
  final String? eventVerificationKey;

  final List<String> intents = [];
  int provisioned = 0;
  int ended = 0;

  @override
  Future<VoiceGrant> provision(SessionId sessionId) async {
    final failure = failWith;
    if (failure != null) throw failure;
    provisioned++;
    return VoiceGrant(
      voiceSessionId: 'vs_mock_$provisioned',
      liveKitUrl: Uri.parse('ws://mock.invalid'),
      participantToken: 'mock-participant-token',
      roomName: 'mock-room',
      participantIdentity: 'user-${sessionId.value}',
      agentIdentity: 'nexa-agent',
      expiresAt: clock.now().add(grantLifetime),
      eventVerificationKey: eventVerificationKey,
      eventSignatureAlgorithm: eventVerificationKey == null
          ? null
          : 'HMAC-SHA256',
      maxDuration: const Duration(minutes: 5),
    );
  }

  @override
  Future<void> sendIntent(SessionId sessionId, String type) async {
    intents.add(type);
  }

  @override
  Future<void> end(SessionId sessionId) async {
    ended++;
  }
}
