import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:nexa_core/nexa_core.dart';

// =================================================================== models

enum NexaHistoryKind { chat, voice, mixed }

@immutable
final class NexaHistoryMessage {
  const NexaHistoryMessage({
    required this.fromUser,
    required this.text,
    required this.at,
  });

  factory NexaHistoryMessage.fromJson(Map<String, Object?> j) =>
      NexaHistoryMessage(
        fromUser: j['user'] == true,
        text: '${j['text']}',
        at: DateTime.parse('${j['at']}'),
      );

  final bool fromUser;
  final String text;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'user': fromUser,
    'text': text,
    'at': at.toUtc().toIso8601String(),
  };
}

/// One conversation. From the server when it offers history; otherwise
/// from the **local UI cache** ([fromCache]), which is never the permanent
/// record.
@immutable
final class NexaHistoryEntry {
  const NexaHistoryEntry({
    required this.id,
    required this.kind,
    required this.sessionId,
    required this.startedAt,
    required this.updatedAt,
    this.title,
    this.messages = const [],
    this.messageCount,
    this.fromCache = true,
  });

  factory NexaHistoryEntry.fromJson(Map<String, Object?> j) => NexaHistoryEntry(
    id: '${j['id']}',
    kind: NexaHistoryKind.values.firstWhere(
      (k) => k.name == j['kind'],
      orElse: () => NexaHistoryKind.chat,
    ),
    sessionId: '${j['session_id']}',
    startedAt: DateTime.parse('${j['started_at']}'),
    updatedAt: DateTime.parse('${j['updated_at']}'),
    title: j['title'] as String?,
    messageCount: j['message_count'] as int?,
    messages: [
      for (final m in (j['messages'] as List?) ?? const [])
        NexaHistoryMessage.fromJson((m as Map).cast<String, Object?>()),
    ],
  );

  final String id;
  final NexaHistoryKind kind;

  /// Chat `ses_…` (conversation id) or voice `vs_…`.
  final String sessionId;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String? title;

  /// Cached messages for fast rendering (bounded; may be partial).
  final List<NexaHistoryMessage> messages;

  /// Server-reported count when known.
  final int? messageCount;
  final bool fromCache;

  String? get displayTitle =>
      title ?? messages.where((m) => m.fromUser).firstOrNull?.text;

  int get count => messageCount ?? messages.length;

  NexaHistoryEntry copyWith({
    String? title,
    List<NexaHistoryMessage>? messages,
    DateTime? updatedAt,
    bool? fromCache,
  }) => NexaHistoryEntry(
    id: id,
    kind: kind,
    sessionId: sessionId,
    startedAt: startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    messageCount: messageCount,
    fromCache: fromCache ?? this.fromCache,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.name,
    'session_id': sessionId,
    'started_at': startedAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'title': ?title,
    'message_count': ?messageCount,
    'messages': [for (final m in messages) m.toJson()],
  };
}

// ================================================================ the cache

/// Bounded local UI cache store (host-provided, app-private).
abstract interface class NexaHistoryStore {
  Future<List<NexaHistoryEntry>> load();
  Future<void> save(List<NexaHistoryEntry> entries);
}

final class InMemoryHistoryStore implements NexaHistoryStore {
  List<NexaHistoryEntry> _entries = const [];

  @override
  Future<List<NexaHistoryEntry>> load() async => _entries;

  @override
  Future<void> save(List<NexaHistoryEntry> entries) async =>
      _entries = List.of(entries);
}

final class JsonFileHistoryStore implements NexaHistoryStore {
  JsonFileHistoryStore(this.file);
  final File file;

  @override
  Future<List<NexaHistoryEntry>> load() async {
    if (!file.existsSync()) return const [];
    try {
      final list = jsonDecode(await file.readAsString()) as List;
      return [
        for (final e in list)
          NexaHistoryEntry.fromJson((e as Map).cast<String, Object?>()),
      ];
    } on Object {
      return const []; // unreadable cache: start empty
    }
  }

