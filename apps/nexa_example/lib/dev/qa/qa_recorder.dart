// DEVELOPMENT ONLY: never constructed unless ExampleConfig.devTools is on.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:nexa_example/dev/qa/qa_analysis.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// Local QA diagnostics store for real-device testing.
///
/// Implements the SDK's [NexaDiagnostics] sink and writes one JSON Lines
/// file per session under `<app documents>/nexa_qa/`:
///
/// * `records/<record_id>.jsonl`: `{"t_ms", "wall", "ev", "d"}` per line,
///   `t_ms` monotonic from the record's start;
/// * `index.jsonl`: one line per record (id, type, SDK session id, start/end,
///   outcome, metrics, warning/error counts, file), newest last, at most
///   [maxRecords] (older records and their files are deleted).
///
/// A **chat** record spans one SDK chat session (`session.start_requested`
/// to `session.ended`); a **voice** record spans one call (`voice.start` to
/// cleanup). Records are redacted on write: credentials, bearer/JWT strings
/// and token-like keys never reach disk, and message text/transcripts are
/// kept only when [captureTranscripts] was switched on for that session
/// (it switches itself off when that session ends).
///
/// Retrieve with `dart run tool/qa.dart pull` (see the example README).
final class QaRecorder with WidgetsBindingObserver implements NexaDiagnostics {
  QaRecorder._(this.root, this._meta, this.maxRecords);

  /// Opens (or creates) the store in [root] and loads the index.
  static Future<QaRecorder> open({
    required Directory root,
    required Map<String, Object?> appMeta,
    int maxRecords = 40,
  }) async {
    final r = QaRecorder._(root, appMeta, maxRecords);
    await r._load();
    return r;
  }

  final Directory root;
  final int maxRecords;
  final Map<String, Object?> _meta;

  /// Anonymous id of this app launch (groups the records of one test run).
  final String runId = 'run_${_stamp(DateTime.now().toUtc())}_${_hex(3)}';

  /// Label applied to records that start while it is set.
  final ValueNotifier<String> label = ValueNotifier('');

  /// Explicit opt-in: keep message text and transcripts for the next
  /// session(s) that start while on. Turns itself off when such a session
  /// ends, so it never silently stays on.
  final ValueNotifier<bool> captureTranscripts = ValueNotifier(false);

  /// Index entries, oldest first. Updated as records open and close.
  final ValueNotifier<List<Map<String, Object?>>> index = ValueNotifier(
    const [],
  );

  _Record? _chat;
  _Record? _voice;
  Timer? _voiceClose;

  File get _indexFile => File('${root.path}/index.jsonl');
  Directory get _records => Directory('${root.path}/records');

  @override
  bool get enabled => true;

  @override
  bool get captureContent => captureTranscripts.value;

  // ----------------------------------------------------------- recording

