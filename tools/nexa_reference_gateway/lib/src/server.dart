import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nexa_reference_gateway/src/scripts.dart';
import 'package:nexa_reference_gateway/src/store.dart';
import 'package:nexa_reference_gateway/src/voice.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

/// Contract version this server implements.
const contractVersion = '0.2.0-proposed';

const _knownCapabilities = {
  'textChat',
  'voiceMessages',
  'liveVoice',
  'toolCalling',
  'richResults',
  'attachments',
};

/// Capabilities the reference gateway grants. `liveVoice` is added only when
/// a LiveKit dev server is configured; attachments/voice messages never.
const _grantable = {'textChat', 'toolCalling', 'richResults'};

/// Local reference implementation of the proposed NEXA Gateway SDK surface.
/// See README: development infrastructure only.
final class ReferenceGateway {
  ReferenceGateway._(this.options, VoiceOptions voiceOptions)
    : store = GatewayStore(options),
      _log = options.verbose ? stderr.writeln : null {
    _responder = ScriptedResponder(store);
    voice = VoiceService(voiceOptions, store)..log = _log;
  }

  final GatewayOptions options;
  final GatewayStore store;
  late final ScriptedResponder _responder;

  /// Voice provisioning + mock agent (DEV ONLY).
  late final VoiceService voice;
  final void Function(String)? _log;
  HttpServer? _server;

  /// Base URI of the running server.
  Uri get uri => Uri.parse('http://${_server!.address.host}:${_server!.port}');

  int get port => _server!.port;

  /// Starts listening. `port: 0` picks a free port (tests).
  static Future<ReferenceGateway> start({
    String host = '127.0.0.1',
    int port = 8080,
    GatewayOptions options = const GatewayOptions(),
    VoiceOptions voice = const VoiceOptions(),
  }) async {
    final gw = ReferenceGateway._(options, voice);
    gw._server = await shelf_io.serve(gw.handler, host, port);
    return gw;
  }

  Future<void> close() async {
    await voice.dispose();
    await _server?.close(force: true);
    store.dispose();
  }

  /// Convenience for tests: mint a token without HTTP.
  IssuedToken mintToken(String applicationId, {Duration? ttl}) =>
      store.mintToken(applicationId, ttl: ttl);

  /// The shelf handler (also usable without a socket).
  Handler get handler {
    final router = Router()
      ..get('/healthz', _health)
      ..post('/v1/dev/session-tokens', _mintToken)
      ..post('/v1/dev/applications/<appId>/reset', _resetApplication)
      ..post('/v1/sdk/sessions', _createSession)
      ..get('/v1/sdk/sessions/<sessionId>/events', _pollEvents)
      ..get('/v1/sdk/sessions/<sessionId>/events/stream', _streamEvents)
      ..post('/v1/sdk/sessions/<sessionId>/messages', _postMessage)
      ..post(
        '/v1/sdk/sessions/<sessionId>/messages/<messageId>/cancel',
        _cancelMessage,
      )
      ..post('/v1/sdk/sessions/<sessionId>/tool-actions', _toolAction)
      ..post(
        '/v1/sdk/sessions/<sessionId>/permissions/<requestId>',
        _permissionResult,
      )
      ..delete('/v1/sdk/sessions/<sessionId>', _endSession)
      // Voice (PROPOSED surface, see docs/contracts/nexa-voice-provisioning.proposed.md)
      ..post('/v1/sdk/sessions/<sessionId>/voice', _provisionVoice)
      ..post('/v1/sdk/sessions/<sessionId>/voice/intents', _voiceIntent)
      ..delete('/v1/sdk/sessions/<sessionId>/voice', _endVoice);
    return const Pipeline()
        .addMiddleware(_logging)
        .addMiddleware(_catchErrors)
        .addHandler(router.call);
  }

  // --------------------------------------------------------------- helpers