  @override
  Future<void> save(List<NexaHistoryEntry> entries) async {
    if (entries.isEmpty) {
      if (file.existsSync()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode([for (final e in entries) e.toJson()]));
  }
}

// ============================================================ server adapter

/// Deletion scopes (design "Data & privacy").
enum NexaDeletionScope {
  conversation,
  allChats,
  allVoice,
  assets,
  localCache,
  everything,
}

/// Server state of a deletion. Only [completed] means the server confirmed.
enum NexaDeletionState { requested, running, completed, partial, failed }

@immutable
final class NexaDeletionReceipt {
  const NexaDeletionReceipt({
    required this.state,
    this.requestId,
    this.failedItems = 0,
    this.retryable = false,
  });

  final NexaDeletionState state;

  /// Server request id to track completion (e.g. `del_2043`).
  final String? requestId;
  final int failedItems;
  final bool retryable;
}

/// A page of server history.
@immutable
final class NexaHistoryPage {
  const NexaHistoryPage(this.items, {this.nextCursor});
  final List<NexaHistoryEntry> items;
  final String? nextCursor;
}

/// Thrown by [UnavailableConversationsApi]: the server has no such API.
final class NexaFeatureUnavailable implements Exception {
  const NexaFeatureUnavailable(this.feature);
  final String feature;
  @override
  String toString() => 'NexaFeatureUnavailable($feature)';
}

/// AWS conversation/history API (proposed contract:
/// `docs/contracts/nexa-client-tools.proposed.md` §6–7). Implemented by a
/// gateway adapter once the endpoints exist; [UnavailableConversationsApi]
/// until then.
abstract interface class NexaConversationsApi {
  bool get canList;
  bool get canOpen;
  bool get canResume;
  bool get canRename;
  bool supportsDeletion(NexaDeletionScope scope);

  /// Newest first; [cursor] from the previous page.
  Future<NexaHistoryPage> list({String? cursor, int limit = 20});
  Future<List<NexaHistoryMessage>> open(String conversationId);
  Future<void> rename(String conversationId, String title);

  /// [conversationId] only for [NexaDeletionScope.conversation].
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  });
  Future<NexaDeletionReceipt> deletionStatus(String requestId);
}

/// Today's backend: no history or deletion API. Says so; never pretends.
final class UnavailableConversationsApi implements NexaConversationsApi {
  const UnavailableConversationsApi();
  @override
  bool get canList => false;
  @override
  bool get canOpen => false;
  @override
  bool get canResume => false;
  @override
  bool get canRename => false;
  @override
  bool supportsDeletion(NexaDeletionScope scope) => false;
  @override
  Future<NexaHistoryPage> list({String? cursor, int limit = 20}) =>
      Future.error(const NexaFeatureUnavailable('history.list'));
  @override
  Future<List<NexaHistoryMessage>> open(String conversationId) =>
      Future.error(const NexaFeatureUnavailable('history.open'));
  @override
  Future<void> rename(String conversationId, String title) =>
      Future.error(const NexaFeatureUnavailable('history.rename'));
  @override
  Future<NexaDeletionReceipt> delete(
    NexaDeletionScope scope, {
    String? conversationId,
  }) => Future.error(const NexaFeatureUnavailable('deletion'));
  @override
  Future<NexaDeletionReceipt> deletionStatus(String requestId) =>
      Future.error(const NexaFeatureUnavailable('deletion.status'));
}

// ================================================================== options

@immutable
final class NexaHistoryOptions {
  const NexaHistoryOptions({
    required this.cache,
    this.server = const UnavailableConversationsApi(),
    this.maxCachedConversations = 50,
    this.maxCachedMessages = 100,
    this.pageSize = 20,
    this.retentionNotice,
    this.onClearHostData,
  });

  /// Bounded local UI cache (never the permanent history).
  final NexaHistoryStore cache;
  final NexaConversationsApi server;
  final int maxCachedConversations;
  final int maxCachedMessages;
  final int pageSize;

  /// Retention text from the app/operator (e.g. "kept for 30 days").
  final String? retentionNotice;

  /// Clears the host's own local data (e.g. diagnostics); returns how many
  /// items were removed.
  final Future<int> Function()? onClearHostData;
}

/// Outcome of one deletion scope: what happened on the device and what the
/// server acknowledged (no server part when the server has no API for it).
@immutable
final class NexaDeletionOutcome {
  const NexaDeletionOutcome({
    required this.scope,
    this.localRemoved = 0,
    this.server,
    this.serverError,
    this.serverAvailable = false,
  });

  final NexaDeletionScope scope;
  final int localRemoved;
  final bool serverAvailable;
  final NexaDeletionReceipt? server;
  final Object? serverError;