  @override
  void record(String event, [Map<String, Object?> data = const {}]) {
    final area = event.split('.').first;
    switch (area) {
      case 'voice':
        if (event == 'voice.start') {
          _closeVoiceNow();
          _voice = _open('voice');
        }
        final r = _voice;
        if (r == null) return;
        _append(r, event, data);
        if (event == 'voice.created') {
          r.sessionId = data['voice_session_id'] as String?;
          _publishIndex(r);
        }
        if (event == 'voice.ended') r.outcome = 'ended:${data['reason']}';
        if (event == 'voice.failed' && r.outcome == null) {
          r.outcome = 'failed:${data['error']}';
        }
        if (event == 'voice.teardown_done') {
          // Late stats/room events follow the teardown by a few ms.
          _voiceClose?.cancel();
          _voiceClose = Timer(
            const Duration(milliseconds: 1500),
            _closeVoiceNow,
          );
        }
      case 'session' || 'chat':
        if (event == 'session.start_requested' && _chat == null) {
          _chat = _open('chat');
        }
        final r = _chat;
        if (r == null) return;
        _append(r, event, data);
        if (event == 'session.started') {
          r.sessionId = data['session_id'] as String?;
          _publishIndex(r);
        } else if (event == 'session.start_failed') {
          r.outcome = 'start_failed:${data['error']}';
          _close(r);
        } else if (event == 'session.ended') {
          r.outcome = 'ended:${data['reason']}';
          _close(r);
        }
      case 'http':
        final r = data['channel'] == 'voice' ? (_voice ?? _chat) : _chat;
        if (r != null) _append(r, event, data);
      default:
        for (final r in [_chat, _voice].nonNulls) {
          _append(r, event, data);
        }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      record('app.lifecycle', {'state': state.name});

  _Record _open(String type) {
    final now = DateTime.now().toUtc();
    final id = 'qa_${_stamp(now)}_${type}_${_hex(2)}';
    final r = _Record(
      id: id,
      type: type,
      startedAt: now,
      file: File('${_records.path}/$id.jsonl'),
      label: label.value.trim().isEmpty ? null : label.value.trim(),
      contentCapture: captureTranscripts.value,
    );
    _append(r, 'qa.record_started', {
      'record_id': id,
      'type': type,
      'run_id': runId,
      'label': r.label,
      'content_capture': r.contentCapture,
      ..._meta,
    });
    _publishIndex(r);
    return r;
  }

  void _append(_Record r, String event, Map<String, Object?> data) {
    if (r.closed) return;
    final clean = _redact(data, content: r.contentCapture);
    final line = QaLine(r.watch.elapsedMilliseconds, '', event, clean);
    r.lines.add(line);
    final json = jsonEncode({
      't_ms': line.tMs,
      'wall': DateTime.now().toUtc().toIso8601String(),
      'ev': event,
      'd': clean,
    });
    _write(() {
      r.file.parent.createSync(recursive: true);
      r.file.writeAsStringSync('$json\n', mode: FileMode.append);
    });
  }

  void _closeVoiceNow() {
    _voiceClose?.cancel();
    _voiceClose = null;
    final r = _voice;
    _voice = null;
    if (r != null) _close(r);
  }

  void _close(_Record r) {
    if (r.closed) return;
    _append(r, 'qa.record_ended', {'outcome': r.outcome ?? 'ended'});
    r
      ..outcome ??= 'ended'
      ..endedAt = DateTime.now().toUtc()
      ..closed = true;
    if (identical(_chat, r)) _chat = null;
    if (r.contentCapture) captureTranscripts.value = false;
    _publishIndex(r);
  }

  /// Ends open records (e.g. when the client is disposed).
  Future<void> flush() async {
    _closeVoiceNow();
    final chat = _chat;
    if (chat != null) _close(chat);
  }

  // --------------------------------------------------------------- index

  final Map<String, Map<String, Object?>> _entries = {};

  /// Updates [r]'s index entry (if given) and rewrites `index.jsonl`.
  void _publishIndex([_Record? r]) {
    if (r != null) _entries[r.id] = r.toIndex();
    final all = _entries.values.toList()
      ..sort((a, b) => '${a['started_at']}'.compareTo('${b['started_at']}'));
    final drop = all.length > maxRecords
        ? all.sublist(0, all.length - maxRecords)
        : const <Map<String, Object?>>[];
    for (final e in drop) {
      _entries.remove(e['id']);
    }
    final kept = all.sublist(drop.length);
    index.value = List.unmodifiable(kept);
    final text = kept.map(jsonEncode).join('\n');
    _write(() {
      root.createSync(recursive: true);
      _indexFile.writeAsStringSync(text.isEmpty ? '' : '$text\n');
      for (final e in drop) {
        final f = File('${_records.path}/${e['id']}.jsonl');
        if (f.existsSync()) f.deleteSync();
      }
    });
  }

  Future<void> _load() async {
    if (!_indexFile.existsSync()) return;
    for (final line in _indexFile.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      try {
        final e = (jsonDecode(line) as Map).cast<String, Object?>();
        // A record still open at the last exit never finished.
        if (e['ended_at'] == null) e['outcome'] = 'incomplete';
        _entries['${e['id']}'] = e;
      } on FormatException {
        continue;
      }
    }
    index.value = List.unmodifiable(_entries.values);
  }

  /// Deletes one record (or all with [id] null) from the device.
  Future<void> delete({String? id}) async {
    await flush();
    final ids = id == null ? _entries.keys.toList() : [id];
    for (final i in ids) {
      _entries.remove(i);
      final f = File('${_records.path}/$i.jsonl');
      if (f.existsSync()) f.deleteSync();
    }
    _publishIndex();
  }

  /// The record file's text (for export / clipboard).
  Future<String?> read(String id) async {
    final f = File('${_records.path}/$id.jsonl');
    return f.existsSync() ? f.readAsStringSync() : null;
  }

  /// Synchronous on purpose: lines are small, rare (≤ a few per second)
  /// and development-only, and a record survives the app being killed.
  void _write(void Function() write) {
    try {
      write();
    } on FileSystemException catch (e) {
      debugPrint('[nexa qa] write failed: ${e.message}');
    }
  }

  // ----------------------------------------------------------- redaction

  static final _secretKey = RegExp(
    'token|authori[sz]ation|secret|password|passwd|api_?key|jwt|cookie|'
    'signature|private',
    caseSensitive: false,
  );
  static final _secretValue = RegExp(
    r'nxs_[A-Za-z0-9_\-]+'
    r'|[Bb]earer\s+\S+'
    r'|eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]*'
    r'|(access_token|token)=[^&\s]+',
  );
  static const _contentKeys = {'text', 'transcript', 'body', 'content'};

  /// Scalars only, secrets removed, content only with the session opt-in.
  static Map<String, Object?> _redact(
    Map<String, Object?> data, {
    required bool content,
  }) {
    final out = <String, Object?>{};
    data.forEach((key, value) {
      if (_secretKey.hasMatch(key)) return;
      if (_contentKeys.contains(key) && !content) return;
      final v = switch (value) {
        null || bool() || num() => value,
        final String s => s.replaceAll(_secretValue, '[REDACTED]'),
        _ => value.runtimeType.toString(),
      };
      out[key] = v;
    });
    return out;
  }

  /// Exposed for the redaction test.
  @visibleForTesting
  static Map<String, Object?> redactForTest(
    Map<String, Object?> data, {
    bool content = false,
  }) => _redact(data, content: content);

  static String _stamp(DateTime t) =>
      '${t.year}${_pad2(t.month)}${_pad2(t.day)}-${_pad2(t.hour)}${_pad2(t.minute)}'
      '${_pad2(t.second)}';
  static String _pad2(int v) => v.toString().padLeft(2, '0');
  static String _hex(int bytes) {
    final rnd = Random.secure();
    return [
      for (var i = 0; i < bytes; i++)
        rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}

final class _Record {
  _Record({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.file,
    required this.label,
    required this.contentCapture,
  });

  final String id;
  final String type;
  final DateTime startedAt;
  final File file;
  final String? label;
  final bool contentCapture;
  final Stopwatch watch = Stopwatch()..start();
  final List<QaLine> lines = [];
  String? sessionId;
  String? outcome;
  DateTime? endedAt;
  bool closed = false;

  Map<String, Object?> toIndex() {
    final summary = closed ? QaAnalysis.of(lines).summary() : null;
    return {
      'id': id,
      'type': type,
      'session_id': sessionId,
      'label': label,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'outcome': closed ? outcome : 'in_progress',
      'content_capture': contentCapture,
      'warnings': summary?['warnings'],
      'errors': summary?['errors'],
      'metrics': summary,
      'file': 'records/$id.jsonl',
    };
  }
}
