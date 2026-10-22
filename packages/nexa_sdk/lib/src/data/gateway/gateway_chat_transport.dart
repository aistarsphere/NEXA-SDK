import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/gateway/gateway_dtos.dart';
import 'package:nexa_sdk/src/data/gateway/nexa_gateway_api.dart';
import 'package:nexa_sdk/src/data/gateway/sse_decoder.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';
import 'package:nexa_sdk/src/version.dart';

/// [ChatTransport] over the NEXA gateway HTTP contract
/// (`docs/contracts/nexa-gateway-api.proposed.yaml`, v0.2.0-proposed).
///
/// STATUS: contract **proposed**; implementation **validated against the
/// local reference gateway only** (`tools/nexa_reference_gateway`), over real
/// HTTP sockets for both delivery modes. No production gateway exists yet, so
/// this must not be described as integrated with a live backend.
///
/// Event delivery ([NexaConfig.eventDelivery]):
/// * Server-Sent Events: one `GET /events/stream?after=` response per
///   subscription, decoded by [decodeSse].
/// * Long-polling: repeated `GET /events?after&wait_ms` requests.
///
/// Reconnect policy lives in `ChatBloc`, not here: a subscription makes a
/// single attempt and ends with a `NexaException` on failure, or ends with an
/// interruption error if the stream closes before `session_ended`. The bloc
/// resubscribes from the last applied sequence with back-off.
final class GatewayChatTransport implements ChatTransport {
  GatewayChatTransport({
    required NexaGatewayApi api,
    required Dio dio,
    required NexaConfig config,
    required NexaLogger logger,
    this.longPollWait = const Duration(seconds: 25),
  }) : _api = api,
       _dio = dio,
       _config = config,
       _logger = logger;

  final NexaGatewayApi _api;
  final Dio _dio;
  final NexaConfig _config;
  final NexaLogger _logger;

  /// How long the server may hold a long-poll request.
  final Duration longPollWait;

  final Map<StreamController<ConversationEvent>, CancelToken> _open = {};
  bool _disposed = false;

