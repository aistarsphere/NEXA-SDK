import 'dart:async';

import 'package:clock/clock.dart';
import 'package:nexa_core/src/auth/session_credential.dart';
import 'package:nexa_core/src/config/nexa_capability.dart';
import 'package:nexa_core/src/conversation/conversation_event.dart';
import 'package:nexa_core/src/errors/nexa_exception.dart';
import 'package:nexa_core/src/ids/ids.dart';
import 'package:nexa_core/src/session/session_handle.dart';
import 'package:nexa_core/src/tools/tool_action.dart';
import 'package:nexa_core/src/tools/tool_call.dart';
import 'package:nexa_core/src/tools/tool_result.dart';
import 'package:nexa_core/src/transport/chat_transport.dart';

/// **MOCK ADAPTER - NOT A BACKEND.**
///
/// Deterministic, in-memory [ChatTransport] used for widget tests, SDK
/// embedding tests and the example app while no NEXA gateway exists. It
/// scripts replies from keywords in the user's text so every event type and
/// tool result can be exercised without a server:
///
/// | keyword in message            | scenario                                   |
/// |-------------------------------|--------------------------------------------|
/// | `restaurant`                  | tool call -> restaurants result            |
/// | `weather`                     | tool call -> weather result                |
/// | `route`, `map`, `directions`  | tool call -> map route result              |
/// | `book`, `confirm`             | tool call requiring explicit confirmation  |
/// | `form`                        | form result                                |
/// | `choose`, `select`            | selection result                           |
/// | `video`, `media`              | media result                               |
/// | `card`                        | rich card result                           |
/// | `error`                       | assistant message fails                    |
/// | `quota`                       | quota exceeded + session ended             |
/// | `permission`, `mic`           | microphone permission request              |
/// | `slow`                        | reply with long delays (cancel testing)    |
/// | `reorder`                     | deltas emitted out of order + a duplicate  |
/// | `invalid`                     | malformed tool payload (validator path)    |
/// | anything else                 | canned streamed reply in `en` or `ar`      |
///
/// Delays are injectable so tests can run with `Duration.zero`.
final class MockChatTransport implements ChatTransport {
  MockChatTransport({
    this.tokenDelay = const Duration(milliseconds: 40),
    this.thinkDelay = const Duration(milliseconds: 400),
    this.grantedCapabilities = const {
      NexaCapability.textChat,
      NexaCapability.toolCalling,
      NexaCapability.richResults,
    },
  });

  /// Delay between streamed text deltas.
  final Duration tokenDelay;

  /// Delay before the assistant starts replying.
  final Duration thinkDelay;

  /// Capabilities this mock "grants" regardless of the request.
  final Set<NexaCapability> grantedCapabilities;

  final Map<SessionId, _MockSession> _sessions = {};
  int _sessionCounter = 0;
  bool _disposed = false;

  /// Messages received, for assertions.
  final List<OutgoingMessage> sentMessages = [];

  /// Tool actions received, for assertions.
  final List<ToolAction> receivedActions = [];

  @override
  Future<SessionHandle> startSession({
    required SessionCredential credential,
    required Set<NexaCapability> requestedCapabilities,
    required String languageTag,
    Map<String, String> clientMetadata = const {},
  }) async {
    _checkDisposed();
    if (credential.isExpired) {
      throw const SessionExpiredException('Mock: credential expired.');
    }
    if (credential.token.contains('invalid')) {
      throw const AuthenticationException('Mock: credential rejected.');
    }
    final id = SessionId('mock-session-${++_sessionCounter}');
    final session = _MockSession(id, languageTag, this);
    _sessions[id] = session;
    session.emit(
      (seq, eventId, at) => ConversationEvent.sessionStarted(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        expiresAt: at.add(const Duration(hours: 1)),
      ),
    );
    return SessionHandle(
      sessionId: id,
      expiresAt: clock.now().add(const Duration(hours: 1)),
      grantedCapabilities: requestedCapabilities.intersection(
        grantedCapabilities,
      ),
    );
  }

