import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';

/// [VoiceProvisioner] over the NEXA voice REST API, contract
/// `nexa.voice.v1` (backend handoff 1.0.0, `voice-contract-v1.md` §3).
///
/// The shared Dio adds `Authorization`, `X-Nexa-App-Id`,
/// `X-Nexa-Sdk-Version` and `X-Request-Id`, and refreshes the SDK token
/// once on `401`. The SDK token must carry scope `voice:session` (the host
/// backend requests it when minting).
///
/// All wire field names live in this file only.
final class GatewayVoiceProvisioner implements VoiceProvisioner {
  GatewayVoiceProvisioner({
    required Dio dio,
    required NexaLogger logger,
    this.allowLegacyHmac = false,
    this.allowInsecureWebSocket = false,
  }) : _dio = dio,
       _logger = logger;

  final Dio _dio;
  final NexaLogger _logger;

  /// Accept `events.alg == "hmac-sha256"` (operator legacy mode). Off by
  /// default: the contract's default is Ed25519 (decision D2 pending).
  final bool allowLegacyHmac;

  /// Accept `ws://` LiveKit URLs (local development only).
  final bool allowInsecureWebSocket;

  static const _base = '/v1/sdk/voice/sessions';

  @override
  Future<VoiceGrant> create({
    required String languageTag,
    SessionId? chatSessionId,
  }) async {
    try {
      final res = await _dio.post<Map<String, Object?>>(
        _base,
        data: {
          'language_tag': languageTag,
          'chat_session_id': ?chatSessionId?.value,
        },
      );
      final body = res.data;
      if (body == null) {
        throw const ContractViolationException('Empty voice grant.');
      }
      return parseGrant(
        body,
        allowLegacyHmac: allowLegacyHmac,
        allowInsecureWebSocket: allowInsecureWebSocket,
      );
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VoiceGrant> refreshToken(VoiceGrant grant) async {
    final path =
        grant.tokenRefreshPath ?? '$_base/${grant.voiceSessionId}/token';
    try {
      final res = await _dio.post<Map<String, Object?>>(path);
      final body = res.data;
      if (body == null || body['voice_session_id'] != grant.voiceSessionId) {
        throw const ContractViolationException(
          'Token refresh for another voice session.',
          path: 'voice_session_id',
        );
      }
      final lk = _object(body, 'livekit');
      return grant.withRefreshedToken(
        liveKitUrl: _liveKitUrl(lk, allowInsecureWebSocket),
        roomName: _str(lk, 'room', 'livekit.'),
        participantIdentity: _str(lk, 'identity', 'livekit.'),
        participantToken: _str(lk, 'token', 'livekit.'),
        tokenExpiresAt: _time(lk, 'token_expires_at', 'livekit.'),
      );
    } on DioException catch (e) {
      final code = _errorCode(e);
      final status = e.response?.statusCode;
      if (status == 410 || (status == 429 && code == 'rate_limited')) {
        // 410 voice_session_ended: stop. 429 on refresh is the exhausted
        // budget (retryable:false): treat as over, start a new session.
        throw VoiceSessionOverException(code ?? '$status');
      }
      throw mapError(e);
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VoiceSessionStatus> status(String voiceSessionId) async {
    try {
      final res = await _dio.get<Map<String, Object?>>(
        '$_base/$voiceSessionId',
      );
      return parseStatus(res.data ?? const {});
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<VoiceSessionStatus?> end(String voiceSessionId) async {
    try {
      final res = await _dio.delete<Map<String, Object?>>(
        '$_base/$voiceSessionId',
      );
      return parseStatus(res.data ?? const {});
    } on Object catch (e) {
      // Idempotent; "ignore errors other than network" (lifecycle §cleanup).
      _logger.log(
        NexaLogLevel.warning,
        'voice DELETE failed: ${mapError(e).code.name}',
      );
      return null;
    }
  }

  // ------------------------------------------------------------ parsing

  /// Parses the `201` body of `POST /v1/sdk/voice/sessions` (§3.1).
  /// Rejects: `contract != nexa.voice.v1`; `events.format != sealed`;
  /// `events.alg` other than `ed25519` (or `hmac-sha256` when legacy is
  /// allowed); a public key that is not 43 base64url chars / 32 bytes;
  /// non-`wss` LiveKit URLs unless [allowInsecureWebSocket].
  static VoiceGrant parseGrant(
    Map<String, Object?> json, {
    bool allowLegacyHmac = false,
    bool allowInsecureWebSocket = false,
  }) {
    if (json['contract'] != voiceContractV1) {
      throw ContractViolationException(
        'Unsupported voice contract "${json['contract']}".',
        path: 'contract',
      );
    }
    final id = _str(json, 'voice_session_id');
    final lk = _object(json, 'livekit');
    final events = _object(json, 'events');
    final limits = _object(json, 'limits');
    final reconnect = json['reconnect'] is Map<String, Object?>
        ? json['reconnect']! as Map<String, Object?>
        : const <String, Object?>{};

    if (events['format'] != 'sealed') {
      throw const ContractViolationException(
        'events.format must be "sealed".',
        path: 'events.format',
      );
    }
    final alg = VoiceEventAlgorithm.fromWire(events['alg'] as String?);
    if (alg == null ||
        (alg == VoiceEventAlgorithm.hmacSha256 && !allowLegacyHmac)) {
      throw ContractViolationException(
        'Unsupported events.alg "${events['alg']}".',
        path: 'events.alg',
      );
    }
    final keyText = alg == VoiceEventAlgorithm.ed25519
        ? _str(events, 'public_key', 'events.')
        : _str(events, 'key', 'events.');
    final key = _decodeKey(keyText);
    if (alg == VoiceEventAlgorithm.ed25519 &&
        (keyText.length != 43 || key == null || key.length != 32)) {
      throw const ContractViolationException(
        'events.public_key must be 43 base64url chars (32 bytes).',
        path: 'events.public_key',
      );
    }
    if (key == null) {
      throw const ContractViolationException(
        'events.key is not base64url.',
        path: 'events.key',
      );
    }
    return VoiceGrant(
      voiceSessionId: id,
      contract: voiceContractV1,
      liveKitUrl: _liveKitUrl(lk, allowInsecureWebSocket),
      roomName: _str(lk, 'room', 'livekit.'),
      participantIdentity: _str(lk, 'identity', 'livekit.'),
      participantToken: _str(lk, 'token', 'livekit.'),
      tokenExpiresAt: _time(lk, 'token_expires_at', 'livekit.'),
      eventsTopic: _str(events, 'topic', 'events.'),
      resumeRpc: _str(events, 'resume_rpc', 'events.'),
      eventAlgorithm: alg,
      eventKey: key,
      maxSeconds: _int(limits, 'max_seconds', 'limits.'),
      reservedSeconds: limits['reserved_seconds'] as int?,
      reconnectGraceSeconds: (reconnect['grace_seconds'] as int?) ?? 30,
      tokenRefreshPath: reconnect['token_refresh_path'] as String?,
      maxRefreshes: (reconnect['max_refreshes'] as int?) ?? 30,
      joinDeadlineSeconds: (json['join_deadline_seconds'] as int?) ?? 60,
    );
  }

  /// Parses the §3.3 session object (`GET` and `DELETE` responses).
  static VoiceSessionStatus parseStatus(Map<String, Object?> json) {
    final status = _str(json, 'status');
    if (!const {'provisioning', 'active', 'ended'}.contains(status)) {
      throw ContractViolationException(
        'Unknown voice status "$status".',
        path: 'status',
      );
    }
    return VoiceSessionStatus(
      voiceSessionId: _str(json, 'voice_session_id'),
      status: status,
      agentState: (json['agent_state'] as String?) ?? 'pending',
      endReason: json['end_reason'] as String?,
      maxSeconds: json['max_seconds'] as int?,
      usedSeconds: json['used_seconds'] as int?,
      remainingSeconds: json['remaining_seconds'] as int?,
      languageTag: json['language_tag'] as String?,
    );
  }

  static Map<String, Object?> _object(Map<String, Object?> json, String key) {
    final v = json[key];
    if (v is! Map<String, Object?>) {
      throw ContractViolationException('voice: missing $key', path: key);
    }
    return v;
  }

  static String _str(Map<String, Object?> json, String key, [String p = '']) {
    final v = json[key];
    if (v is! String || v.isEmpty) {
      throw ContractViolationException('voice: missing $p$key', path: '$p$key');
    }
    return v;
  }

  static int _int(Map<String, Object?> json, String key, [String p = '']) {
    final v = json[key];
    if (v is! int) {
      throw ContractViolationException('voice: missing $p$key', path: '$p$key');
    }
    return v;
  }

  static DateTime _time(Map<String, Object?> json, String key, String p) {
    final t = DateTime.tryParse(_str(json, key, p));
    if (t == null) {
      throw ContractViolationException('voice: bad $p$key', path: '$p$key');
    }
    return t;
  }

  static Uri _liveKitUrl(Map<String, Object?> lk, bool allowWs) {
    final url = Uri.tryParse(_str(lk, 'url', 'livekit.'));
    final ok =
        url != null &&
        (url.scheme == 'wss' || (allowWs && url.scheme == 'ws')) &&
        url.host.isNotEmpty;
    if (!ok) {
      throw const ContractViolationException(
        'livekit.url must be wss://',
        path: 'livekit.url',
      );
    }
    return url;
  }

  static Uint8List? _decodeKey(String text) {
    try {
      return VoiceGrant.decodeBase64Url(text);
    } on FormatException {
      return null;
    }
  }

  static String? _errorCode(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['error'] is Map) {
      return (data['error'] as Map)['code'] as String?;
    }
    return null;
  }
}
