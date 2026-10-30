// NEXA QA diagnostics CLI (development only). Run from apps/nexa_example:
//
//   dart run tool/qa.dart pull [--device <serial>]   copy records from the Android phone
//   dart run tool/qa.dart pull --ios [--device <udid>]  … from the iPhone (devicectl)
//   dart run tool/qa.dart list                       recent sessions
//   dart run tool/qa.dart report <id|latest|latest-voice|latest-chat> [--json] [--full]
//   dart run tool/qa.dart note <id> --expected "phrase" [--expected …] [--feedback "…"]
//   dart run tool/qa.dart delete <id>|--all [--device <serial>]
//   dart run tool/qa.dart path                       local store location
//
// <id> is a record id (or unique prefix) or the SDK session id (ses_… / vs_…).
// Records are copied to ~/.nexa/qa/<device>/ (outside the repository).
// Development builds only (Android: adb run-as; iPhone: xcrun devicectl).
// Records never contain tokens.

import 'dart:convert';
import 'dart:io';

import 'package:nexa_example/dev/qa/qa_analysis.dart';

const _package = 'com.nexa.nexa_example';
const _deviceDir = 'app_flutter/nexa_qa';
const _iosBundle = 'com.nexa.nexaExample';

Future<void> main(List<String> args) async {
  if (args.isEmpty) return _usage();
  final rest = args.sublist(1);
  try {
    switch (args.first) {
      case 'pull' when rest.contains('--ios'):
        await _pullIos(_opt(rest, '--device'));
      case 'pull':
        await _pull(_opt(rest, '--device'));
      case 'list':
        _list();
      case 'report':
        _report(rest);
      case 'note':
        _note(rest);
      case 'delete':
        await _delete(rest);
      case 'path':
        stdout.writeln(_storeRoot().path);
      default:
        _usage();
    }
  } on _Blocker catch (e) {
    stderr.writeln('BLOCKER: ${e.message}');
    exitCode = 2;
  }
}

void _usage() {
  stdout.writeln(
    File.fromUri(Platform.script)
        .readAsLinesSync()
        .takeWhile((l) {
          return l.startsWith('//');
        })
        .map((l) => l.replaceFirst(RegExp('^// ?'), ''))
        .join('\n'),
  );
}

final class _Blocker implements Exception {
  const _Blocker(this.message);
  final String message;
}

// ------------------------------------------------------------------ store

Directory _storeRoot() => Directory('${Platform.environment['HOME']}/.nexa/qa');

/// The most recently pulled device store (or the one named by NEXA_QA_DIR).
Directory _store() {
  final override = Platform.environment['NEXA_QA_DIR'];
  if (override != null) return Directory(override);
  final root = _storeRoot();
  if (!root.existsSync()) {
    throw const _Blocker('no local records. Run `dart run tool/qa.dart pull`.');
  }
  final dirs = root.listSync().whereType<Directory>().toList()
    ..sort(
      (a, b) => File('${b.path}/index.jsonl').statSyncOrZero().compareTo(
        File('${a.path}/index.jsonl').statSyncOrZero(),
      ),
    );
  if (dirs.isEmpty) {
    throw const _Blocker('no local records. Run `dart run tool/qa.dart pull`.');
  }
  return dirs.first;
}

extension on File {
  int statSyncOrZero() =>
      existsSync() ? lastModifiedSync().millisecondsSinceEpoch : 0;
}

List<Map<String, Object?>> _index(Directory store) {
  final f = File('${store.path}/index.jsonl');
  if (!f.existsSync()) return const [];
  return [
    for (final l in f.readAsLinesSync())
      if (l.trim().isNotEmpty) (jsonDecode(l) as Map).cast<String, Object?>(),
  ];
}

Map<String, Object?> _resolve(Directory store, String key) {
  final entries = _index(store);
  if (entries.isEmpty) throw const _Blocker('the index is empty.');
  if (key.startsWith('latest')) {
    final type = key == 'latest' ? null : key.replaceFirst('latest-', '');
    final match = entries.where((e) => type == null || e['type'] == type);
    if (match.isEmpty) throw _Blocker('no $type record.');
    return match.last;
  }
  final hits = entries.where(
    (e) => '${e['id']}'.startsWith(key) || e['session_id'] == key,
  );
  if (hits.isEmpty) throw _Blocker('no record matches "$key".');
  if (hits.length > 1) {
    throw _Blocker(
      '"$key" is ambiguous: ${hits.map((e) => e['id']).join(', ')}',
    );
  }
  return hits.single;
}

