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
  IssuedToken mintToken(
    String applicationId, {
    Duration? ttl,
    Set<String> scopes = const {'chat:session'},
  }) => store.mintToken(applicationId, ttl: ttl, scopes: scopes);

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
      // labeeb.sdk/1 (contract snapshot: docs/contracts/labeeb-sdk-1/)
      ..get('/v1/sdk/contract', _contract)
      ..get('/v1/sdk/tools', _tools)
      ..get('/v1/sdk/sessions/<sessionId>/tool-calls/<callId>', _getToolCall)
      ..post(
        '/v1/sdk/sessions/<sessionId>/tool-calls/<callId>/approval',
        _approveToolCall,
      )
      ..post(
        '/v1/sdk/sessions/<sessionId>/tool-calls/<callId>/result',
        _toolCallResult,
      )
      ..post(
        '/v1/sdk/sessions/<sessionId>/tool-calls/<callId>/cancel',
        _cancelToolCall,
      )
      ..post('/v1/sdk/conversations', _createConversation)
      ..get('/v1/sdk/conversations', _listConversations)
      ..delete('/v1/sdk/conversations', _clearConversations)
      ..get('/v1/sdk/conversations/<cid>', _getConversation)
      ..patch('/v1/sdk/conversations/<cid>', _renameConversation)
      ..delete('/v1/sdk/conversations/<cid>', _deleteConversation)
      ..get('/v1/sdk/conversations/<cid>/messages', _messages)
      ..post('/v1/sdk/conversations/<cid>/voice-turns', _voiceTurns)
      ..post('/v1/sdk/conversations/<cid>/assets', _uploadAsset)
      ..get('/v1/sdk/assets/<assetId>', _getAsset)
      ..get('/v1/sdk/assets/<assetId>/content', _assetContent)
      ..delete('/v1/sdk/assets/<assetId>', _deleteAsset)
      ..get('/v1/sdk/me/preferences', _getPreferences)
      ..put('/v1/sdk/me/preferences', _putPreferences)
      ..delete('/v1/sdk/me/preferences', _deletePreferences)
      ..delete('/v1/sdk/me/assistant-data', _deleteAssistantData)
      ..post(
        '/v1/sdk/sessions/<sessionId>/permissions/<requestId>',
        _permissionResult,
      )
      ..delete('/v1/sdk/sessions/<sessionId>', _endSession)
      // Voice nexa.voice.v1 (backend handoff 1.0.0)
      ..post('/v1/sdk/voice/sessions', _createVoice)
      ..post('/v1/sdk/voice/sessions/<voiceId>/token', _refreshVoiceToken)
      ..get('/v1/sdk/voice/sessions/<voiceId>', _getVoice)
      ..delete('/v1/sdk/voice/sessions/<voiceId>', _deleteVoice)
      // DEV ONLY: simulate server-side ends (agent loss, tenant revoke).
      ..post('/v1/dev/voice/sessions/<voiceId>/end', _devEndVoice)
      ..post('/v1/dev/voice/fail-next-create', _devFailNextCreate);
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
  }) => Response(
    status,
    body: jsonEncode({
      'error': {
        'code': code,
        'message': message,
        'retryable': retryable,
        'retry_after_seconds': ?retryAfterSeconds,
        'quota_kind': ?quotaKind,
      },
    }),
    headers: {
      'content-type': 'application/json',
      if (retryAfterSeconds != null) 'retry-after': '$retryAfterSeconds',
    },
  );

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
    final requested = body['scopes'];
    final token = store.mintToken(
      appId,
      ttl: ttl is int ? Duration(seconds: ttl) : null,
      scopes: requested is List
          ? {for (final s in requested) '$s'}
          : const {'chat:session'},
    );
    return _json(201, {
      'token': token.token,
      'expires_at': token.expiresAt.toIso8601String(),
      'application_id': token.applicationId,
      'scopes': token.scopes.toList(),
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
    final tools = body['client_tools'];
    if (tools is List && granted.contains('toolCalling')) {
      for (final t in tools) {
        if (t is String) session.clientTools.add(t);
      }
    }
    final cid = body['conversation_id'];
    if (cid != null) {
      final conv = store.conversations[cid];
      if (conv == null || conv.applicationId != token.applicationId) {
        session.end('conversation_not_found');
        return _error(404, 'conversation_not_found', 'Unknown conversation.');
      }
      session.conversationId = conv.id;
      conv
        ..activeSession = session.id
        ..latestSession = session.id;
    }
    session.observer = (e) => _record(session, e);
    session.append('session_started', {
      'expires_at': session.expiresAt.toIso8601String(),
    });
    return _json(201, {
      'session_id': session.id,
      'expires_at': session.expiresAt.toIso8601String(),
      'granted_capabilities': granted,
      'last_sequence': 0,
      'conversation_id': session.conversationId,
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
    final uiEvent = body['ui_event'];
    if (uiEvent == null &&
        (text is! String || text.trim().isEmpty || text.length > 8000)) {
      return _error(422, 'validation_failed', 'text must be 1..8000 chars.');
    }
    Map<String, Object?>? uiDoc;
    if (uiEvent != null) {
      if (uiEvent is! Map ||
          uiEvent['ui_id'] is! String ||
          uiEvent['component_id'] is! String ||
          !const {
            'select',
            'confirm',
            'cancel',
            'submit',
            'change',
            'dismiss',
          }.contains(uiEvent['event'])) {
        return _error(422, 'validation_failed', 'Malformed ui_event.');
      }
      uiDoc = session.uiDocs[uiEvent['ui_id']];
      final node = uiDoc == null
          ? null
          : _findNode(uiDoc['root'], uiEvent['component_id']! as String);
      if (node == null) {
        return _error(
          422,
          'unknown_ui_component',
          'ui_event does not match a document this gateway sent.',
        );
      }
      final known = {
        for (final o in (node['options'] as List?) ?? const [])
          if (o is Map) o['id'],
      };
      final ids = (uiEvent['option_ids'] as List?) ?? const [];
      if (ids.any((id) => !known.contains(id))) {
        return _error(422, 'unknown_ui_option', 'Option id not in document.');
      }
    }
    final attachments = (body['attachments'] as List?) ?? const [];
    if (attachments.length > 4 ||
        attachments.any(
          (a) =>
              store.assets[a]?.conversationId != session.conversationId ||
              session.conversationId == null,
        )) {
      return _error(422, 'validation_failed', 'Unknown attachment.');
    }
    final fingerprint = jsonEncode([text, uiEvent, attachments]);
    final previous = session.idempotency[clientId];
    if (previous != null) {
      if (previous != fingerprint) {
        return _error(
          409,
          'idempotency_conflict',
          'Same Idempotency-Key with a different body.',
        );
      }
      return Response(202); // replay: acknowledged, nothing re-emitted
    }
    final lower = text is String ? text.toLowerCase() : '';
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
    session.idempotency[clientId] = fingerprint;
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
    for (final a in attachments) {
      store.assets[a]?.messageId = userMessageId;
    }
    _pendingUserText[userMessageId] = (
      text is String ? text : '',
      uiEvent is Map ? uiEvent.cast<String, Object?>() : null,
      [for (final a in attachments) '$a'],
    );
    session.append('user_message_accepted', {
      'message_id': userMessageId,
      'client_message_id': clientId,
    });
    unawaited(
      uiDoc != null
          ? _responder.respondToUiEvent(
              session,
              userMessageId: userMessageId,
              doc: uiDoc,
              event: (uiEvent! as Map).cast<String, Object?>(),
            )
          : _responder.respond(
              session,
              userMessageId: userMessageId,
              text: text! as String,
            ),
    );
    return Response(202);
  }

  static Map<String, Object?>? _findNode(Object? node, String id) {
    if (node is! Map) return null;
    if (node['id'] == id) return node.cast<String, Object?>();
    for (final key in const ['children', 'items']) {
      for (final c in (node[key] as List?) ?? const []) {
        final f = _findNode(c, id);
        if (f != null) return f;
      }
    }
    return null;
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

  // ------------------------------------------------------- labeeb.sdk/1

  /// Text/ui_event/attachments of accepted user messages (for history).
  final Map<String, (String, Map<String, Object?>?, List<String>)>
  _pendingUserText = {};

  /// Records chat messages into the session's server conversation.
  void _record(SessionState session, Map<String, Object?> e) {
    final conv = store.conversations[session.conversationId];
    if (conv == null) return;
    switch (e['type']) {
      case 'user_message_accepted':
        final id = e['message_id']! as String;
        final (text, ui, attachments) =
            _pendingUserText.remove(id) ?? ('', null, const <String>[]);
        conv.title ??= text.isEmpty ? null : text.characters60();
        conv.addMessage({
          'id': id,
          'role': 'user',
          'channel': 'chat',
          'status': 'accepted',
          'text': text,
          'parts': [
            if (text.isNotEmpty) {'type': 'text', 'text': text},
            if (ui != null) {'type': 'ui_event', ...ui},
            for (final a in attachments)
              if (store.assets[a] case final asset?)
                {
                  'type': asset.kind,
                  'asset_id': a,
                  'mime': asset.mime,
                  'filename': ?asset.filename,
                },
          ],
          'session_id': session.id,
        });
      case 'assistant_message_completed':
        final text = '${e['full_text'] ?? ''}';
        conv.addMessage({
          'id': e['message_id'],
          'role': 'assistant',
          'channel': 'chat',
          'status': 'completed',
          'text': text,
          'parts': [
            {'type': 'text', 'text': text},
          ],
          'finish_reason': e['finish_reason'],
          'session_id': session.id,
        });
    }
  }

  Future<Response> _contract(Request req) async {
    for (final path in const [
      '../../docs/contracts/labeeb-sdk-1/contract-1.0.0.json',
      'docs/contracts/labeeb-sdk-1/contract-1.0.0.json',
    ]) {
      final f = File(path);
      if (f.existsSync()) {
        return Response.ok(
          await f.readAsString(),
          headers: {'content-type': 'application/json'},
        );
      }
    }
    return _error(404, 'not_found', 'Contract snapshot not found.');
  }

  /// Mirrors production availability: search providers that are blocked
  /// there are unavailable (or fail) here too.
  Response _tools(Request req) {
    _authenticate(req);
    const unavailable = {
      'sports.matches': 'requires_configuration',
      'video.search': 'requires_configuration',
      'vision.analyze': 'no_model_selected',
      'ocr.extract': 'no_model_selected',
      'image.edit': 'no_model_selected',
    };
    const client = {
      'device.location.get_current',
      'device.camera.capture',
      'maps.open_directions',
      'browser.open_url',
      'device.network.get_status',
      'device.photo.pick',
      'device.file.pick',
      'device.share.content',
      'device.app.open_settings',
      'app.theme.apply',
      'app.theme.reset',
    };
    const server = {
      'places.search_nearby',
      'places.search_text',
      'vision.analyze',
      'image.generate',
      'image.edit',
      'ocr.extract',
      'file.read',
      'file.create',
      'web.search',
      'news.search',
      'sports.matches',
      'video.search',
      'app.theme.list_palettes',
      'jobs.status',
      'jobs.cancel',
    };
    return _json(200, {
      'enabled': true,
      'tools': [
        for (final t in [...client, ...server])
          {
            'name': t,
            'side': client.contains(t) ? 'client' : 'server',
            'available': !unavailable.containsKey(t),
            'unavailable_reason': unavailable[t],
          },
      ],
    });
  }

  ContractCall _call(SessionState session, String callId) {
    final c = session.contractCalls[callId];
    if (c == null) {
      throw _ApiError(_error(404, 'tool_call_not_found', 'Unknown tool call.'));
    }
    return c;
  }

  Response _getToolCall(Request req, String sessionId, String callId) {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final c = _call(session, callId);
    final ui = session.uiDocs.values
        .where((d) => '${d['id']}'.endsWith(c.id))
        .firstOrNull;
    final json = c.toJson();
    if (ui != null) {
      json['result'] = {...?c.result, 'ui': ui};
    }
    return _json(200, json);
  }

  Future<Response> _approveToolCall(
    Request req,
    String sessionId,
    String callId,
  ) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final c = _call(session, callId);
    final granted = (await _body(req))['granted'];
    if (granted is! bool) {
      return _error(422, 'validation_failed', 'granted must be a boolean.');
    }
    if (!c.open) return _error(409, 'tool_call_closed', 'Call is closed.');
    if (c.status != 'awaiting_approval') {
      return _error(409, 'not_awaiting_approval', 'Not awaiting approval.');
    }
    if (granted) {
      c.status = 'awaiting_client';
      c.approval.complete(true);
      session.append('tool_call_updated', c.toJson());
    } else {
      c.settle('denied');
      session.append('tool_call_failed', c.toJson());
    }
    return _json(200, c.toJson());
  }

  static const _requiredResult = {
    'device.location.get_current': ['latitude', 'longitude'],
    'device.camera.capture': ['asset_id'],
    'device.photo.pick': ['asset_id'],
    'device.file.pick': ['asset_id'],
    'maps.open_directions': ['opened'],
    'browser.open_url': ['opened'],
    'device.app.open_settings': ['opened'],
    'device.network.get_status': ['online'],
    'device.share.content': ['shared'],
    'app.theme.apply': ['status'],
    'app.theme.reset': ['status'],
  };

  Future<Response> _toolCallResult(
    Request req,
    String sessionId,
    String callId,
  ) async {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final c = _call(session, callId);
    if (c.side != 'client') {
      return _error(409, 'not_a_client_tool', 'Not a client tool.');
    }
    if (c.status != 'awaiting_client') {
      return _error(409, 'tool_call_closed', 'Call is not open.');
    }
    final body = await _body(req);
    final error = body['error'];
    final result = body['result'];
    if (error is Map && error['code'] is String) {
      c.settle('failed', error: error.cast<String, Object?>());
      session.append('tool_call_failed', c.toJson());
      return _json(200, c.toJson());
    }
    final required = _requiredResult[c.tool] ?? const <String>[];
    if (result is! Map || required.any((k) => !result.containsKey(k))) {
      return _error(
        422,
        'invalid_tool_result',
        'Result does not match the tool schema.',
      );
    }
    final assetId = result['asset_id'];
    if (assetId != null && !store.assets.containsKey(assetId)) {
      return _error(422, 'invalid_tool_result', 'Unknown asset_id.');
    }
    c.settle('succeeded', result: result.cast<String, Object?>());
    session.append('tool_call_completed', c.toJson());
    return _json(200, c.toJson());
  }

  Response _cancelToolCall(Request req, String sessionId, String callId) {
    final token = _authenticate(req);
    final session = _session(req, token, sessionId);
    final c = _call(session, callId);
    if (!c.open) return _error(409, 'tool_call_closed', 'Call is closed.');
    c.settle('cancelled', error: {'code': 'cancelled', 'retryable': false});
    session.append('tool_call_failed', c.toJson());
    return _json(200, c.toJson());
  }

  ConversationRecord _conversation(IssuedToken token, String cid) {
    final c = store.conversations[cid];
    if (c == null || c.applicationId != token.applicationId) {
      throw _ApiError(
        _error(404, 'conversation_not_found', 'Unknown conversation.'),
      );
    }
    return c;
  }

  Future<Response> _createConversation(Request req) async {
    final token = _authenticate(req);
    final body = await _body(req);
    final ref = body['client_ref'];
    if (ref is String) {
      final existing = store.conversations.values
          .where(
            (c) => c.applicationId == token.applicationId && c.clientRef == ref,
          )
          .firstOrNull;
      if (existing != null) return _json(200, existing.toJson());
    }
    final c = ConversationRecord(
      id: store.newId('conv'),
      applicationId: token.applicationId,
      kind: body['kind'] is String ? body['kind']! as String : 'chat',
      title: body['title'] as String?,
      titleSource: body['title'] is String ? 'user' : 'auto',
      clientRef: ref as String?,
      installation: req.headers['x-nexa-installation-id'],
    );
    store.conversations[c.id] = c;
    return _json(201, c.toJson());
  }

  Response _listConversations(Request req) {
    final token = _authenticate(req);
    final q = req.url.queryParameters;
    final limit = (int.tryParse(q['limit'] ?? '') ?? 20).clamp(1, 100);
    final all =
        store.conversations.values
            .where(
              (c) =>
                  c.applicationId == token.applicationId &&
                  (q['kind'] == null || c.kind == q['kind']) &&
                  (q['installation'] == null ||
                      c.installation == q['installation']),
            )
            .toList()
          ..sort(
            (a, b) => (b.lastMessageAt ?? b.updatedAt).compareTo(
              a.lastMessageAt ?? a.updatedAt,
            ),
          );
    final start = int.tryParse(q['cursor'] ?? '') ?? 0;
    final page = all.skip(start).take(limit).toList();
    final next = start + page.length;
    return _json(200, {
      'items': [for (final c in page) c.toJson()],
      'next_cursor': next < all.length ? '$next' : null,
    });
  }

  Response _getConversation(Request req, String cid) {
    final token = _authenticate(req);
    return _json(200, _conversation(token, cid).toJson(withSessions: true));
  }

  Future<Response> _renameConversation(Request req, String cid) async {
    final token = _authenticate(req);
    final c = _conversation(token, cid);
    final title = (await _body(req))['title'];
    if (title is! String || title.trim().isEmpty) {
      return _error(422, 'validation_failed', 'title is required.');
    }
    c
      ..title = title.trim()
      ..titleSource = 'user';
    return _json(200, c.toJson());
  }

  Map<String, int> _purge(Iterable<ConversationRecord> convs) {
    var messages = 0;
    var assets = 0;
    var events = 0;
    var calls = 0;
    var n = 0;
    for (final c in convs.toList()) {
      n++;
      messages += c.messages.length;
      final ids = store.assets.values
          .where((a) => a.conversationId == c.id)
          .map((a) => a.id)
          .toList();
      assets += ids.length;
      ids.forEach(store.assets.remove);
      for (final s in store.sessions.values.where(
        (s) => s.conversationId == c.id,
      )) {
        events += s.log.length;
        calls += s.contractCalls.length;
        s.end('conversation_deleted');
      }
      store.conversations.remove(c.id);
    }
    return {
      'conversations': n,
      'messages': messages,
      'events': events,
      'assets': assets,
      'tool_calls': calls,
    };
  }

  Response _deleteConversation(Request req, String cid) {
    final token = _authenticate(req);
    return _json(200, {
      'deleted': _purge([_conversation(token, cid)]),
    });
  }

  Response _clearConversations(Request req) {
    final token = _authenticate(req);
    final kind = req.url.queryParameters['kind'];
    return _json(200, {
      'deleted': _purge(
        store.conversations.values.where(
          (c) =>
              c.applicationId == token.applicationId &&
              (kind == null || c.kind == kind),
        ),
      ),
    });
  }

  Response _messages(Request req, String cid) {
    final token = _authenticate(req);
    final c = _conversation(token, cid);
    final q = req.url.queryParameters;
    final limit = (int.tryParse(q['limit'] ?? '') ?? 50).clamp(1, 200);
    final before = int.tryParse(q['before_seq'] ?? '');
    final older = c.messages
        .where((m) => before == null || (m['seq']! as int) < before)
        .toList();
    final page = older.length > limit
        ? older.sublist(older.length - limit)
        : older;
    return _json(200, {
      'items': page,
      'next_before': older.length > limit ? page.first['seq'] : null,
    });
  }

  Future<Response> _voiceTurns(Request req, String cid) async {
    final token = _authenticate(req);
    final c = _conversation(token, cid);
    final body = await _body(req);
    final turns = body['turns'];
    if (turns is! List) {
      return _error(422, 'validation_failed', 'turns is required.');
    }
    for (final t in turns) {
      if (t is! Map) continue;
      final id = t['client_turn_id'];
      if (c.messages.any((m) => m['client_turn_id'] == id)) continue;
      c.addMessage({
        'id': store.newId('msg'),
        'role': t['role'],
        'channel': 'voice',
        'status': 'completed',
        'text': t['text'],
        'parts': [
          {'type': 'text', 'text': t['text']},
        ],
        'client_turn_id': id,
      });
    }
    return _json(200, {'server_recorded': false});
  }

  static const _uploadTypes = {
    'image/png',
    'image/jpeg',
    'image/webp',
    'application/pdf',
    'text/plain',
    'text/markdown',
    'text/csv',
    'application/json',
  };

  static bool _magicOk(String mime, List<int> b) => switch (mime) {
    'image/png' => b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E,
    'image/jpeg' => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8,
    'image/webp' =>
      b.length > 12 && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP',
    'application/pdf' =>
      b.length > 4 && String.fromCharCodes(b.sublist(0, 4)) == '%PDF',
    _ => true,
  };

  Future<Response> _uploadAsset(Request req, String cid) async {
    final token = _authenticate(req);
    final c = _conversation(token, cid);
    final mime = (req.headers['content-type'] ?? '').split(';').first.trim();
    final bytes = await req.read().expand((chunk) => chunk).toList();
    if (!_uploadTypes.contains(mime) || !_magicOk(mime, bytes)) {
      return _error(
        415,
        'unsupported_media_type',
        'Content type not allowed or not matching the bytes.',
      );
    }
    if (bytes.length > 10 * 1024 * 1024) {
      return _error(
        413,
        'asset_too_large',
        'Attachments are limited to 10 MB.',
      );
    }
    if (store.assets.values.where((a) => a.conversationId == c.id).length >=
        50) {
      return _error(409, 'asset_limit_reached', '50 assets per conversation.');
    }
    final a = AssetRecord(
      id: store.newId('ast'),
      applicationId: token.applicationId,
      conversationId: c.id,
      mime: mime,
      bytes: bytes,
      origin: 'user',
      filename: req.headers['x-nexa-filename'],
    );
    store.assets[a.id] = a;
    return _json(201, a.toJson());
  }

  AssetRecord _asset(IssuedToken token, String id) {
    final a = store.assets[id];
    if (a == null || a.applicationId != token.applicationId) {
      throw _ApiError(_error(404, 'asset_not_found', 'Unknown asset.'));
    }
    return a;
  }

  Response _getAsset(Request req, String assetId) =>
      _json(200, _asset(_authenticate(req), assetId).toJson());

  Response _assetContent(Request req, String assetId) {
    final a = _asset(_authenticate(req), assetId);
    return Response.ok(
      a.bytes,
      headers: {
        'content-type': a.mime,
        'cache-control': 'private, no-store',
        'x-content-type-options': 'nosniff',
      },
    );
  }

  Response _deleteAsset(Request req, String assetId) {
    final a = _asset(_authenticate(req), assetId);
    store.assets.remove(a.id);
    return Response(204);
  }

  Response _getPreferences(Request req) {
    final token = _authenticate(req);
    return _json(200, {
      'preferences': store.preferences[token.applicationId] ?? const {},
    });
  }

  Future<Response> _putPreferences(Request req) async {
    final token = _authenticate(req);
    final p = (await _body(req))['preferences'];
    final keyRe = RegExp(r'^[a-z][a-z0-9_.]{0,39}$');
    if (p is! Map ||
        p.length > 30 ||
        p.entries.any(
          (e) =>
              e.key is! String ||
              !keyRe.hasMatch(e.key as String) ||
              !(e.value is String || e.value is num || e.value is bool) ||
              (e.value is String && (e.value as String).length > 200),
        )) {
      return _error(422, 'validation_failed', 'Invalid preferences.');
    }
    store.preferences[token.applicationId] = p.cast<String, Object?>();
    return _json(200, {'preferences': p});
  }

  Response _deletePreferences(Request req) {
    final token = _authenticate(req);
    store.preferences.remove(token.applicationId);
    return Response(204);
  }

  Response _deleteAssistantData(Request req) {
    final token = _authenticate(req);
    final deleted = _purge(
      store.conversations.values.where(
        (c) => c.applicationId == token.applicationId,
      ),
    );
    store.preferences.remove(token.applicationId);
    return _json(200, {'deleted': deleted});
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
    session.end('user_ended');
    return Response(204);
  }

  // ----------------------------------------------------------------- voice

  /// Voice calls need scope `voice:session` (not a default scope).
  IssuedToken _authenticateVoice(Request req) {
    final token = _authenticate(req);
    if (!token.scopes.contains('voice:session')) {
      throw _ApiError(
        _error(403, 'forbidden', 'Token lacks scope voice:session.'),
      );
    }
    return token;
  }

  VoiceSessionState _voiceSession(IssuedToken token, String id) {
    final v = voice.sessions[id];
    // Another tenant's/user's id answers exactly like an unknown one.
    if (v == null || v.subject != token.token) {
      throw _ApiError(
        _error(404, 'voice_session_not_found', 'Voice session not found.'),
      );
    }
    return v;
  }

  Future<Response> _createVoice(Request req) async {
    final token = _authenticateVoice(req);
    final body = await _body(req);
    final lang = body['language_tag'];
    if (lang is! String || !const {'en', 'ar'}.contains(lang)) {
      return _error(422, 'validation_failed', 'language_tag must be en or ar.');
    }
    final chatId = body['chat_session_id'];
    if (chatId != null) {
      final chat = store.sessions[chatId];
      if (chat == null || chat.applicationId != token.applicationId) {
        return _error(404, 'session_not_found', 'Chat session not found.');
      }
    }
    final lk = voice.livekit;
    if (lk == null) {
      return _error(
        403,
        'capability_not_granted',
        'Voice is not enabled for this application.',
        quotaKind: 'liveVoice',
      );
    }
    if (voice.failNextCreate || !await lk.isReachable()) {
      voice.failNextCreate = false;
      return _error(
        503,
        'voice_unavailable',
        'No voice capacity is available right now. Try again shortly.',
        retryable: true,
        retryAfterSeconds: 5,
      );
    }
    if (voice.secondsLeft(token.applicationId) <= 0) {
      return _error(
        402,
        'quota_exceeded',
        'Voice quota exhausted.',
        quotaKind: 'voice_seconds',
      );
    }
    if (voice.liveFor(token.token) != null) {
      return _error(
        409,
        'voice_session_active',
        'A voice session is already active for this user.',
      );
    }
    final scenario = body['scenario'];
    final grant = await voice.create(
      applicationId: token.applicationId,
      subject: token.token,
      languageTag: lang,
      scenario: scenario is String ? scenario : '',
    );
    return _json(201, grant);
  }

  Future<Response> _refreshVoiceToken(Request req, String voiceId) async {
    final token = _authenticateVoice(req);
    final v = _voiceSession(token, voiceId);
    if (v.status == 'ended') {
      return _error(
        410,
        'voice_session_ended',
        'Voice session ended (${v.endReason}).',
      );
    }
    if (v.refreshes >= voice.options.maxRefreshes) {
      return _error(429, 'rate_limited', 'Too many token refreshes.');
    }
    return _json(200, voice.refresh(v));
  }

  Response _getVoice(Request req, String voiceId) {
    final token = _authenticateVoice(req);
    return _json(200, _voiceSession(token, voiceId).statusJson());
  }

  Future<Response> _deleteVoice(Request req, String voiceId) async {
    final token = _authenticateVoice(req);
    final v = _voiceSession(token, voiceId);
    await voice.end(v, 'user_ended');
    return _json(200, v.statusJson());
  }

  /// DEV ONLY: `{"reason": "agent_lost" | "revoked" | ...}`.
  Future<Response> _devEndVoice(Request req, String voiceId) async {
    final v = voice.sessions[voiceId];
    if (v == null) return _error(404, 'voice_session_not_found', 'unknown');
    final body = await _body(req);
    final reason = (body['reason'] as String?) ?? 'revoked';
    await voice.end(
      v,
      reason,
      agentState: reason == 'agent_lost' ? 'unavailable' : 'ended',
    );
    return _json(200, v.statusJson());
  }

  Response _devFailNextCreate(Request req) {
    voice.failNextCreate = true;
    return Response(204);
  }
}

final class _ApiError implements Exception {
  _ApiError(this.response);
  final Response response;
}

extension on String {
  /// A short auto title from the first message.
  String characters60() => length <= 60 ? this : '${substring(0, 57)}...';
}
