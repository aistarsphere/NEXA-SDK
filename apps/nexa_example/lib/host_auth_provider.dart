import 'dart:convert';
import 'dart:io';

import 'package:nexa_sdk/nexa_sdk.dart';

/// How a real host obtains a session credential.
///
/// The host's **own backend** holds the tenant's NEXA API key and calls the
/// gateway to mint a short-lived session token for the signed-in user. The
/// mobile app only forwards that token. Nothing secret lives on the device.
///
/// In this example the "host backend" is the reference gateway's
/// development-only endpoint `POST /v1/dev/session-tokens`
/// ([hostBackendUri]). The SDK never calls that endpoint; this provider does,
/// exactly as a real host would call `POST /me/nexa-session-token` on its
/// own API.
final class HostAuthProvider implements NexaAuthProvider {
  HostAuthProvider({required this.hostBackendUri, required this.applicationId});

  final Uri hostBackendUri;
  final String applicationId;

  /// Lifetime requested for the next token. The settings page can shorten it
  /// to demonstrate transparent renewal after a 401.
  int tokenTtlSeconds = 15 * 60;

  /// Tokens issued so far (shown in the host UI).
  int issued = 0;

  @override
  Future<SessionCredential> fetchSessionCredential() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(
        hostBackendUri.resolve('/v1/dev/session-tokens'),
      );
      req.headers.contentType = ContentType.json;
      req.write(
        jsonEncode({
          'application_id': applicationId,
          'ttl_seconds': tokenTtlSeconds,
          // voice:session is opt-in (contract v1 §2); hosts request it.
          'scopes': ['chat:session', 'voice:session'],
        }),
      );
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      if (res.statusCode != 201) {
        throw HttpException('host backend answered ${res.statusCode}: $text');
      }
      final body = jsonDecode(text) as Map<String, Object?>;
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
