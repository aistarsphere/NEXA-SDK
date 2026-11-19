import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// A tool call that was not finished when the app last ran: the session it
/// must be answered in (a voice call's hidden `tools.session_id` exists
/// nowhere else) and what the gateway last said. Never its arguments or
/// result (those come from the server again).
@immutable
final class LabeebPendingCall {
  const LabeebPendingCall({
    required this.sessionId,
    required this.status,
    required this.seenAt,
  });

  final String sessionId;

  /// Last known wire status (`awaiting_approval`, `running`, …).
  final String status;
  final DateTime seenAt;
}

/// Pending calls and half-filled `nexa.ui/1` forms of one conversation.
@immutable
final class LabeebPendingState {
  const LabeebPendingState({this.calls = const {}, this.uiValues = const {}});

  /// `tool_call_id` → pending call.
  final Map<String, LabeebPendingCall> calls;

  /// `ui_id` → `component_id` → JSON-safe value.
  final Map<String, Map<String, Object?>> uiValues;

  bool get isEmpty => calls.isEmpty && uiValues.isEmpty;
}

/// Where pending tool-workflow state is kept between runs (per account).
abstract interface class LabeebPendingStore {
  Future<LabeebPendingState> load(String conversationId);

  /// Replaces the state of [conversationId]; an empty state removes it.
  Future<void> save(String conversationId, LabeebPendingState state);

  /// Removes the state of every conversation (all history was deleted).
  Future<void> clear();
}

/// Keeps state for the life of the process only (tests, and the default).
final class InMemoryPendingStore implements LabeebPendingStore {
  final Map<String, LabeebPendingState> _byConversation = {};

  @override
  Future<LabeebPendingState> load(String conversationId) async =>
      _byConversation[conversationId] ?? const LabeebPendingState();

  @override
  Future<void> save(String conversationId, LabeebPendingState state) async {
    if (state.isEmpty) {
      _byConversation.remove(conversationId);
    } else {
      _byConversation[conversationId] = state;
    }
  }

  @override
  Future<void> clear() async => _byConversation.clear();
}

/// One small JSON file per account, bounded: 50 calls per conversation,
/// 20 conversations, 7 days.
final class JsonFilePendingStore implements LabeebPendingStore {
  JsonFilePendingStore(this.file);

  /// `pending_<first 8 hex of sha256(accountKey)>.json` in [directory]: the
  /// key is not readable from the name and accounts never share a file.
  factory JsonFilePendingStore.forAccount(
    Directory directory,
    String accountKey,
  ) {
    final h = sha256
        .convert(utf8.encode(accountKey))
        .toString()
        .substring(0, 8);
    return JsonFilePendingStore(File('${directory.path}/pending_$h.json'));
  }

  final File file;

  static const maxCallsPerConversation = 50;
  static const maxConversations = 20;
  static const maxAge = Duration(days: 7);

  // Reads and writes run one after the other.
  Future<void> _queue = Future.value();

  Future<T> _serial<T>(Future<T> Function() job) {
    final result = _queue.then((_) => job());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Map<String, Object?>> _read() async {
    if (!file.existsSync()) return {};
    try {
      final j = jsonDecode(await file.readAsString());
      return j is Map ? j.cast<String, Object?>() : {};
    } on Object {
      return {}; // unreadable: start empty (cache-like state, never truth)
    }
  }

  @override
  Future<LabeebPendingState> load(String conversationId) => _serial(() async {
    final entry = (await _read())[conversationId];
    return entry is Map
        ? _decode(entry.cast<String, Object?>())
        : const LabeebPendingState();
  });

  @override
  Future<void> save(String conversationId, LabeebPendingState state) =>
      _serial(() async {
        final all = await _read();
        final fresh = _prune(state);
        if (fresh.isEmpty) {
          all.remove(conversationId);
        } else {
          all[conversationId] = _encode(fresh);
        }
        // Newest conversations only.
        final ordered = all.entries.toList()
          ..sort(
            (a, b) => '${(b.value as Map?)?['updated_at']}'.compareTo(
              '${(a.value as Map?)?['updated_at']}',
            ),
          );
        final kept = Map.fromEntries(ordered.take(maxConversations));
        if (kept.isEmpty) {
          if (file.existsSync()) await file.delete();
          return;
        }
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonEncode(kept));
      });

  @override
  Future<void> clear() => _serial(() async {
    if (file.existsSync()) await file.delete();
  });

  LabeebPendingState _prune(LabeebPendingState s) {
    final limit = clock.now().toUtc().subtract(maxAge);
    final calls =
        s.calls.entries.where((e) => !e.value.seenAt.isBefore(limit)).toList()
          ..sort((a, b) => b.value.seenAt.compareTo(a.value.seenAt));
    return LabeebPendingState(
      calls: Map.fromEntries(calls.take(maxCallsPerConversation)),
      uiValues: s.uiValues,
    );
  }

  Map<String, Object?> _encode(LabeebPendingState s) => {
    'updated_at': clock.now().toUtc().toIso8601String(),
    'calls': {
      for (final e in s.calls.entries)
        e.key: {
          'session_id': e.value.sessionId,
          'status': e.value.status,
          'seen_at': e.value.seenAt.toUtc().toIso8601String(),
        },
    },
    'ui': s.uiValues,
  };

  LabeebPendingState _decode(Map<String, Object?> j) {
    final updated = DateTime.tryParse('${j['updated_at']}');
    final limit = clock.now().toUtc().subtract(maxAge);
    if (updated == null || updated.isBefore(limit)) {
      return const LabeebPendingState();
    }
    final calls = <String, LabeebPendingCall>{};
    if (j['calls'] case final Map<Object?, Object?> raw) {
      for (final MapEntry(:key, :value) in raw.entries) {
        if (key is! String || value is! Map) continue;
        final seen = DateTime.tryParse('${value['seen_at']}');
        final sid = value['session_id'];
        if (seen == null || sid is! String || seen.isBefore(limit)) continue;
        calls[key] = LabeebPendingCall(
          sessionId: sid,
          status: '${value['status']}',
          seenAt: seen,
        );
      }
    }
    final ui = <String, Map<String, Object?>>{};
    if (j['ui'] case final Map<Object?, Object?> raw) {
      for (final MapEntry(:key, :value) in raw.entries) {
        if (key is String && value is Map) {
          ui[key] = value.cast<String, Object?>();
        }
      }
    }
    return LabeebPendingState(calls: calls, uiValues: ui);
  }
}
