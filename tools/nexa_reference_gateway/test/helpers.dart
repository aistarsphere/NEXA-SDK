import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';

/// Minimal HTTP client for contract tests (dart:io only, no SDK code).
final class GwClient {
  GwClient(this.gw, {this.appId = 'app_test', this.sdkVersion = 'test'});

  final ReferenceGateway gw;
  final String appId;
  final String sdkVersion;
  final HttpClient _http = HttpClient();
  String? token;

  Future<(int, Map<String, Object?>)> call(
    String method,
    String path, {
    Object? body,
    Map<String, String> headers = const {},
    bool auth = true,
  }) async {
    final req = await _http.openUrl(method, gw.uri.resolve(path));
    req.headers.contentType = ContentType.json;
    req.headers.set('X-Nexa-App-Id', appId);
    req.headers.set('X-Nexa-Sdk-Version', sdkVersion);
    if (auth && token != null) {
      req.headers.set('Authorization', 'Bearer $token');
    }
    headers.forEach(req.headers.set);
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    final decoded = text.isEmpty ? <String, Object?>{} : jsonDecode(text);
    return (
      res.statusCode,
      decoded is Map<String, Object?> ? decoded : {'raw': decoded},
    );
  }

  Future<String> mint({int? ttlSeconds}) async {
    final (status, body) = await call(
      'POST',
      '/v1/dev/session-tokens',
      body: {'application_id': appId, 'ttl_seconds': ?ttlSeconds},
      auth: false,
    );
    if (status != 201) throw StateError('mint failed: $status $body');
    return token = body['token']! as String;
  }

  Future<(int, Map<String, Object?>)> createSession({
    String lang = 'en',
    List<String> caps = const ['textChat', 'toolCalling', 'richResults'],
  }) => call(
    'POST',
    '/v1/sdk/sessions',
    body: {
      'application_id': appId,
      'requested_capabilities': caps,
      'language_tag': lang,
      'sdk_version': sdkVersion,
      'platform': 'test',
    },
  );

  Future<String> session({String lang = 'en'}) async {
    final (status, body) = await createSession(lang: lang);
    if (status != 201) throw StateError('createSession failed: $status $body');
    return body['session_id']! as String;
  }

  Future<(int, Map<String, Object?>)> send(
    String sessionId,
    String clientId,
    String text, {
    String? key,
  }) => call(
    'POST',
    '/v1/sdk/sessions/$sessionId/messages',
    body: {'client_message_id': clientId, 'text': text},
    headers: {'Idempotency-Key': key ?? clientId},
  );

  Future<(int, Map<String, Object?>)> poll(
    String sessionId, {
    int after = 0,
    int waitMs = 0,
  }) => call(
    'GET',
    '/v1/sdk/sessions/$sessionId/events?after=$after&wait_ms=$waitMs',
  );

  /// Polls until an event of [type] appears (or [timeout]). Returns all
  /// events seen in order (duplicates included).
  Future<List<Map<String, Object?>>> pollUntil(
    String sessionId,
    String type, {
    int after = 0,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    final all = <Map<String, Object?>>[];
    var cursor = after;
    while (DateTime.now().isBefore(deadline)) {
      final (status, body) = await poll(sessionId, after: cursor, waitMs: 500);
      if (status != 200) throw StateError('poll failed: $status $body');
      final events = (body['events']! as List).cast<Map<String, Object?>>();
      all.addAll(events);
      cursor = body['cursor']! as int;
      if (events.any((e) => e['type'] == type)) return all;
      if (body['done'] == true) return all;
    }
    throw TimeoutException('no $type event');
  }

  /// Opens the SSE stream and yields parsed events until the server closes
  /// the connection.
  Stream<Map<String, Object?>> stream(
    String sessionId, {
    int after = 0,
  }) async* {
    final req = await _http.getUrl(
      gw.uri.resolve('/v1/sdk/sessions/$sessionId/events/stream?after=$after'),
    );
    req.headers.set('X-Nexa-App-Id', appId);
    req.headers.set('X-Nexa-Sdk-Version', sdkVersion);
    req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close();
    if (res.statusCode != 200) {
      throw StateError('stream failed: ${res.statusCode}');
    }
    var data = StringBuffer();
    try {
      await for (final line
          in res.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (data.isNotEmpty) {
            yield jsonDecode(data.toString()) as Map<String, Object?>;
            data = StringBuffer();
          }
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trim());
        }
      }
    } on HttpException {
      // connection force-closed by the test's tearDown
    }
  }

  /// Collects SSE events into [into] until the client is closed. Cancelling
  /// a live dart:io response subscription can block until the server closes,
  /// so collectors are abandoned and the client is force-closed in tearDown.
  void collect(
    String sessionId,
    List<Map<String, Object?>> into, {
    int after = 0,
  }) {
    stream(sessionId, after: after).listen(into.add, onError: (Object _) {});
  }

  void close() => _http.close(force: true);
}

List<String> types(Iterable<Map<String, Object?>> events) => [
  for (final e in events) e['type']! as String,
];

const fastOptions = GatewayOptions(
  deltaDelay: Duration.zero,
  slowDeltaDelay: Duration(milliseconds: 60),
  thinkDelay: Duration.zero,
  keepAliveInterval: Duration(milliseconds: 200),
  quotaPerApplication: 5,
);