  bool get serverConfirmed => server?.state == NexaDeletionState.completed;
}

// =============================================================== controller

/// History list (server pages when available, else the local UI cache),
/// conversation open, rename and the deletion scopes.
final class NexaHistoryController extends ChangeNotifier {
  NexaHistoryController(this.options);

  final NexaHistoryOptions options;
  NexaConversationsApi get server => options.server;

  final List<NexaHistoryEntry> _cache = [];
  final List<NexaHistoryEntry> _serverItems = [];
  String? _cursor;
  bool _cacheLoaded = false;
  bool _loading = false;
  bool _hasMore = false;
  Object? _error;

  bool get loading => _loading;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  /// Whether the list shows server history (true) or the device cache.
  bool get serverBacked => server.canList;

  /// Newest first.
  List<NexaHistoryEntry> get entries {
    final source = serverBacked ? _serverItems : _cache;
    return List.unmodifiable(
      <NexaHistoryEntry>[...source]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
    );
  }

  List<NexaHistoryEntry> get cachedEntries => List.unmodifiable(_cache);

  Future<void> _loadCache() async {
    if (_cacheLoaded) return;
    _cache
      ..clear()
      ..addAll(await options.cache.load());
    _cacheLoaded = true;
  }

  /// First page (server) or the cache.
  Future<void> refresh() async {
    await _loadCache();
    _serverItems.clear();
    _cursor = null;
    _hasMore = serverBacked;
    notifyListeners();
    if (serverBacked) await loadMore();
  }

