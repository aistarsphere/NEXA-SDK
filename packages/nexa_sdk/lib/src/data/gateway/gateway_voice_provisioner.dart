import 'package:dio/dio.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';

/// [VoiceProvisioner] over the gateway HTTP API.
///
/// **STATUS: PROPOSED surface, validated against the reference gateway
/// only.** Paths and field names below are the SDK team's proposal
/// (`docs/contracts/nexa-voice-provisioning.proposed.md`); the production
/// `nexa-integration` contract was not available and must be mapped here
/// when it is. Everything outside this file consumes [VoiceGrant] only.
final class GatewayVoiceProvisioner implements VoiceProvisioner {
  GatewayVoiceProvisioner({required Dio dio, required NexaLogger logger})
    : _dio = dio,
      _logger = logger;

  final Dio _dio;
  final NexaLogger _logger;

  @override
  Future<VoiceGrant> provision(SessionId sessionId) async {
    try {
      final res = await _dio.post<Map<String, Object?>>(
        '/v1/sdk/sessions/${sessionId.value}/voice',
        data: const <String, Object?>{},
      );
      final body = res.data;
      if (body == null) {
        throw const ContractViolationException('Empty voice grant.');
      }
      return _parseGrant(body);
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<void> sendIntent(SessionId sessionId, String type) async {
    try {
      await _dio.post<void>(
        '/v1/sdk/sessions/${sessionId.value}/voice/intents',
        data: {'type': type},
      );
    } on Object catch (e) {
      _logger.log(NexaLogLevel.warning, 'voice intent "$type" failed: $e');
    }
  }

  @override
  Future<void> end(SessionId sessionId) async {
    try {
      await _dio.delete<void>('/v1/sdk/sessions/${sessionId.value}/voice');
    } on Object catch (e) {
      final mapped = mapError(e);
      if (mapped is SessionExpiredException) return; // already gone
      _logger.log(NexaLogLevel.warning, 'voice end failed: ${mapped.code}');
    }
  }

  /// Single place where wire field names meet the SDK model.
  static VoiceGrant _parseGrant(Map<String, Object?> json) {
    String str(String key) {
      final v = json[key];
      if (v is! String || v.isEmpty) {
        throw ContractViolationException(
          'voice grant: missing $key',
          path: key,
        );
      }
      return v;
    }

    final url = Uri.tryParse(str('livekit_url'));
    if (url == null ||
        !url.hasScheme ||
        !(url.scheme == 'ws' || url.scheme == 'wss')) {
      throw const ContractViolationException(
        'voice grant: livekit_url must be ws:// or wss://',
        path: 'livekit_url',
      );
    }
    final expires = DateTime.tryParse(str('expires_at'));
    if (expires == null) {
      throw const ContractViolationException(
        'voice grant: bad expires_at',
        path: 'expires_at',
      );
    }
    final maxSeconds = json['max_duration_seconds'];
    final key = json['event_verification_key'];
    final alg = json['event_signature_alg'];
    if (key is String && alg is String && alg != 'HMAC-SHA256') {
      throw ContractViolationException(
        'voice grant: unsupported event_signature_alg $alg',
        path: 'event_signature_alg',
      );
    }
    return VoiceGrant(
      voiceSessionId: str('voice_session_id'),
      liveKitUrl: url,
      participantToken: str('participant_token'),
      roomName: str('room_name'),
      participantIdentity: str('participant_identity'),
      agentIdentity: json['agent_identity'] as String?,
      expiresAt: expires,
      eventVerificationKey: key is String && key.isNotEmpty ? key : null,
      eventSignatureAlgorithm: alg as String?,
      maxDuration: maxSeconds is int ? Duration(seconds: maxSeconds) : null,
    );
  }
}