  @override
  Stream<ConversationEvent> events(
    SessionId sessionId, {
    int afterSequence = 0,
  }) {
    final session = _session(sessionId);
    StreamSubscription<ConversationEvent>? live;
    late final StreamController<ConversationEvent> out;
    out = StreamController<ConversationEvent>(
      onListen: () {
        // Subscribe to live events *before* replaying so nothing emitted
        // between the snapshot and the subscription is lost.
        live = session.controller.stream.listen(out.add, onDone: out.close);
        for (final e in session.log.where((e) => e.sequence > afterSequence)) {
          out.add(e);
        }
        if (session.controller.isClosed) unawaited(out.close());
      },
      onCancel: () => live?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<void> sendMessage(SessionId sessionId, OutgoingMessage message) async {
    final session = _session(sessionId);
    if (session.ended) {
      throw const SessionExpiredException('Mock: session already ended.');
    }
    sentMessages.add(message);
    // Idempotency: a retry with the same clientMessageId is acknowledged
    // again but does not start a second reply.
    final isRetry = session.acceptedClientIds.contains(message.clientMessageId);
    final messageId = MessageId('mock-user-${session.nextMessageNumber()}');
    session.acceptedClientIds.add(message.clientMessageId);
    session.emit(
      (seq, eventId, at) => ConversationEvent.userMessageAccepted(
        eventId: eventId,
        sessionId: sessionId,
        sequence: seq,
        occurredAt: at,
        messageId: messageId,
        clientMessageId: message.clientMessageId,
      ),
    );
    if (isRetry) return;
    unawaited(session.reply(message, inReplyTo: messageId));
  }

  @override
  Future<void> submitToolAction(SessionId sessionId, ToolAction action) async {
    final session = _session(sessionId);
    receivedActions.add(action);
    await session.handleAction(action);
  }

  @override
  Future<void> reportPermissionResult(
    SessionId sessionId, {
    required String requestId,
    required bool granted,
  }) async {
    _session(sessionId).permissionResults[requestId] = granted;
  }

  @override
  Future<void> cancelMessage(SessionId sessionId, MessageId messageId) async {
    final session = _session(sessionId);
    session.cancelRequested.add(messageId);
  }

  @override
  Future<void> endSession(SessionId sessionId) async {
    final session = _sessions[sessionId];
    if (session == null || session.ended) return;
    session.end(SessionEndReason.userEnded);
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final s in _sessions.values) {
      if (!s.ended) s.end(SessionEndReason.serverEnded);
    }
    _sessions.clear();
  }

  _MockSession _session(SessionId id) {
    _checkDisposed();
    final session = _sessions[id];
    if (session == null) {
      throw ServerException(
        statusCode: 404,
        message: 'Mock: unknown session $id',
        serverCode: 'session_not_found',
      );
    }
    return session;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const NotInitializedException('Mock transport disposed.');
    }
  }
}

typedef _EventBuilder =
    ConversationEvent Function(int seq, EventId eventId, DateTime at);

final class _MockSession {
  _MockSession(this.id, this.languageTag, this.transport);

  final SessionId id;
  final String languageTag;
  final MockChatTransport transport;
  final StreamController<ConversationEvent> controller =
      StreamController<ConversationEvent>.broadcast();
  final List<ConversationEvent> log = [];
  final Set<ClientMessageId> acceptedClientIds = {};
  final Set<MessageId> cancelRequested = {};
  final Map<String, bool> permissionResults = {};
  final Map<ToolCallId, Future<void> Function(ToolAction)> pendingActions = {};

  int _seq = 0;
  int _events = 0;
  int _messages = 0;
  bool ended = false;

  bool get _ar => languageTag == 'ar';

  int nextMessageNumber() => ++_messages;

  ConversationEvent emit(_EventBuilder build) {
    final event = build(
      ++_seq,
      EventId('${id.value}-evt-${++_events}'),
      clock.now(),
    );
    log.add(event);
    if (!controller.isClosed) controller.add(event);
    return event;
  }

  /// Emits a raw event without touching the sequence counter (for reorder and
  /// duplicate scenarios).
  void emitRaw(ConversationEvent event) {
    if (!controller.isClosed) controller.add(event);
  }

  void end(SessionEndReason reason) {
    if (ended) return;
    ended = true;
    emit(
      (seq, eventId, at) => ConversationEvent.sessionEnded(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        reason: reason,
      ),
    );
    unawaited(controller.close());
  }

