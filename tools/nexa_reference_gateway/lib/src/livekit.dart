import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Minimal LiveKit server-side helpers for the reference gateway:
/// participant/admin JWT minting and the RoomService Twirp API.
///
/// DEVELOPMENT ONLY. The API key/secret belong to the local
/// `livekit-server --dev` instance (`devkey` / `secret`). They never leave
/// this process; the SDK only ever receives room-scoped participant tokens.
final class LiveKitDev {
  LiveKitDev({
    required this.url,
    required this.apiKey,
    required this.apiSecret,
  });

  /// `ws://host:port` signalling URL handed to clients.
  final Uri url;
  final String apiKey;
  final String apiSecret;

  /// HTTP base for the Twirp RoomService (`ws` → `http`).
  Uri get httpBase =>
      url.replace(scheme: url.scheme == 'wss' ? 'https' : 'http');

  static String _b64(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  /// Signs a LiveKit access token (HS256) with the given video grants.
  String mintToken({
    required String identity,
    required Map<String, Object?> video,
    required Duration ttl,
    String? name,
    Map<String, Object?>? metadata,
  }) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final header = _b64(
      utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})),
    );
    final payload = _b64(
      utf8.encode(
        jsonEncode({
          'iss': apiKey,
          'sub': identity,
          'nbf': now - 10,
          'exp': now + ttl.inSeconds,
          'name': ?name,
          'video': video,
          'metadata': ?(metadata == null ? null : jsonEncode(metadata)),
        }),
      ),
    );
    final sig = _b64(
      Hmac(
        sha256,
        utf8.encode(apiSecret),
      ).convert(utf8.encode('$header.$payload')).bytes,
    );
    return '$header.$payload.$sig';
  }

  /// Room-scoped participant token: join one room, publish audio + data,
  /// subscribe. No admin rights.
  String participantToken({
    required String room,
    required String identity,
    required Duration ttl,
  }) => mintToken(
    identity: identity,
    ttl: ttl,
    name: identity,
    video: {
      'roomJoin': true,
      'room': room,
      'canPublish': true,
      'canSubscribe': true,
      'canPublishData': true,
      'canUpdateOwnMetadata': false,
    },
  );

  String _adminToken(String room) => mintToken(
    identity: 'nexa-reference-gateway',
    ttl: const Duration(minutes: 5),
    video: {'roomAdmin': true, 'room': room, 'roomCreate': true},
  );

  Future<Map<String, Object?>> _twirp(
    String method,
    String room,
    Map<String, Object?> body,
  ) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(
        httpBase.resolve('/twirp/livekit.RoomService/$method'),
      );
      req.headers.contentType = ContentType.json;
      req.headers.set('Authorization', 'Bearer ${_adminToken(room)}');
      req.write(jsonEncode(body));
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      if (res.statusCode != 200) {
        throw HttpException('LiveKit $method failed: ${res.statusCode} $text');
      }
      final decoded = text.isEmpty ? <String, Object?>{} : jsonDecode(text);
      return decoded is Map<String, Object?> ? decoded : {};
    } finally {
      client.close();
    }
  }

  /// Identities currently in [room] (empty when the room does not exist).
  Future<List<String>> listParticipants(String room) async {
    try {
      final res = await _twirp('ListParticipants', room, {'room': room});
      final list = res['participants'];
      if (list is! List) return const [];
      return [
        for (final p in list)
          if (p is Map && p['identity'] is String) p['identity'] as String,
      ];
    } on HttpException catch (e) {
      if (e.message.contains('404') || e.message.contains('not_found')) {
        return const [];
      }
      rethrow;
    }
  }

  /// Sends a reliable data packet to [room] on [topic] from the server API.
  Future<void> sendData(
    String room, {
    required List<int> data,
    required String topic,
    List<String>? destinationIdentities,
  }) => _twirp('SendData', room, {
    'room': room,
    'data': base64.encode(data),
    'kind': 'RELIABLE',
    'topic': topic,
    'destination_identities': ?destinationIdentities,
  });

  /// Deletes the room (kicks everyone). Idempotent.
  Future<void> deleteRoom(String room) async {
    try {
      await _twirp('DeleteRoom', room, {'room': room});
    } on HttpException {
      // already gone
    }
  }

  /// Liveness probe against the server's HTTP endpoint.
  Future<bool> isReachable() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
    try {
      final req = await client.getUrl(httpBase.resolve('/'));
      final res = await req.close();
      await res.drain<void>();
      return true;
    } on Object {
      return false;
    } finally {
      client.close();
    }
  }
}
