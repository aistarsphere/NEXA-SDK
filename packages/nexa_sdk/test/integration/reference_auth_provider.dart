import 'dart:convert';
import 'dart:io';

import 'package:nexa_core/nexa_core.dart';

/// Test stand-in for the **host backend**: mints a session token from the
/// reference gateway's dev endpoint. The SDK never calls this endpoint; the
/// host's `NexaAuthProvider` does, exactly as a real host would call its own
/// backend.
final class ReferenceAuthProvider implements NexaAuthProvider {
  ReferenceAuthProvider(this.gateway, {this.applicationId = 'app_test'});

  final Uri gateway;
  final String applicationId;

  /// TTL requested for the next token (short values exercise renewal).
  int ttlSeconds = 900;

  /// Credentials issued so far, for assertions.
  int issued = 0;

  /// When set, the next fetch throws this instead of minting.
  Object? failNextWith;

  @override
  Future<SessionCredential> fetchSessionCredential() async {
    final failure = failNextWith;
    if (failure != null) {
      failNextWith = null;
      throw failure;
    }
    final client = HttpClient();
    try {
      final req = await client.postUrl(
        gateway.resolve('/v1/dev/session-tokens'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'application_id': applicationId,
          'ttl_seconds': ttlSeconds,
          // voice:session is opt-in (contract v1 §2); hosts request it.
          'scopes': ['chat:session', 'voice:session'],
        }),
      );
      final res = await req.close();
      final body =
          jsonDecode(await utf8.decodeStream(res)) as Map<String, Object?>;
      if (res.statusCode != 201) {
        throw StateError('token mint failed: ${res.statusCode} $body');
      }
      issued++;
      return SessionCredential(
        token: body['token']! as String,
        expiresAt: DateTime.parse(body['expires_at']! as String),
        scopes: const {'chat:session', 'voice:session'},
      );
    } finally {
      client.close();
    }
  }
}