  /// Next server page.
  Future<void> loadMore() async {
    if (!serverBacked || _loading || !_hasMore) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await server.list(cursor: _cursor, limit: options.pageSize);
      _serverItems.addAll(page.items.map((e) => e.copyWith(fromCache: false)));
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      // Keep summaries in the cache for fast/offline rendering.
      for (final e in page.items) {
        _upsertCache(e.copyWith(fromCache: true), keepMessages: true);
      }
      await _persist();
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Messages of [entry]: from the server when available (refreshing the
  /// cache), else the cached copy.
  Future<List<NexaHistoryMessage>> open(NexaHistoryEntry entry) async {
    if (!server.canOpen) return entry.messages;
    final messages = await server.open(entry.sessionId);
    _upsertCache(entry.copyWith(messages: messages, fromCache: true));
    await _persist();
    return messages;
  }

  /// Server rename (the cache follows after the server accepted it).
  Future<void> rename(NexaHistoryEntry entry, String title) async {
    final t = title.trim();
    if (!server.canRename || t.isEmpty) return;
    await server.rename(entry.sessionId, t);
    _replaceEverywhere(entry.id, (e) => e.copyWith(title: t));
    await _persist();
  }

  // ------------------------------------------------- recording (cache only)

  /// Caches the visible chat conversation for fast rendering. The server
  /// already has it: only the new input was sent (`POST …/messages`).
  Future<void> recordChat(ConversationState conversation) async {
    final sid = conversation.sessionId?.value;
    if (sid == null) return;
    final messages = [
      for (final m in conversation.messages)
        if (m.text.trim().isNotEmpty &&
            (m.role == MessageRole.user || m.status == MessageStatus.completed))
          NexaHistoryMessage(
            fromUser: m.role == MessageRole.user,
            text: m.text,
            at: m.createdAt,
          ),
    ];
    if (messages.isEmpty) return;
    await _record(NexaHistoryKind.chat, sid, messages);
  }

  /// Caches a voice call reference (final transcript lines when kept).
  Future<void> recordVoice(
    String voiceSessionId,
    List<VoiceTranscriptEntry> transcript,
  ) => _record(NexaHistoryKind.voice, voiceSessionId, [
    for (final t in transcript)
      if (t.isFinal && t.text.trim().isNotEmpty)
        NexaHistoryMessage(
          fromUser: t.speaker == VoiceSpeaker.user,
          text: t.text,
          at: t.at,
        ),
  ]);

  Future<void> _record(
    NexaHistoryKind kind,
    String sessionId,
    List<NexaHistoryMessage> messages,
  ) async {
    await _loadCache();
    final now = DateTime.now().toUtc();
    final existing = _cache.where((e) => e.sessionId == sessionId).firstOrNull;
    _upsertCache(
      existing?.copyWith(messages: messages, updatedAt: now) ??
          NexaHistoryEntry(
            id: 'h_${now.microsecondsSinceEpoch}',
            kind: kind,
            sessionId: sessionId,
            startedAt: messages.firstOrNull?.at ?? now,
            updatedAt: now,
            messages: messages,
          ),
    );
    await _persist();
    notifyListeners();
  }

  void _upsertCache(NexaHistoryEntry e, {bool keepMessages = false}) {
    final i = _cache.indexWhere((c) => c.sessionId == e.sessionId);
    if (i < 0) {
      _cache.add(e);
    } else {
      _cache[i] = keepMessages && e.messages.isEmpty
          ? e.copyWith(messages: _cache[i].messages)
          : e;
    }
  }

  void _replaceEverywhere(
    String id,
    NexaHistoryEntry Function(NexaHistoryEntry) f,
  ) {
    for (final list in [_cache, _serverItems]) {
      final i = list.indexWhere((e) => e.id == id);
      if (i >= 0) list[i] = f(list[i]);
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    // Bounded: newest conversations, newest messages.
    _cache.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (_cache.length > options.maxCachedConversations) {
      _cache.removeRange(options.maxCachedConversations, _cache.length);
    }
    for (var i = 0; i < _cache.length; i++) {
      final m = _cache[i].messages;
      if (m.length > options.maxCachedMessages) {
        _cache[i] = _cache[i].copyWith(
          messages: m.sublist(m.length - options.maxCachedMessages),
        );
      }
    }
    await options.cache.save(_cache);
  }

  // ------------------------------------------------------------- deletion

  /// Runs one deletion scope: the local part first (always), then the
  /// server part when the server supports it. Never reports server deletion
  /// the server did not acknowledge.
  Future<NexaDeletionOutcome> delete(
    NexaDeletionScope scope, {
    NexaHistoryEntry? conversation,
    Future<int> Function()? deleteLocalMedia,
  }) async {
    await _loadCache();
    var local = 0;
    void removeWhere(bool Function(NexaHistoryEntry) test) {
      final before = _cache.length;
      _cache.removeWhere(test);
      _serverItems.removeWhere(test);
      local += before - _cache.length;
    }

    switch (scope) {
      case NexaDeletionScope.conversation:
        final id = conversation?.sessionId;
        removeWhere((e) => e.sessionId == id);
      case NexaDeletionScope.allChats:
        removeWhere((e) => e.kind != NexaHistoryKind.voice);
      case NexaDeletionScope.allVoice:
        removeWhere((e) => e.kind == NexaHistoryKind.voice);
      case NexaDeletionScope.assets:
        local += await deleteLocalMedia?.call() ?? 0;
      case NexaDeletionScope.localCache:
        local += _cache.length;
        _cache.clear();
        local += await deleteLocalMedia?.call() ?? 0;
        local += await options.onClearHostData?.call() ?? 0;
      case NexaDeletionScope.everything:
        removeWhere((_) => true);
        local += await deleteLocalMedia?.call() ?? 0;
        local += await options.onClearHostData?.call() ?? 0;
    }
    await _persist();
    notifyListeners();
    if (scope == NexaDeletionScope.localCache ||
        !server.supportsDeletion(scope)) {
      return NexaDeletionOutcome(scope: scope, localRemoved: local);
    }
    try {
      final receipt = await server.delete(
        scope,
        conversationId: conversation?.sessionId,
      );
      return NexaDeletionOutcome(
        scope: scope,
        localRemoved: local,
        serverAvailable: true,
        server: receipt,
      );
    } on Object catch (e) {
      return NexaDeletionOutcome(
        scope: scope,
        localRemoved: local,
        serverAvailable: true,
        serverError: e,
      );
    }
  }

  /// Retries the server part of [scope] (after a partial failure).
  Future<NexaDeletionOutcome> retryServer(
    NexaDeletionScope scope, {
    NexaHistoryEntry? conversation,
  }) async {
    try {
      final receipt = await server.delete(
        scope,
        conversationId: conversation?.sessionId,
      );
      return NexaDeletionOutcome(
        scope: scope,
        serverAvailable: true,
        server: receipt,
      );
    } on Object catch (e) {
      return NexaDeletionOutcome(
        scope: scope,
        serverAvailable: true,
        serverError: e,
      );
    }
  }
}
