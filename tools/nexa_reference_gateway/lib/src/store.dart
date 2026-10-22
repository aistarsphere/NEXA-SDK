import 'dart:async';
import 'dart:math';

/// Tunables for the reference gateway. Defaults mirror the CLI flags.
final class GatewayOptions {
  const GatewayOptions({
    this.tokenTtl = const Duration(minutes: 15),
    this.sessionTtl = const Duration(hours: 1),
    this.quotaPerApplication = 50,
    this.deltaDelay = const Duration(milliseconds: 40),
    this.slowDeltaDelay = const Duration(milliseconds: 250),
    this.thinkDelay = const Duration(milliseconds: 200),
    this.keepAliveInterval = const Duration(seconds: 15),
    this.verbose = false,
  });

  final Duration tokenTtl;
  final Duration sessionTtl;
  final int quotaPerApplication;
  final Duration deltaDelay;
  final Duration slowDeltaDelay;
  final Duration thinkDelay;
  final Duration keepAliveInterval;
  final bool verbose;
}

/// A minted session credential. Stands in for what the host backend would
/// obtain from the real gateway's tenant endpoint.
final class IssuedToken {
  IssuedToken({
    required this.token,
    required this.applicationId,
    required this.expiresAt,
  });

  final String token;
  final String applicationId;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);
}

/// Per-application state (tenant stand-in).
final class ApplicationState {
  ApplicationState(this.id, this.quotaRemaining);
  final String id;
  int quotaRemaining;
}

/// Chaos switches a scripted scenario can arm on a session.
final class ChaosFlags {
  /// SSE: close the connection right after writing this sequence (once).
  int? dropStreamAfterSequence;

  /// Long-poll: answer 503 to the next poll (once).
  bool failNextPoll = false;

  /// Deliver every event twice while true.
  bool duplicateEvents = false;

  /// Answer 429 once to the next message that contains `ratelimit`.
  bool rateLimitArmed = true;
}

/// State of one assistant reply in flight.
final class ReplyState {
  ReplyState(this.messageId);
  final String messageId;
  bool cancelRequested = false;
  bool finished = false;
}

/// State of one tool call awaiting a user action.
final class PendingToolCall {
  PendingToolCall({
    required this.id,
    required this.name,
    required this.messageId,
    required this.confirmationId,
  });
  final String id;
  final String name;
  final String messageId;
  final String confirmationId;
  bool resolved = false;
}

/// One conversation session with its ordered event log.
final class SessionState {
  SessionState({
    required this.id,
    required this.applicationId,
    required this.tokenValue,
    required this.languageTag,
    required this.expiresAt,
    required this.grantedCapabilities,
  });

  final String id;
  final String applicationId;
  final String tokenValue;
  final String languageTag;
  final DateTime expiresAt;
  final List<String> grantedCapabilities;

  final List<Map<String, Object?>> log = [];
  final Map<String, String> idempotency = {}; // client_message_id -> text
  final Map<String, ReplyState> replies = {}; // assistant message id -> state
  final Map<String, PendingToolCall> toolCalls = {};
  final Map<String, bool?> permissions = {}; // request id -> granted
  final ChatChaos chaos = ChatChaos();

  bool ended = false;
  String? endReason;
  int _sequence = 0;
  int _eventCounter = 0;
  int _messageCounter = 0;
  Timer? expiryTimer;

  final StreamController<Map<String, Object?>> _live =
      StreamController<Map<String, Object?>>.broadcast(sync: true);

  /// Live feed of appended events (after the log snapshot).
  Stream<Map<String, Object?>> get live => _live.stream;

  int get lastSequence => _sequence;

  String nextMessageId(String role) => 'msg_${role}_${++_messageCounter}';

  /// Appends an event with the next sequence and returns it.
  Map<String, Object?> append(String type, Map<String, Object?> fields) {
    final event = <String, Object?>{
      'type': type,
      'event_id': 'evt_${id}_${++_eventCounter}',
      'session_id': id,
      'sequence': ++_sequence,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      ...fields,
    };
    log.add(event);
    if (!_live.isClosed) _live.add(event);
    return event;
  }

  /// Events with `sequence > after`, honouring the duplicate chaos flag.
  List<Map<String, Object?>> eventsAfter(int after) {
    final out = <Map<String, Object?>>[];
    for (final e in log) {
      if ((e['sequence']! as int) > after) {
        out.add(e);
        if (chaos.duplicateEvents) out.add(e);
      }
    }
    return out;
  }

  /// Marks the session ended, emitting `session_ended` once.
  void end(String reason) {
    if (ended) return;
    ended = true;
    endReason = reason;
    expiryTimer?.cancel();
    for (final r in replies.values) {
      r.cancelRequested = true;
    }
    append('session_ended', {'reason': reason});
    unawaited(_live.close());
  }

  void dispose() {
    expiryTimer?.cancel();
    if (!_live.isClosed) unawaited(_live.close());
  }
}

/// Chaos holder (kept separate so the name reads well at call sites).
typedef ChatChaos = ChaosFlags;

/// In-memory store: tokens, applications, sessions.
final class GatewayStore {
  GatewayStore(this.options);

  final GatewayOptions options;
  final Map<String, IssuedToken> tokens = {};
  final Map<String, ApplicationState> applications = {};
  final Map<String, SessionState> sessions = {};
  final Random _random = Random.secure();
  int _sessionCounter = 0;

  String _randomSuffix() =>
      List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();

  ApplicationState application(String id) => applications.putIfAbsent(
    id,
    () => ApplicationState(id, options.quotaPerApplication),
  );

  IssuedToken mintToken(String applicationId, {Duration? ttl}) {
    final token = IssuedToken(
      token: 'nrg_${_randomSuffix()}${_randomSuffix()}',
      applicationId: applicationId,
      expiresAt: DateTime.now().toUtc().add(ttl ?? options.tokenTtl),
    );
    tokens[token.token] = token;
    application(applicationId);
    return token;
  }

  SessionState createSession({
    required IssuedToken token,
    required String languageTag,
    required List<String> granted,
  }) {
    final id = 'ses_${++_sessionCounter}_${_randomSuffix()}';
    final session = SessionState(
      id: id,
      applicationId: token.applicationId,
      tokenValue: token.token,
      languageTag: languageTag,
      expiresAt: DateTime.now().toUtc().add(options.sessionTtl),
      grantedCapabilities: granted,
    );
    sessions[id] = session;
    session.expiryTimer = Timer(options.sessionTtl, () {
      session.end('expired');
    });
    return session;
  }

  void dispose() {
    for (final s in sessions.values) {
      s.dispose();
    }
    sessions.clear();
    tokens.clear();
  }
}