  @override
  Future<SessionHandle> startSession({
    required SessionCredential credential,
    required Set<NexaCapability> requestedCapabilities,
    required String languageTag,
    Map<String, String> clientMetadata = const {},
  }) async {
    _checkDisposed();
    try {
      final dto = await _api.createSession(
        CreateSessionRequestDto(
          applicationId: _config.applicationId,
          requestedCapabilities: requestedCapabilities
              .map((c) => c.name)
              .toList(),
          languageTag: languageTag,
          clientMetadata: clientMetadata,
          sdkVersion: nexaSdkVersion,
          platform: _platformName(),
        ),
      );
      return SessionHandle(
        sessionId: SessionId(dto.sessionId),
        expiresAt: dto.expiresAt,
        grantedCapabilities: dto.grantedCapabilities
            .map(_capabilityFromWire)
            .whereType<NexaCapability>()
            .toSet(),
        lastSequence: dto.lastSequence,
      );
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<ConversationEvent> events(
    SessionId sessionId, {
    int afterSequence = 0,
  }) {
    _checkDisposed();
    final cancel = CancelToken();
    late final StreamController<ConversationEvent> controller;
    controller = StreamController<ConversationEvent>(
      onListen: () {
        final run = switch (_config.eventDelivery) {
          NexaEventDelivery.serverSentEvents => _sseLoop,
          NexaEventDelivery.longPolling => _pollLoop,
        };
        unawaited(run(sessionId, afterSequence, controller, cancel));
      },
      onCancel: () {
        cancel.cancel('subscription cancelled');
        _open.remove(controller);
      },
    );
    _open[controller] = cancel;
    return controller.stream;
  }

  Future<void> _sseLoop(
    SessionId sessionId,
    int after,
    StreamController<ConversationEvent> out,
    CancelToken cancel,
  ) async {
    var sawEnd = false;
    try {
      final response = await _dio.get<ResponseBody>(
        '/v1/sdk/sessions/${sessionId.value}/events/stream',
        queryParameters: {'after': after},
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero, // long-lived response
          headers: const {'Accept': 'text/event-stream'},
        ),
      );
      final body = response.data;
      if (body == null) throw const TransportException('Empty event stream.');
      await for (final message in decodeSse(body.stream)) {
        if (cancel.isCancelled) break;
        final event = _parse(message.data);
        if (event == null) continue;
        if (!out.isClosed) out.add(event);
        if (event is SessionEndedEvent) {
          sawEnd = true;
          break;
        }
      }
    } on Object catch (e) {
      await _fail(out, e, cancel);
      return;
    }
    if (!sawEnd && !cancel.isCancelled && !out.isClosed) {
      // The server closed the stream without ending the session: treat as a
      // transient interruption so the bloc reconnects from its cursor.
      out.addError(
        const TransportException('Event stream interrupted.', retryable: true),
      );
    }
    if (!out.isClosed) await out.close();
  }

  Future<void> _pollLoop(
    SessionId sessionId,
    int after,
    StreamController<ConversationEvent> out,
    CancelToken cancel,
  ) async {
    var cursor = after;
    try {
      while (!cancel.isCancelled && !_disposed) {
        final page = await _api.pollEvents(
          sessionId.value,
          cursor,
          longPollWait.inMilliseconds,
        );
        for (final raw in page.events) {
          final event = _parse(raw);
          if (event != null && !out.isClosed) out.add(event);
        }
        if (page.cursor > cursor) cursor = page.cursor;
        if (page.done) break;
        if (page.events.isEmpty && longPollWait == Duration.zero) {
          await Future<void>.delayed(_config.eventPollInterval);
        }
      }
    } on Object catch (e) {
      await _fail(out, e, cancel);
      return;
    }
    if (!out.isClosed) await out.close();
  }

  Future<void> _fail(
    StreamController<ConversationEvent> out,
    Object error,
    CancelToken cancel,
  ) async {
    if (out.isClosed) return;
    if (!cancel.isCancelled) {
      final mapped = mapError(await _materialize(error));
      if (mapped is! CancelledException) {
        _logger.log(
          NexaLogLevel.warning,
          'Event subscription failed (${mapped.code.name}).',
        );
        out.addError(mapped);
      }
    }
    await out.close();
  }

  /// Parses one wire event. Unknown or invalid events that still carry the
  /// common envelope become [UnsupportedEvent] so the sequence cursor keeps
  /// moving (the reducer ignores them); anything worse is logged and dropped.
  ConversationEvent? _parse(Object raw) {
    Object? decoded;
    try {
      decoded = raw is String ? jsonDecode(raw) : raw;
    } on FormatException catch (e) {
      _logger.log(NexaLogLevel.warning, 'Dropped unparseable event: $e');
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      _logger.log(NexaLogLevel.warning, 'Dropped non-object event.');
      return null;
    }
    final event = ConversationEvent.tryParse(decoded);
    if (event == null) {
      _logger.log(NexaLogLevel.warning, 'Dropped event without envelope.');
    } else if (event is UnsupportedEvent) {
      _logger.log(
        NexaLogLevel.warning,
        'Unsupported event "${event.originalType}" at ${event.sequence}: '
        '${event.reason}',
      );
    }
    return event;
  }

  /// Error responses to a streaming request arrive with a `ResponseBody`
  /// instead of decoded JSON; read it so the error mapper sees the envelope.
  Future<Object> _materialize(Object error) async {
    if (error is DioException && error.response?.data is ResponseBody) {
      try {
        final bytes = await (error.response!.data as ResponseBody).stream
            .fold<List<int>>([], (acc, chunk) => acc..addAll(chunk));
        error.response!.data = jsonDecode(utf8.decode(bytes));
      } on Object {
        error.response!.data = null;
      }
    }
    return error;
  }

  @override
  Future<void> sendMessage(SessionId sessionId, OutgoingMessage message) =>
      _guard(
        () => _api.postMessage(
          sessionId.value,
          MessageRequestDto(
            clientMessageId: message.clientMessageId.value,
            text: message.text,
            languageTag: message.languageTag,
          ),
          message.clientMessageId.value,
        ),
      );

  @override
  Future<void> submitToolAction(SessionId sessionId, ToolAction action) =>
      _guard(() => _api.postToolAction(sessionId.value, action.toJson()));

  @override
  Future<void> reportPermissionResult(
    SessionId sessionId, {
    required String requestId,
    required bool granted,
  }) => _guard(
    () => _api.reportPermission(
      sessionId.value,
      requestId,
      PermissionResultDto(granted: granted),
    ),
  );

  @override
  Future<void> cancelMessage(SessionId sessionId, MessageId messageId) =>
      _guard(() => _api.cancelMessage(sessionId.value, messageId.value));

  @override
  Future<void> endSession(SessionId sessionId) =>
      _guard(() => _api.endSession(sessionId.value));

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final entry in _open.entries.toList()) {
      entry.value.cancel('transport disposed');
      await entry.key.close();
    }
    _open.clear();
  }

  Future<void> _guard(Future<void> Function() call) async {
    _checkDisposed();
    try {
      await call();
    } on Object catch (e) {
      throw mapError(e);
    }
  }

  void _checkDisposed() {
    if (_disposed) throw const NotInitializedException('Transport disposed.');
  }

  static NexaCapability? _capabilityFromWire(String name) {
    for (final c in NexaCapability.values) {
      if (c.name == name) return c;
    }
    return null;
  }

  static String _platformName() {
    try {
      return Platform.operatingSystem;
    } on Object {
      return 'unknown';
    }
  }
}