  Future<void> _wait(Duration d) =>
      d == Duration.zero ? Future<void>.value() : Future<void>.delayed(d);

  Future<void> reply(
    OutgoingMessage message, {
    required MessageId inReplyTo,
  }) async {
    final text = message.text.toLowerCase();
    final assistantId = MessageId('mock-assistant-${nextMessageNumber()}');
    final slow = text.contains('slow');
    final tokenDelay = slow ? transport.tokenDelay * 8 : transport.tokenDelay;

    if (text.contains('quota')) {
      emit(
        (seq, eventId, at) => ConversationEvent.quotaUpdated(
          eventId: eventId,
          sessionId: id,
          sequence: seq,
          occurredAt: at,
          quota: const QuotaInfo(kind: 'messages', remaining: 0, limit: 100),
          exceeded: true,
        ),
      );
      end(SessionEndReason.quotaExceeded);
      return;
    }

    await _wait(transport.thinkDelay);
    if (ended) return;

    if (text.contains('permission') || text.contains('mic')) {
      emit(
        (seq, eventId, at) => ConversationEvent.permissionRequested(
          eventId: eventId,
          sessionId: id,
          sequence: seq,
          occurredAt: at,
          requestId: 'perm-${_events + 1}',
          permission: NexaPermission.microphone,
          reason: _ar
              ? 'نحتاج إلى الميكروفون للمحادثة الصوتية.'
              : 'The microphone is needed for voice conversation.',
        ),
      );
    }

    _started(assistantId, inReplyTo);

    if (text.contains('error')) {
      await _stream(
        assistantId,
        _ar ? 'لحظة من فضلك' : 'One moment',
        tokenDelay,
      );
      emit(
        (seq, eventId, at) => ConversationEvent.messageFailed(
          eventId: eventId,
          sessionId: id,
          sequence: seq,
          occurredAt: at,
          messageId: assistantId,
          error: const EventError(
            code: 'inference_failed',
            message: 'Mock inference failure.',
            retryable: true,
          ),
        ),
      );
      return;
    }

    if (text.contains('reorder')) {
      await _reorderScenario(assistantId);
      return;
    }

    final tool = _toolScenario(text);
    if (tool != null) {
      await _runTool(assistantId, tool, tokenDelay);
      return;
    }

    final reply = _cannedReply(message.text);
    final cancelled = await _stream(assistantId, reply, tokenDelay);
    if (!cancelled) _complete(assistantId, FinishReason.stop, fullText: reply);
  }

  void _started(MessageId assistantId, MessageId inReplyTo) {
    emit(
      (seq, eventId, at) => ConversationEvent.assistantMessageStarted(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        messageId: assistantId,
        inReplyTo: inReplyTo,
      ),
    );
  }

  void _complete(
    MessageId assistantId,
    FinishReason reason, {
    String? fullText,
  }) {
    emit(
      (seq, eventId, at) => ConversationEvent.assistantMessageCompleted(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        messageId: assistantId,
        finishReason: reason,
        fullText: fullText,
      ),
    );
  }

  /// Streams [reply] word by word. Returns true if cancelled midway.
  Future<bool> _stream(
    MessageId assistantId,
    String reply,
    Duration delay,
  ) async {
    final words = reply.split(' ');
    for (var i = 0; i < words.length; i++) {
      if (ended) return true;
      if (cancelRequested.contains(assistantId)) {
        emit(
          (seq, eventId, at) => ConversationEvent.messageCancelled(
            eventId: eventId,
            sessionId: id,
            sequence: seq,
            occurredAt: at,
            messageId: assistantId,
          ),
        );
        return true;
      }
      final chunk = i == 0 ? words[i] : ' ${words[i]}';
      emit(
        (seq, eventId, at) => ConversationEvent.assistantTextDelta(
          eventId: eventId,
          sessionId: id,
          sequence: seq,
          occurredAt: at,
          messageId: assistantId,
          deltaIndex: i,
          text: chunk,
        ),
      );
      await _wait(delay);
    }
    return false;
  }