List<QaLine> _lines(Directory store, Map<String, Object?> entry) {
  final f = File('${store.path}/${entry['file']}');
  if (!f.existsSync()) {
    throw _Blocker('record file missing: ${f.path} (pull again?)');
  }
  return [
    for (final l in f.readAsLinesSync())
      if (l.trim().isNotEmpty)
        QaLine.fromJson((jsonDecode(l) as Map).cast<String, Object?>()),
  ];
}

// ------------------------------------------------------------------- adb

Future<String> _device(String? requested) async {
  final r = await Process.run('adb', ['devices']);
  if (r.exitCode != 0) {
    throw const _Blocker('adb is not available (install platform-tools).');
  }
  final lines = '${r.stdout}'
      .split('\n')
      .skip(1)
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);
  final ready = [
    for (final l in lines)
      if (l.endsWith('\tdevice')) l.split('\t').first,
  ];
  final other = [
    for (final l in lines)
      if (!l.endsWith('\tdevice')) l,
  ];
  if (requested != null) {
    if (!ready.contains(requested)) {
      throw _Blocker(
        'device $requested is not connected/authorised '
        '(adb: ${other.isEmpty ? 'not listed' : other.join(', ')}).',
      );
    }
    return requested;
  }
  if (ready.isEmpty) {
    throw _Blocker(
      'no Android device connected'
      '${other.isEmpty ? '' : ' (${other.join(', ')}: unlock the phone and '
                'accept USB debugging)'}.',
    );
  }
  if (ready.length > 1) {
    throw _Blocker('several devices: pass --device (${ready.join(', ')}).');
  }
  return ready.single;
}

Future<String> _runAs(String device, List<String> command) async {
  final r = await Process.run('adb', [
    '-s',
    device,
    'exec-out',
    'run-as',
    _package,
    ...command,
  ], stdoutEncoding: utf8);
  if (r.exitCode != 0 || '${r.stdout}'.startsWith('run-as:')) {
    throw _Blocker(
      'cannot read the app sandbox (${'${r.stderr}${r.stdout}'.trim()}). '
      'Needs a debug build of $_package installed on $device.',
    );
  }
  return '${r.stdout}';
}