  Middleware get _logging =>
      (inner) => (req) async {
        final res = await inner(req);
        // Never log headers (they carry the bearer token).
        _log?.call('${req.method} /${req.url.path} -> ${res.statusCode}');
        return res;
      };

  Middleware get _catchErrors =>
      (inner) => (req) async {
        try {
          return await inner(req);
        } on _ApiError catch (e) {
          return e.response;
        } on FormatException catch (e) {
          return _error(400, 'bad_request', 'Malformed JSON: ${e.message}');
        }
      };

  static Response _json(int status, Object body) => Response(
    status,
    body: jsonEncode(body),
    headers: const {'content-type': 'application/json'},
  );

  static Response _error(
    int status,
    String code,
    String message, {
    bool retryable = false,
    int? retryAfterSeconds,
    String? quotaKind,
  }) => _json(status, {
    'error': {
      'code': code,
      'message': message,
      'retryable': retryable,
      'retry_after_seconds': ?retryAfterSeconds,
      'quota_kind': ?quotaKind,
    },
  });

  Future<Map<String, Object?>> _body(Request req) async {
    final text = await req.readAsString();
    if (text.isEmpty) return const {};
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, Object?>) {
      throw _ApiError(_error(400, 'bad_request', 'Body must be an object.'));
    }
    return decoded;
  }

  /// Authenticates `/v1/sdk/*` requests. Authorisation decisions (which
  /// application the token belongs to) happen here, server-side; the
  /// `X-Nexa-App-Id` header is informational and must match.
  IssuedToken _authenticate(Request req) {
    final header = req.headers['authorization'] ?? '';
    if (!header.startsWith('Bearer ')) {
      throw _ApiError(
        _error(401, 'missing_token', 'Authorization bearer token required.'),
      );
    }
    final token = store.tokens[header.substring(7).trim()];
    if (token == null) {
      throw _ApiError(_error(401, 'invalid_token', 'Unknown session token.'));
    }
    if (token.isExpired) {
      throw _ApiError(
        _error(401, 'token_expired', 'Session token expired.', retryable: true),
      );
    }
    final appId = req.headers['x-nexa-app-id'];
    if (appId != null && appId != token.applicationId) {
      throw _ApiError(
        _error(
          403,
          'application_mismatch',
          'Token was not issued for this application.',
        ),
      );
    }
    if ((req.headers['x-nexa-sdk-version'] ?? '').isEmpty) {
      throw _ApiError(
        _error(400, 'missing_sdk_version', 'X-Nexa-Sdk-Version is required.'),
      );
    }
    return token;
  }

  SessionState _session(Request req, IssuedToken token, String sessionId) {
    final session = store.sessions[sessionId];
    if (session == null) {
      throw _ApiError(_error(404, 'session_not_found', 'Unknown session.'));
    }
    if (session.applicationId != token.applicationId) {
      throw _ApiError(
        _error(403, 'forbidden', 'Session belongs to another application.'),
      );
    }
    return session;
  }

  static void _requireActive(SessionState session) {
    if (session.ended) {
      throw _ApiError(
        _error(
          410,
          session.endReason == 'expired' ? 'session_expired' : 'session_ended',
          'Session is no longer active (${session.endReason}).',
        ),
      );
    }
  }

  // -------------------------------------------------------------- handlers

  Response _health(Request req) => _json(200, {
    'status': 'ok',
    'contract_version': contractVersion,
    'reference_implementation': true,
    'sessions': store.sessions.length,
  });

  /// DEV ONLY. Stands in for the host backend's token minting. In the real
  /// system the host backend authenticates its user and calls the gateway's
  /// tenant endpoint with the tenant API key; the device never sees that key.
  Future<Response> _mintToken(Request req) async {
    final body = await _body(req);
    final appId = body['application_id'];
    if (appId is! String || appId.isEmpty) {
      return _error(422, 'validation_failed', 'application_id is required.');
    }
    final ttl = body['ttl_seconds'];
    final token = store.mintToken(
      appId,
      ttl: ttl is int ? Duration(seconds: ttl) : null,
    );
    return _json(201, {
      'token': token.token,
      'expires_at': token.expiresAt.toIso8601String(),
      'application_id': token.applicationId,
      'scopes': ['chat:session'],
    });
  }

  Response _resetApplication(Request req, String appId) {
    store.application(appId).quotaRemaining = options.quotaPerApplication;
    voice.resetQuota(appId);
    return Response(204);
  }

  Future<Response> _createSession(Request req) async {
    final token = _authenticate(req);
    final body = await _body(req);
    final appId = body['application_id'];
    if (appId != token.applicationId) {
      return _error(
        403,
        'application_mismatch',
        'application_id does not match the credential.',
      );
    }
    final lang = body['language_tag'];
    if (lang is! String || !const {'en', 'ar'}.contains(lang)) {
      return _error(422, 'validation_failed', 'language_tag must be en or ar.');
    }
    final requested = body['requested_capabilities'];
    if (requested is! List) {
      return _error(
        422,
        'validation_failed',
        'requested_capabilities must be a list.',
      );
    }
    final app = store.application(token.applicationId);
    if (app.quotaRemaining <= 0) {
      return _error(
        402,
        'quota_exceeded',
        'Message quota exhausted for this application.',
        quotaKind: 'messages',
      );
    }
    final grantable = {..._grantable, if (voice.livekit != null) 'liveVoice'};
    final granted = [
      for (final c in requested)
        if (c is String &&
            _knownCapabilities.contains(c) &&
            grantable.contains(c))
          c,
    ];
    final session = store.createSession(
      token: token,
      languageTag: lang,
      granted: granted,
    );
    session.append('session_started', {
      'expires_at': session.expiresAt.toIso8601String(),
    });
    return _json(201, {
      'session_id': session.id,
      'expires_at': session.expiresAt.toIso8601String(),
      'granted_capabilities': granted,
      'last_sequence': 0,
    });
  }

  Future<Response> _pollEvents(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final after = int.tryParse(req.url.queryParameters['after'] ?? '0') ?? 0;
    final waitMs =
        (int.tryParse(req.url.queryParameters['wait_ms'] ?? '0') ?? 0).clamp(
          0,
          30000,
        );
    if (session.chaos.failNextPoll) {
      session.chaos.failNextPoll = false;
      return _error(
        503,
        'unavailable',
        'Scripted transient failure (interrupt scenario).',
        retryable: true,
      );
    }
    // Session already over and the client is past the end: 410.
    if (session.ended && after >= session.lastSequence) {
      _requireActive(session);
    }
    var events = session.eventsAfter(after);
    if (events.isEmpty && waitMs > 0 && !session.ended) {
      await session.live.first
          .timeout(Duration(milliseconds: waitMs), onTimeout: () => const {})
          .catchError((Object _) => const <String, Object?>{});
      events = session.eventsAfter(after);
    }
    return _json(200, {
      'events': events,
      'cursor': events.isEmpty ? after : events.last['sequence'],
      'done':
          session.ended &&
          (events.isEmpty || events.last['type'] == 'session_ended'),
    });
  }

  /// Server-Sent Events delivery. Same event schema; `id:` carries the
  /// sequence so a standard `Last-Event-ID` could resume, but the SDK uses
  /// the explicit `after` query parameter.
  Future<Response> _streamEvents(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final after = int.tryParse(req.url.queryParameters['after'] ?? '0') ?? 0;
    if (session.ended && after >= session.lastSequence) _requireActive(session);

    StreamSubscription<Map<String, Object?>>? live;
    Timer? keepAlive;
    late final StreamController<List<int>> out;
    var closed = false;

    void finish() {
      if (closed) return;
      closed = true;
      keepAlive?.cancel();
      unawaited(live?.cancel());
      unawaited(out.close());
    }

    void write(Map<String, Object?> event) {
      if (closed) return;
      final seq = event['sequence']! as int;
      out.add(utf8.encode('id: $seq\ndata: ${jsonEncode(event)}\n\n'));
      if (session.chaos.duplicateEvents) {
        out.add(utf8.encode('id: $seq\ndata: ${jsonEncode(event)}\n\n'));
      }
      if (session.chaos.dropStreamAfterSequence == seq) {
        session.chaos.dropStreamAfterSequence = null;
        finish(); // deliberate interruption without session_ended
        return;
      }
      if (event['type'] == 'session_ended') finish();
    }

    out = StreamController<List<int>>(
      onListen: () {
        out.add(utf8.encode('retry: 1000\n\n'));
        // Subscribe live first, then replay, so nothing is lost in between.
        var replayed = 0;
        final snapshot = session.log
            .where((e) => (e['sequence']! as int) > after)
            .toList();
        replayed = snapshot.isEmpty ? after : snapshot.last['sequence']! as int;
        if (!session.ended) {
          live = session.live.listen((e) {
            if ((e['sequence']! as int) > replayed) write(e);
          }, onDone: finish);
        }
        for (final e in snapshot) {
          write(e);
        }
        if (session.ended) finish();
        if (options.keepAliveInterval > Duration.zero) {
          keepAlive = Timer.periodic(options.keepAliveInterval, (_) {
            if (!closed) out.add(utf8.encode(': keep-alive\n\n'));
          });
        }
      },
      onCancel: finish,
    );

    return Response.ok(
      out.stream,
      headers: const {
        'content-type': 'text/event-stream; charset=utf-8',
        'cache-control': 'no-cache',
        'connection': 'keep-alive',
        'x-accel-buffering': 'no',
      },
      context: const {'shelf.io.buffer_output': false},
    );
  }

  Future<Response> _postMessage(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    _requireActive(session);
    final key = req.headers['idempotency-key'];
    if (key == null || key.isEmpty) {
      return _error(
        400,
        'missing_idempotency_key',
        'Idempotency-Key required.',
      );
    }
    final body = await _body(req);
    final clientId = body['client_message_id'];
    final text = body['text'];
    if (clientId is! String || clientId.isEmpty || clientId != key) {
      return _error(
        422,
        'validation_failed',
        'client_message_id must equal Idempotency-Key.',
      );
    }
    if (text is! String || text.trim().isEmpty || text.length > 8000) {
      return _error(422, 'validation_failed', 'text must be 1..8000 chars.');
    }
    final previous = session.idempotency[clientId];
    if (previous != null) {
      if (previous != text) {
        return _error(
          409,
          'idempotency_conflict',
          'Same Idempotency-Key with a different body.',
        );
      }
      return Response(202); // replay: acknowledged, nothing re-emitted
    }
    final lower = text.toLowerCase();
    if (lower.contains('ratelimit') && session.chaos.rateLimitArmed) {
      session.chaos.rateLimitArmed = false;
      return _error(
        429,
        'rate_limited',
        'Scripted rate limit; retry shortly.',
        retryable: true,
        retryAfterSeconds: 1,
      );
    }
    final app = store.application(session.applicationId);
    if (app.quotaRemaining <= 0) {
      return _error(
        402,
        'quota_exceeded',
        'Message quota exhausted.',
        quotaKind: 'messages',
      );
    }
    if (session.replies.values.any((r) => !r.finished)) {
      return _error(
        409,
        'assistant_busy',
        'An assistant reply is still in progress; wait or cancel it.',
      );
    }
    session.idempotency[clientId] = text;
    app.quotaRemaining--;
    if (lower.contains('interrupt')) session.chaos.dropStreamAfterSequence = -1;
    if (lower.contains('reject')) {
      session.append('user_message_rejected', {
        'client_message_id': clientId,
        'error': {
          'code': 'policy_violation',
          'message': 'Scripted rejection (reference gateway).',
          'retryable': false,
        },
      });
      return Response(202);
    }
    final userMessageId = session.nextMessageId('user');
    session.append('user_message_accepted', {
      'message_id': userMessageId,
      'client_message_id': clientId,
    });
    unawaited(
      _responder.respond(session, userMessageId: userMessageId, text: text),
    );
    return Response(202);
  }

  Future<Response> _cancelMessage(
    Request req,
    String sessionId,
    String messageId,
  ) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    _requireActive(session);
    if (!session.replies.containsKey(messageId)) {
      return _error(404, 'message_not_found', 'Unknown assistant message.');
    }
    if (!_responder.requestCancel(session, messageId)) {
      return _error(409, 'already_finished', 'Message already finished.');
    }
    return Response(202);
  }

  Future<Response> _toolAction(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    _requireActive(session);
    final body = await _body(req);
    final kind = body['kind'];
    final callId = body['tool_call_id'];
    if (kind is! String || callId is! String) {
      return _error(
        422,
        'validation_failed',
        'kind and tool_call_id required.',
      );
    }
    final call = session.toolCalls[callId];
    if (call == null || call.resolved) {
      return _error(
        409,
        'not_awaiting_action',
        'Tool call is not awaiting this action.',
      );
    }
    if (kind != 'confirmed' && kind != 'declined') {
      return _error(409, 'not_awaiting_action', 'Expected confirmed/declined.');
    }
    unawaited(_responder.resolveToolAction(session, call, kind: kind));
    return Response(202);
  }

  Future<Response> _permissionResult(
    Request req,
    String sessionId,
    String requestId,
  ) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final body = await _body(req);
    final granted = body['granted'];
    if (granted is! bool) {
      return _error(422, 'validation_failed', 'granted must be a boolean.');
    }
    session.permissions[requestId] = granted;
    return Response(204);
  }

  Response _endSession(Request req, String sessionId) {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final v = voice.forChatSession(session.id);
    if (v != null) unawaited(voice.end(v, 'chat_ended'));
    session.end('user_ended');
    return Response(204);
  }

  // ----------------------------------------------------------------- voice

  /// PROPOSED: provisions a LiveKit room-scoped grant for the chat session.
  Future<Response> _provisionVoice(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    _requireActive(session);
    if (!session.grantedCapabilities.contains('liveVoice')) {
      return _error(
        403,
        'capability_not_granted',
        'liveVoice was not granted for this session.',
        quotaKind: 'liveVoice',
      );
    }
    final lk = voice.livekit;
    if (lk == null) {
      return _error(
        503,
        'voice_unavailable',
        'No LiveKit server configured for this gateway.',
        retryable: true,
      );
    }
    if (!await lk.isReachable()) {
      return _error(
        503,
        'voice_unavailable',
        'LiveKit server unreachable at ${lk.httpBase}.',
        retryable: true,
      );
    }
    if (voice.voiceQuotaRemaining(session.applicationId) <= 0) {
      return _error(
        402,
        'quota_exceeded',
        'Voice quota exhausted for this application.',
        quotaKind: 'voice_minutes',
      );
    }
    final existing = voice.forChatSession(session.id);
    if (existing != null) {
      return _error(
        409,
        'voice_session_active',
        'A voice session is already active for this chat session.',
      );
    }
    final body = await _body(req);
    final scenario = body['scenario'];
    final grant = await voice.provision(
      session,
      text: scenario is String ? scenario : null,
    );
    return _json(201, grant);
  }

  Future<Response> _voiceIntent(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final v = voice.forChatSession(session.id);
    if (v == null) {
      return _error(404, 'voice_session_not_found', 'No active voice session.');
    }
    final body = await _body(req);
    final type = body['type'];
    if (type is! String) {
      return _error(422, 'validation_failed', 'type is required.');
    }
    unawaited(voice.onIntent(v, type));
    return Response(202);
  }

  Future<Response> _endVoice(Request req, String sessionId) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final v = voice.forChatSession(session.id);
    if (v != null) await voice.end(v, 'user_ended');
    return Response(204);
  }
}

final class _ApiError implements Exception {
  _ApiError(this.response);
  final Response response;
}