  Future<void> _reorderScenario(MessageId assistantId) async {
    // Build three deltas, emit 0, then 2 before 1, then a duplicate of 0.
    final d0 = emit(
      (seq, eventId, at) => ConversationEvent.assistantTextDelta(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        messageId: assistantId,
        deltaIndex: 0,
        text: 'Order',
      ),
    );
    final seq1 = ++_seq;
    final seq2 = ++_seq;
    final d1 = ConversationEvent.assistantTextDelta(
      eventId: EventId('${id.value}-evt-${++_events}'),
      sessionId: id,
      sequence: seq1,
      occurredAt: clock.now(),
      messageId: assistantId,
      deltaIndex: 1,
      text: ' is',
    );
    final d2 = ConversationEvent.assistantTextDelta(
      eventId: EventId('${id.value}-evt-${++_events}'),
      sessionId: id,
      sequence: seq2,
      occurredAt: clock.now(),
      messageId: assistantId,
      deltaIndex: 2,
      text: ' preserved.',
    );
    log
      ..add(d1)
      ..add(d2);
    emitRaw(d2);
    await _wait(transport.tokenDelay);
    emitRaw(d1);
    await _wait(transport.tokenDelay);
    emitRaw(d0); // duplicate
    await _wait(transport.tokenDelay);
    _complete(assistantId, FinishReason.stop, fullText: 'Order is preserved.');
  }