Future<void> _pull(String? requested) async {
  final device = await _device(requested);
  final index = await _runAs(device, ['cat', '$_deviceDir/index.jsonl']);
  if (index.contains('No such file')) {
    throw const _Blocker(
      'no QA records on the device yet (run a chat or voice session in a '
      'development build first).',
    );
  }
  final store = Directory('${_storeRoot().path}/$device');
  Directory('${store.path}/records').createSync(recursive: true);
  File('${store.path}/index.jsonl').writeAsStringSync(index);
  var copied = 0;
  for (final e in _index(store)) {
    final local = File('${store.path}/${e['file']}');
    // Closed records never change: skip ones already pulled.
    if (local.existsSync() && e['ended_at'] != null) continue;
    local.writeAsStringSync(
      await _runAs(device, ['cat', '$_deviceDir/${e['file']}']),
    );
    copied++;
  }
  final model = await Process.run('adb', [
    '-s',
    device,
    'shell',
    'getprop ro.product.model; getprop ro.build.version.release',
  ]);
  final props = '${model.stdout}'.trim().split('\n');
  File('${store.path}/device.json').writeAsStringSync(
    jsonEncode({
      'serial': device,
      'model': props.isNotEmpty ? props.first.trim() : null,
      'android': props.length > 1 ? props[1].trim() : null,
      'pulled_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );
  _chmodPrivate(store);
  stdout.writeln(
    'pulled ${_index(store).length} record(s), $copied file(s) → ${store.path}',
  );
  _list(store);
}

/// iPhone: copies `Documents/nexa_qa` out of the app's data container.
Future<void> _pullIos(String? requested) async {
  final list = await Process.run('xcrun', [
    'devicectl',
    'list',
    'devices',
    '--json-output',
    '/dev/stdout',
    '-q',
  ]);
  String? udid;
  String? model;
  final unavailable = <String>[];
  if (list.exitCode == 0) {
    final out = '${list.stdout}';
    final json = (jsonDecode(out.substring(out.indexOf('{'))) as Map)
        .cast<String, Object?>();
    final devices = ((json['result'] as Map?)?['devices'] as List?) ?? const [];
    for (final d in devices.cast<Map<String, dynamic>>()) {
      final hw = (d['hardwareProperties'] as Map?) ?? const {};
      final conn = (d['connectionProperties'] as Map?) ?? const {};
      if (hw['reality'] != 'physical' || hw['platform'] != 'iOS') continue;
      final id = '${hw['udid']}';
      if (requested != null && requested != id) continue;
      if (conn['tunnelState'] == 'unavailable' ||
          conn['pairingState'] != 'paired') {
        unavailable.add(id);
        continue;
      }
      udid = id;
      model = '${hw['marketingName'] ?? hw['productType']}';
      break;
    }
  }
  if (udid == null) {
    throw _Blocker(
      unavailable.isEmpty
          ? 'no physical iPhone found.'
          : 'iPhone(s) ${unavailable.join(', ')} unavailable: unlock, connect '
                'the cable, trust this Mac and enable Developer Mode.',
    );
  }
  final tmp = Directory.systemTemp.createTempSync('nexa_qa_ios_');
  try {
    final r = await Process.run('xcrun', [
      'devicectl',
      'device',
      'copy',
      'from',
      '--device',
      udid,
      '--domain-type',
      'appDataContainer',
      '--domain-identifier',
      _iosBundle,
      '--source',
      'Documents/nexa_qa',
      '--destination',
      tmp.path,
      '-q',
    ]);
    if (r.exitCode != 0) {
      throw _Blocker(
        'could not copy from the iPhone app container '
        '(${'${r.stderr}'.trim().split('\n').last}). Needs a development '
        'build of $_iosBundle that has recorded at least one session.',
      );
    }
    final found = [tmp, ...tmp.listSync(recursive: true).whereType<Directory>()]
        .firstWhere(
          (d) => File('${d.path}/index.jsonl').existsSync(),
          orElse: () =>
              throw const _Blocker('no QA records on the iPhone yet.'),
        );
    final store = Directory('${_storeRoot().path}/$udid');
    Directory('${store.path}/records').createSync(recursive: true);
    File('${found.path}/index.jsonl').copySync('${store.path}/index.jsonl');
    final records = Directory('${found.path}/records');
    if (records.existsSync()) {
      for (final f in records.listSync().whereType<File>()) {
        f.copySync('${store.path}/records/${f.uri.pathSegments.last}');
      }
    }
    File('${store.path}/device.json').writeAsStringSync(
      jsonEncode({
        'serial': udid,
        'model': model,
        'platform': 'iOS',
        'pulled_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    _chmodPrivate(store);
    stdout.writeln('pulled ${_index(store).length} record(s) → ${store.path}');
    _list(store);
  } finally {
    tmp.deleteSync(recursive: true);
  }
}

void _chmodPrivate(Directory dir) {
  Process.runSync('chmod', ['-R', 'go-rwx', _storeRoot().path]);
}

Future<void> _delete(List<String> rest) async {
  final all = rest.contains('--all');
  final id = rest.where((a) => !a.startsWith('--')).firstOrNull;
  if (!all && id == null) return _usage();
  final store = _store();
  final targets = all ? _index(store) : [_resolve(store, id!)];
  final device = await _device(_opt(rest, '--device'));
  for (final e in targets) {
    await _runAs(device, ['rm', '-f', '$_deviceDir/${e['file']}']);
    final local = File('${store.path}/${e['file']}');
    if (local.existsSync()) local.deleteSync();
    final note = File('${store.path}/notes/${e['id']}.json');
    if (note.existsSync()) note.deleteSync();
  }
  if (all) {
    await _runAs(device, ['rm', '-f', '$_deviceDir/index.jsonl']);
    File('${store.path}/index.jsonl').writeAsStringSync('');
  }
  stdout.writeln(
    'deleted ${targets.length} record file(s) locally and on $device. '
    '${all ? '' : 'The app drops the index entry when it next rewrites the index (or delete from the app).'}',
  );
}

// ------------------------------------------------------------------ list

void _list([Directory? dir]) {
  final store = dir ?? _store();
  final entries = _index(store).reversed.take(20);
  stdout.writeln(
    '${'record'.padRight(38)} ${'session'.padRight(26)} '
    '${'outcome'.padRight(24)} warn err  key metric',
  );
  for (final e in entries) {
    final m = (e['metrics'] as Map?)?.cast<String, Object?>() ?? const {};
    final key = e['type'] == 'voice'
        ? 'listening ${m['start_to_listening_ms'] ?? '-'} ms, '
              'turns ${m['turns'] ?? 0}'
        : 'first token p50 '
              '${(m['first_token_ms'] as Map?)?['p50'] ?? '-'} ms, '
              'turns ${m['turns'] ?? 0}';
    stdout.writeln(
      '${'${e['id']}'.padRight(38)} ${'${e['session_id'] ?? '-'}'.padRight(26)} '
      '${'${e['outcome']}'.padRight(24)} ${'${e['warnings'] ?? '-'}'.padLeft(4)} '
      '${'${e['errors'] ?? '-'}'.padLeft(3)}  $key'
      '${e['label'] == null ? '' : '  [${e['label']}]'}',
    );
  }
}

// ------------------------------------------------------------------ note

void _note(List<String> rest) {
  final id = rest.where((a) => !a.startsWith('--')).firstOrNull;
  if (id == null) return _usage();
  final store = _store();
  final entry = _resolve(store, id);
  final expected = <String>[];
  String? feedback;
  for (var i = 0; i < rest.length - 1; i++) {
    if (rest[i] == '--expected') expected.add(rest[i + 1]);
    if (rest[i] == '--feedback') feedback = rest[i + 1];
  }
  final f = File('${store.path}/notes/${entry['id']}.json')
    ..parent.createSync(recursive: true);
  final old = f.existsSync()
      ? (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>()
      : <String, Object?>{};
  f.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'expected': [...?(old['expected'] as List?)?.cast<String>(), ...expected],
      'feedback': feedback ?? old['feedback'],
      'noted_at': DateTime.now().toUtc().toIso8601String(),
    }),
  );
  stdout.writeln('ground truth saved → ${f.path}');
}

// ---------------------------------------------------------------- report

void _report(List<String> rest) {
  final key = rest.where((a) => !a.startsWith('--')).firstOrNull ?? 'latest';
  final store = _store();
  final entry = _resolve(store, key);
  final a = QaAnalysis.of(_lines(store, entry));
  final noteFile = File('${store.path}/notes/${entry['id']}.json');
  final note = noteFile.existsSync()
      ? (jsonDecode(noteFile.readAsStringSync()) as Map).cast<String, Object?>()
      : null;
  final device = File('${store.path}/device.json').existsSync()
      ? jsonDecode(File('${store.path}/device.json').readAsStringSync())
      : null;
  final accuracy = _accuracy(a, note);

  if (rest.contains('--json')) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'record': entry,
        'device': device,
        'metrics': a.metrics,
        'turns': a.turns,
        'http': a.http,
        'warnings': a.warnings,
        'errors': a.errors,
        'missing_instrumentation': a.missing,
        'hypotheses': a.hypotheses,
        'accuracy': accuracy,
        'feedback': note?['feedback'],
      }),
    );
    return;
  }

  final out = StringBuffer();
  void h(String title) => out
    ..writeln()
    ..writeln('## $title');
  final meta = a.meta;
  out
    ..writeln('# QA report ${entry['id']}')
    ..writeln(
      'type ${a.type} · session ${entry['session_id'] ?? '-'} · outcome '
      '${entry['outcome']} · label ${entry['label'] ?? '-'}',
    )
    ..writeln(
      'started ${entry['started_at']} · duration '
      '${((a.metrics['duration_ms'] as int? ?? 0) / 1000).toStringAsFixed(1)} s · '
      'run ${meta['run_id']}',
    )
    ..writeln(
      'app ${meta['app_id']} ${meta['app_version']} (${meta['build_mode']}) · '
      'sdk ${meta['sdk_version']} · ${meta['platform']} ${meta['os_version']}'
      '${device == null ? '' : ' · ${(device as Map)['model']}${device['android'] == null ? '' : ' Android ${device['android']}'}'}'
      ' · backend ${meta['backend']} (${meta['gateway_host']})',
    )
    ..writeln(
      'All numbers below are MEASURED on the device unless marked '
      'HYPOTHESIS. Client times are receipt times (monotonic).',
    );

  h('Timeline');
  final full = rest.contains('--full');
  final tl = a.timeline;
  final shown = full || tl.length <= 80
      ? tl
      : [
          ...tl.take(60),
          '  … ${tl.length - 75} more (use --full)',
          ...tl.skip(tl.length - 15),
        ];
  shown.forEach(out.writeln);

  h('API and connection health');
  for (final r in a.http) {
    out.writeln(
      '  ${'${r['method']}'.padRight(6)} ${'${r['path']}'.padRight(58)} '
      '${'${r['status'] ?? r['dio_error']}'.padLeft(4)} ${'${r['ms']}'.padLeft(5)} ms'
      '${r['stream'] == true ? ' (to headers)' : ''}'
      '${r['error_code'] == null ? '' : ' code=${r['error_code']}'}'
      '  req=${r['request_id']}'
      '${r['server_request_id'] == null ? '' : ' srv=${r['server_request_id']}'}',
    );
  }
  if (a.http.isEmpty) out.writeln('  (no requests)');

  h('Latency (measured)');
  const latencyKeys = [
    'session_start_ms',
    'first_token_ms',
    'total_reply_ms',
    'permission_ms',
    'create_ms',
    'room_connect_ms',
    'start_to_handshake_ms',
    'start_to_listening_ms',
    'stt_final_ms',
    'speech_end_to_audio_started_ms',
    'first_audible_ms',
    'agent_stt_final_ms',
    'agent_speech_end_to_audio_ms',
    'cleanup_ms',
  ];
  for (final k in latencyKeys) {
    if (a.metrics[k] != null) out.writeln('  $k: ${a.metrics[k]}');
  }
  if (a.turns.isNotEmpty) {
    out.writeln('  per turn:');
    for (final t in a.turns) {
      out.writeln('    ${Map.of(t)..removeWhere((_, v) => v == null)}');
    }
  }

  if (a.type == 'voice') {
    h('Audio transport');
    for (final k in [
      'ice_states',
      'ice_pair',
      'mic_published',
      'agent_audio_subscribed',
      'audio_samples',
      'inbound_packets',
      'inbound_lost',
      'inbound_loss_pct',
      'max_jitter_ms',
      'outbound_packets',
      'max_inbound_stall_samples',
      'max_outbound_stall_samples',
    ]) {
      out.writeln('  $k: ${a.metrics[k] ?? '-'}');
    }
    h('Interruptions and reconnects');
    for (final k in [
      'barge_in_attempts',
      'interruptions_confirmed',
      'room_reconnects',
      'recoveries',
      'weak_network_events',
      'end_reason',
      'delete_status',
    ]) {
      out.writeln('  $k: ${a.metrics[k] ?? '-'}');
    }
  } else {
    h('Stream');
    out.writeln('  stream_reconnects: ${a.metrics['stream_reconnects']}');
  }

  h('Errors and suspicious events');
  for (final e in a.errors) {
    out.writeln('  ERROR  $e');
  }
  for (final w in a.warnings) {
    out.writeln('  WARN   $w');
  }
  if (a.errors.isEmpty && a.warnings.isEmpty) out.writeln('  none');

  h('Missing instrumentation (not measurable from Flutter)');
  for (final m in a.missing) {
    out.writeln('  - $m');
  }

  h('Likely ownership (HYPOTHESIS, rule-based)');
  for (final x in a.hypotheses) {
    out.writeln('  ? $x');
  }
  if (a.hypotheses.isEmpty) out.writeln('  no rule fired');

  h('Accuracy (tester ground truth)');
  out.writeln('  ${accuracy['status']}');
  for (final p in (accuracy['pairs'] as List? ?? const [])) {
    final m = p as Map;
    out
      ..writeln('  expected: ${m['expected']}')
      ..writeln('  heard   : ${m['heard'] ?? '(no transcript)'}')
      ..writeln('  CER     : ${m['cer'] ?? '-'}');
  }
  if (note?['feedback'] != null) {
    out.writeln('  tester feedback: ${note!['feedback']}');
  }
  stdout.write(out);
}

Map<String, Object?> _accuracy(QaAnalysis a, Map<String, Object?>? note) {
  final expected = (note?['expected'] as List?)?.cast<String>() ?? const [];
  final heard = [
    for (final t in a.transcript)
      if (t.speaker == 'user') t.text,
  ];
  if (expected.isEmpty) {
    return {
      'status':
          'no ground truth attached (tool/qa.dart note <id> --expected '
          '"…"). No accuracy is claimed.',
    };
  }
  if (!a.contentCaptured) {
    return {
      'status':
          'transcripts were not captured for this session (opt-in '
          'was off), so accuracy cannot be computed.',
    };
  }
  final pairs = [
    for (var i = 0; i < expected.length; i++)
      {
        'expected': expected[i],
        'heard': i < heard.length ? heard[i] : null,
        'cer': i < heard.length
            ? characterErrorRate(expected[i], heard[i]).toStringAsFixed(3)
            : null,
      },
  ];
  return {
    'status':
        'character error rate of the final user transcripts against '
        'the tester\'s phrases, paired in order (${expected.length} expected, '
        '${heard.length} final transcripts)',
    'pairs': pairs,
  };
}

String? _opt(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}
