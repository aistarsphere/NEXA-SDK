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
    this.clientToolTimeout = const Duration(minutes: 3),
    this.verbose = false,
  });

  final Duration tokenTtl;
  final Duration sessionTtl;
  final int quotaPerApplication;
  final Duration deltaDelay;
  final Duration slowDeltaDelay;
  final Duration thinkDelay;
  final Duration keepAliveInterval;

  /// How long a `client_tool_call` waits for the device's result.
  final Duration clientToolTimeout;
  final bool verbose;
}

/// A minted session credential. Stands in for what the host backend would
/// obtain from the real gateway's tenant endpoint.
final class IssuedToken {
  IssuedToken({
    required this.token,
    required this.applicationId,
    required this.expiresAt,
    this.scopes = const {'chat:session'},
  });

  final String token;
  final String applicationId;
  final DateTime expiresAt;

  /// `voice:session` is NOT a default scope (contract v1 §2).
  final Set<String> scopes;

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

  /// Client tools the app advertised at session start (`client_tools`).
  final Set<String> clientTools = {};

  /// Pending `client_tool_call`s: call id -> result (contract
  /// `nexa.client_tool.v1`).
  final Map<String, Completer<Map<String, Object?>>> clientCalls = {};

  /// `context` of the latest user message (e.g. places ordinals).
  Map<String, Object?>? lastContext;

  /// The latest places result shown to the user (for "the second one").
  List<Map<String, Object?>> lastPlaces = const [];

  /// labeeb.sdk/1: the conversation this session joined.
  String? conversationId;

  /// labeeb.sdk/1 tool calls of this session.
  final Map<String, ContractCall> contractCalls = {};

  /// `nexa.ui/1` documents sent in this session (validates `ui_event`).
  final Map<String, Map<String, Object?>> uiDocs = {};

  /// Called for every appended event (e.g. to record messages).
  void Function(Map<String, Object?> event)? observer;
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
    observer?.call(event);
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
    // Ending the session cancels open tool calls (labeeb.sdk/1).
    for (final c in contractCalls.values.where((c) => c.open)) {
      c.settle('cancelled', error: {'code': 'cancelled', 'retryable': false});
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

  /// labeeb.sdk/1 server-owned conversations, assets and preferences.
  final Map<String, ConversationRecord> conversations = {};
  final Map<String, AssetRecord> assets = {};
  final Map<String, Map<String, Object?>> preferences = {};
  final Random _random = Random.secure();
  int _sessionCounter = 0;
  int _idCounter = 0;

  /// A new id with [prefix] (`conv`, `ast`, `tc`, …).
  String newId(String prefix) => '${prefix}_${++_idCounter}${_randomSuffix()}';

  String _randomSuffix() =>
      List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();

  ApplicationState application(String id) => applications.putIfAbsent(
    id,
    () => ApplicationState(id, options.quotaPerApplication),
  );

  IssuedToken mintToken(
    String applicationId, {
    Duration? ttl,
    Set<String> scopes = const {'chat:session'},
  }) {
    final token = IssuedToken(
      token: 'nrg_${_randomSuffix()}${_randomSuffix()}',
      applicationId: applicationId,
      expiresAt: DateTime.now().toUtc().add(ttl ?? options.tokenTtl),
      scopes: scopes,
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

/// A labeeb.sdk/1 tool call (`tool_call.statuses`).
final class ContractCall {
  ContractCall({
    required this.id,
    required this.tool,
    required this.side,
    required this.arguments,
    required this.status,
    required this.deadlineAt,
    this.approvalRequired = false,
    this.asynchronous = false,
  });

  final String id;
  final String tool;
  final String side;
  final Map<String, Object?> arguments;
  String status;
  final DateTime deadlineAt;
  final bool approvalRequired;
  final bool asynchronous;
  Map<String, Object?>? result;
  Map<String, Object?>? error;

  /// Completes when the call reaches a terminal status.
  final Completer<ContractCall> done = Completer<ContractCall>();

  /// Completes when the user approved (true) or denied (false).
  final Completer<bool> approval = Completer<bool>();

  bool get open =>
      status == 'awaiting_approval' ||
      status == 'awaiting_client' ||
      status == 'running';

  void settle(
    String terminal, {
    Map<String, Object?>? result,
    Map<String, Object?>? error,
  }) {
    status = terminal;
    this.result = result;
    this.error = error;
    if (!approval.isCompleted) approval.complete(false);
    if (!done.isCompleted) done.complete(this);
  }

  Map<String, Object?> toJson() => {
    'tool_call_id': id,
    'tool': tool,
    'side': side,
    'arguments': arguments,
    'status': status,
    'approval_required': approvalRequired,
    'deadline_at': deadlineAt.toIso8601String(),
    'result': result,
    'error': error,
    'asynchronous': asynchronous,
  };
}

/// A server-owned conversation (labeeb.sdk/1 `conversations.history`).
final class ConversationRecord {
  ConversationRecord({
    required this.id,
    required this.applicationId,
    required this.kind,
    this.title,
    this.titleSource = 'auto',
    this.clientRef,
    this.installation,
  }) : createdAt = DateTime.now().toUtc(),
       updatedAt = DateTime.now().toUtc();

  final String id;
  final String applicationId;
  final String kind;
  String? title;
  String titleSource;
  final String? clientRef;
  final String? installation;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? lastMessageAt;
  String? activeSession;
  String? latestSession;
  int seq = 0;
  final List<Map<String, Object?>> messages = [];

  int get messageCount => messages.where((m) => m['role'] == 'user').length;

  void addMessage(Map<String, Object?> m) {
    final now = DateTime.now().toUtc();
    messages.add({...m, 'seq': ++seq, 'created_at': now.toIso8601String()});
    updatedAt = now;
    lastMessageAt = now;
  }

  Map<String, Object?> toJson({bool withSessions = false}) => {
    'id': id,
    'title': title,
    'title_source': titleSource,
    'kind': kind,
    'message_count': messageCount,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'last_message_at': lastMessageAt?.toIso8601String(),
    if (withSessions)
      'sessions': {'active': activeSession, 'latest': latestSession},
  };
}

/// An uploaded or generated attachment.
final class AssetRecord {
  AssetRecord({
    required this.id,
    required this.applicationId,
    required this.conversationId,
    required this.mime,
    required this.bytes,
    required this.origin,
    this.filename,
  }) : createdAt = DateTime.now().toUtc();

  final String id;
  final String applicationId;
  final String conversationId;
  final String mime;
  final List<int> bytes;
  final String origin;
  final String? filename;
  final DateTime createdAt;
  String? messageId;

  String get kind => mime.startsWith('image/') ? 'image' : 'file';

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind,
    'origin': origin,
    'mime': mime,
    'size_bytes': bytes.length,
    'filename': filename,
    'conversation_id': conversationId,
    'message_id': messageId,
    'created_at': createdAt.toIso8601String(),
  };
}