  _ToolScenario? _toolScenario(String text) {
    if (text.contains('invalid')) {
      return _ToolScenario(
        'restaurants.search',
        _ar ? 'نتيجة غير صالحة' : 'Invalid result',
        rawResult: {'kind': 'restaurants', 'items': 'not-a-list'},
      );
    }
    if (text.contains('restaurant')) {
      return _ToolScenario(
        'restaurants.search',
        _ar ? 'البحث عن مطاعم قريبة' : 'Searching nearby restaurants',
        result: ToolResult.restaurants(
          query: 'nearby',
          items: [
            RestaurantResult(
              id: 'r1',
              name: _ar ? 'مطعم الضيافة' : 'Mocha House',
              cuisine: _ar ? 'عراقي' : 'Cafe',
              rating: 4.6,
              priceTier: 2,
              distanceMeters: 450,
              openNow: true,
            ),
            RestaurantResult(
              id: 'r2',
              name: _ar ? 'بيت الكباب' : 'Grill Corner',
              cuisine: _ar ? 'مشاوي' : 'Grill',
              rating: 4.2,
              priceTier: 3,
              distanceMeters: 1200,
            ),
          ],
        ),
      );
    }
    if (text.contains('weather')) {
      return _ToolScenario(
        'weather.current',
        _ar ? 'جلب حالة الطقس' : 'Fetching weather',
        result: ToolResult.weather(
          weather: WeatherData(
            locationName: _ar ? 'بغداد' : 'Baghdad',
            temperatureC: 31,
            condition: _ar ? 'صافٍ' : 'Clear',
            iconKey: 'clear',
            humidityPercent: 22,
            windKph: 14,
            forecast: [
              DailyForecast(
                date: clock.now().add(const Duration(days: 1)),
                highC: 33,
                lowC: 19,
                condition: _ar ? 'صافٍ' : 'Clear',
                iconKey: 'clear',
              ),
              DailyForecast(
                date: clock.now().add(const Duration(days: 2)),
                highC: 29,
                lowC: 18,
                condition: _ar ? 'غائم جزئياً' : 'Partly cloudy',
                iconKey: 'cloudy',
              ),
            ],
          ),
        ),
      );
    }
    if (text.contains('route') ||
        text.contains('map') ||
        text.contains('directions')) {
      return _ToolScenario(
        'maps.route',
        _ar ? 'حساب المسار' : 'Calculating route',
        result: ToolResult.mapRoute(
          route: MapRoute(
            origin: const GeoPoint(latitude: 33.3152, longitude: 44.3661),
            destination: const GeoPoint(latitude: 33.3406, longitude: 44.4009),
            originLabel: _ar ? 'موقعك' : 'Your location',
            destinationLabel: _ar ? 'المنصور' : 'Al-Mansour',
            distanceMeters: 5200,
            duration: const Duration(minutes: 14),
          ),
        ),
      );
    }
    if (text.contains('book') || text.contains('confirm')) {
      return _ToolScenario(
        'bookings.create',
        _ar ? 'إنشاء حجز' : 'Creating a booking',
        requiresConfirmation: true,
        confirmation: ConfirmationSpec(
          id: 'c1',
          title: _ar ? 'تأكيد الحجز' : 'Confirm booking',
          description: _ar
              ? 'سيتم حجز طاولة لشخصين الساعة 8 مساءً.'
              : 'A table for two will be booked at 8:00 PM.',
          confirmLabel: _ar ? 'تأكيد' : 'Confirm',
          declineLabel: _ar ? 'إلغاء' : 'Cancel',
          severity: ConfirmationSeverity.medium,
          details: [_ar ? 'مطعم الضيافة' : 'Mocha House', '8:00 PM', '2'],
        ),
        result: ToolResult.text(
          text: _ar ? 'تم الحجز بنجاح.' : 'Your booking is confirmed.',
        ),
      );
    }
    if (text.contains('form')) {
      return _ToolScenario(
        'forms.collect',
        _ar ? 'نموذج' : 'Form',
        result: ToolResult.form(
          form: FormSpec(
            id: 'f1',
            title: _ar ? 'بيانات التواصل' : 'Contact details',
            submitLabel: _ar ? 'إرسال' : 'Submit',
            fields: [
              FormFieldSpec(
                id: 'name',
                label: _ar ? 'الاسم' : 'Name',
                type: FormFieldType.text,
                required: true,
              ),
              FormFieldSpec(
                id: 'phone',
                label: _ar ? 'الهاتف' : 'Phone',
                type: FormFieldType.phone,
              ),
            ],
          ),
        ),
      );
    }
    if (text.contains('choose') || text.contains('select')) {
      return _ToolScenario(
        'selection.ask',
        _ar ? 'اختيار' : 'Selection',
        result: ToolResult.selection(
          selection: SelectionSpec(
            id: 's1',
            prompt: _ar ? 'اختر وقتاً' : 'Pick a time',
            options: const [
              SelectionOption(id: 't1', label: '6:00 PM'),
              SelectionOption(id: 't2', label: '7:00 PM'),
              SelectionOption(id: 't3', label: '8:00 PM'),
            ],
          ),
        ),
      );
    }
    if (text.contains('video') || text.contains('media')) {
      return _ToolScenario(
        'media.find',
        _ar ? 'وسائط' : 'Media',
        result: ToolResult.media(
          items: [
            MediaItem(
              kind: MediaKind.video,
              uri: Uri.parse('https://example.com/video.mp4'),
              title: _ar ? 'مقطع تعريفي' : 'Intro clip',
              duration: const Duration(seconds: 42),
              mimeType: 'video/mp4',
            ),
          ],
        ),
      );
    }
    if (text.contains('card')) {
      return _ToolScenario(
        'cards.show',
        _ar ? 'بطاقة' : 'Card',
        result: ToolResult.richCard(
          card: RichCard(
            title: _ar ? 'عرض اليوم' : "Today's offer",
            subtitle: _ar ? 'خصم 20%' : '20% off',
            body: _ar ? 'على جميع المشروبات الساخنة.' : 'On all hot drinks.',
            actions: [
              CardAction(
                id: 'claim',
                label: _ar ? 'استفد' : 'Claim',
                primary: true,
              ),
            ],
          ),
        ),
      );
    }
    return null;
  }

