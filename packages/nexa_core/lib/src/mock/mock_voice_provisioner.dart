import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/transport/voice_provisioner.dart';
import 'package:nexa_core/src/voice/voice_grant.dart';

/// **MOCK - never ship.** In-memory stand-in for the four voice REST calls
/// so the controller and UI can run without a gateway or LiveKit. Tests
/// script the authoritative server status with [serverStatus].
final class MockVoiceProvisioner implements VoiceProvisioner {
  MockVoiceProvisioner({
    this.failCreateWith,
    this.maxSeconds = 600,
    this.tokenLifetime = const Duration(seconds: 60),
  });

  /// When set, [create] throws this (and nothing is created).
  Object? failCreateWith;

  /// When set, [refreshToken] throws this.
  Object? failRefreshWith;

  /// When set, [status] throws this.
  Object? failStatusWith;

  final int maxSeconds;
  final Duration tokenLifetime;

  /// What `GET` answers. Defaults to an active session with a joined agent.
  VoiceSessionStatus Function(String id)? serverStatus;

  int created = 0;
  int refreshed = 0;
  int statusCalls = 0;
  final List<String> ended = [];
  final List<String> languageTags = [];
  final List<SessionId?> chatSessionIds = [];

  /// A fixed 32-byte public key; mock transports do not verify signatures.
  static final mockPublicKey = Uint8List(32);

  @override
  Future<VoiceGrant> create({
    required String languageTag,
    SessionId? chatSessionId,
  }) async {
    final failure = failCreateWith;
    if (failure != null) throw failure;
    created++;
    languageTags.add(languageTag);
    chatSessionIds.add(chatSessionId);
    final id = 'vs_mock_$created';
    return VoiceGrant(
      voiceSessionId: id,
      liveKitUrl: Uri.parse('wss://mock.invalid'),
      roomName: 'nexa-$id',
      participantIdentity: 'nexa-user-$id',
      participantToken: 'mock-join-token',
      tokenExpiresAt: clock.now().add(tokenLifetime),
      eventAlgorithm: VoiceEventAlgorithm.ed25519,
      eventKey: mockPublicKey,
      maxSeconds: maxSeconds,
      reservedSeconds: maxSeconds,
      tokenRefreshPath: '/v1/sdk/voice/sessions/$id/token',
    );
  }

  @override
  Future<VoiceGrant> refreshToken(VoiceGrant grant) async {
    final failure = failRefreshWith;
    if (failure != null) throw failure;
    refreshed++;
    return grant.withRefreshedToken(
      liveKitUrl: grant.liveKitUrl,
      roomName: grant.roomName,
      participantIdentity: grant.participantIdentity,
      participantToken: 'mock-join-token-$refreshed',
      tokenExpiresAt: clock.now().add(tokenLifetime),
    );
  }

  @override
  Future<VoiceSessionStatus> status(String voiceSessionId) async {
    statusCalls++;
    final failure = failStatusWith;
    if (failure != null) throw failure;
    final custom = serverStatus;
    if (custom != null) return custom(voiceSessionId);
    if (ended.contains(voiceSessionId)) {
      return VoiceSessionStatus(
        voiceSessionId: voiceSessionId,
        status: 'ended',
        agentState: 'ended',
        endReason: 'user_ended',
      );
    }
    return VoiceSessionStatus(
      voiceSessionId: voiceSessionId,
      status: 'active',
      agentState: 'joined',
      remainingSeconds: maxSeconds,
    );
  }

  @override
  Future<VoiceSessionStatus?> end(String voiceSessionId) async {
    ended.add(voiceSessionId);
    return VoiceSessionStatus(
      voiceSessionId: voiceSessionId,
      status: 'ended',
      agentState: 'ended',
      endReason: 'user_ended',
    );
  }
}