  Future<void> _runTool(
    MessageId assistantId,
    _ToolScenario scenario,
    Duration delay,
  ) async {
    final toolCallId = ToolCallId('${assistantId.value}-tool');
    emit(
      (seq, eventId, at) => ConversationEvent.toolCallRequested(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        messageId: assistantId,
        toolCall: ToolCallRequest(
          id: toolCallId,
          toolName: scenario.toolName,
          displayTitle: scenario.title,
          requiresConfirmation: scenario.requiresConfirmation,
        ),
      ),
    );

    if (scenario.requiresConfirmation) {
      emit(
        (seq, eventId, at) => ConversationEvent.userConfirmationRequested(
          eventId: eventId,
          sessionId: id,
          sequence: seq,
          occurredAt: at,
          toolCallId: toolCallId,
          confirmation: scenario.confirmation!,
        ),
      );
      pendingActions[toolCallId] = (action) async {
        pendingActions.remove(toolCallId);
        switch (action) {
          case ConfirmedAction():
            await _executeTool(assistantId, toolCallId, scenario, delay);
          case DeclinedAction():
            _progress(toolCallId, ToolExecutionStatus.cancelled);
            _complete(
              assistantId,
              FinishReason.stop,
              fullText: _ar ? 'تم إلغاء الحجز.' : 'Booking cancelled.',
            );
          default:
            break;
        }
      };
      return;
    }
    await _executeTool(assistantId, toolCallId, scenario, delay);
  }

  Future<void> _executeTool(
    MessageId assistantId,
    ToolCallId toolCallId,
    _ToolScenario scenario,
    Duration delay,
  ) async {
    _progress(toolCallId, ToolExecutionStatus.running, progress: 0.2);
    await _wait(delay * 3);
    if (ended) return;
    final raw = scenario.rawResult;
    if (raw != null) {
      // Goes through ConversationEvent.fromJson so the validator runs.
      final json = <String, Object?>{
        'type': 'tool_result_received',
        'event_id': '${id.value}-evt-${++_events}',
        'session_id': id.value,
        'sequence': ++_seq,
        'occurred_at': clock.now().toIso8601String(),
        'tool_call_id': toolCallId.value,
        'message_id': assistantId.value,
        'result': raw,
      };
      final event = ConversationEvent.fromJson(json);
      log.add(event);
      emitRaw(event);
    } else {
      emit(
        (seq, eventId, at) => ConversationEvent.toolResultReceived(
          eventId: eventId,
          sessionId: id,
          sequence: seq,
          occurredAt: at,
          toolCallId: toolCallId,
          messageId: assistantId,
          result: scenario.result!,
        ),
      );
    }
    final result = scenario.result;
    final needsUserAction =
        result is FormToolResult || result is SelectionToolResult;
    if (needsUserAction) {
      pendingActions[toolCallId] = (action) async {
        pendingActions.remove(toolCallId);
        _complete(
          assistantId,
          FinishReason.stop,
          fullText: _ar
              ? 'شكراً، تم استلام إجابتك.'
              : 'Thanks, got your answer.',
        );
      };
      return;
    }
    final closing = _ar ? 'هذا ما وجدته.' : "Here's what I found.";
    final cancelled = await _stream(assistantId, closing, delay);
    if (!cancelled) {
      _complete(assistantId, FinishReason.stop, fullText: closing);
    }
  }

  void _progress(
    ToolCallId toolCallId,
    ToolExecutionStatus status, {
    double? progress,
  }) {
    emit(
      (seq, eventId, at) => ConversationEvent.toolExecutionProgress(
        eventId: eventId,
        sessionId: id,
        sequence: seq,
        occurredAt: at,
        toolCallId: toolCallId,
        status: status,
        progress: progress,
      ),
    );
  }

  Future<void> handleAction(ToolAction action) async {
    final handler = pendingActions[action.toolCallId];
    if (handler == null) {
      if (action is RetryRequestedAction) return;
      throw const ContractViolationException(
        'Mock: no pending tool call for this action.',
      );
    }
    await handler(action);
  }

  String _cannedReply(String userText) {
    if (_ar) {
      return 'أهلاً بك في نيكسا. استلمت رسالتك: "$userText". '
          'جرّب كلمات مثل مطعم، طقس، حجز أو نموذج لتجربة النتائج الغنية.';
    }
    return 'Welcome to NEXA. I received: "$userText". '
        'Try words like restaurant, weather, book or form to see rich results.';
  }
}

final class _ToolScenario {
  const _ToolScenario(
    this.toolName,
    this.title, {
    this.result,
    this.rawResult,
    this.requiresConfirmation = false,
    this.confirmation,
  });

  final String toolName;
  final String title;
  final ToolResult? result;
  final Map<String, Object?>? rawResult;
  final bool requiresConfirmation;
  final ConfirmationSpec? confirmation;
}
