// DEVELOPMENT ONLY. Pure Dart (no Flutter imports): shared by the in-app QA
// recorder (index metrics) and the desktop CLI `tool/qa.dart` (reports).

import 'dart:math' as math;

/// One line of a QA record file (`records/<id>.jsonl`).
final class QaLine {
  const QaLine(this.tMs, this.wall, this.event, this.data);

  factory QaLine.fromJson(Map<String, Object?> json) => QaLine(
    (json['t_ms'] as num?)?.toInt() ?? 0,
    json['wall'] as String? ?? '',
    json['ev'] as String? ?? '',
    (json['d'] as Map?)?.cast<String, Object?>() ?? const {},
  );

  /// Monotonic milliseconds since the record started.
  final int tMs;

  /// Wall clock (UTC, informational only).
  final String wall;
  final String event;
  final Map<String, Object?> data;

  Object? operator [](String key) => data[key];
}

/// Facts and heuristics derived from one QA record. [facts] are measured;
/// [hypotheses] are rule-based guesses and always labelled as such.
final class QaAnalysis {
  QaAnalysis._(this.lines);

  factory QaAnalysis.of(List<QaLine> lines) => QaAnalysis._(lines).._run();

  final List<QaLine> lines;

  late final Map<String, Object?> meta;
  late final String type;
  final Map<String, Object?> metrics = {};
  final List<String> timeline = [];
  final List<String> warnings = [];
  final List<String> errors = [];
  final List<String> missing = [];
  final List<String> hypotheses = [];
  final List<Map<String, Object?>> turns = [];

  /// One entry per barge-in attempt (and per agent-side interruption the
  /// client did not see as an attempt), see [_bargeIns].
  final List<Map<String, Object?>> bargeIns = [];
  final List<Map<String, Object?>> http = [];

  /// Final user/assistant texts, only when the record captured content.
  final List<({String speaker, String text})> transcript = [];
  bool contentCaptured = false;

  Iterable<QaLine> _named(String event) => lines.where((l) => l.event == event);
  QaLine? _first(String event, [bool Function(QaLine)? where]) {
    for (final l in lines) {
      if (l.event == event && (where == null || where(l))) return l;
    }
    return null;
  }

  void _run() {
    final start = _first('qa.record_started');
    meta = start?.data ?? const {};
    type = meta['type'] as String? ?? 'unknown';
    contentCaptured = meta['content_capture'] == true;
    metrics['duration_ms'] = lines.isEmpty ? 0 : lines.last.tMs;
    _http();
    _timeline();
    if (type == 'voice') {
      _voice();
    } else {
      _chat();
    }
    _app();
  }

  // ---------------------------------------------------------------- http

  void _http() {
    for (final l in _named('http.request')) {
      http.add(l.data);
      final status = l['status'] as int?;
      if (status == null || status >= 400) {
        errors.add(
          'HTTP ${l['method']} ${l['path']} → ${status ?? l['dio_error']}'
          '${l['error_code'] == null ? '' : ' (${l['error_code']})'}'
          ' request_id=${l['request_id']}',
        );
      }
    }
    metrics['http_requests'] = http.length;
    metrics['http_failures'] = http
        .where((h) => (h['status'] as int? ?? 0) >= 400 || h['status'] == null)
        .length;
  }

  // ------------------------------------------------------------ timeline

  static const _quiet = {
    'voice.audio_stats',
    'voice.active_speakers',
    'chat.assistant_first_delta',
  };

  void _timeline() {
    for (final l in lines) {
      if (_quiet.contains(l.event)) continue;
      final d = Map.of(l.data)..remove('text');
      final detail = switch (l.event) {
        'voice.phase' => '${d['from']} → ${d['to']}',
        'voice.agent_event' =>
          '${d['type']} seq=${d['seq']}'
              '${d['mono_ms'] == null ? '' : ' agent_mono=${d['mono_ms']}'}'
              '${d['is_final'] == true ? ' final' : ''}',
        'http.request' =>
          '${d['method']} ${d['path']} → ${d['status'] ?? d['dio_error']} '
              '${d['ms']} ms',
        _ =>
          d.entries
              .where((e) => e.value != null)
              .map((e) => '${e.key}=${e.value}')
              .join(' '),
      };
      timeline.add('${_fmt(l.tMs)}  ${l.event.padRight(28)} $detail');
    }
  }

  // ---------------------------------------------------------------- chat

  void _chat() {
    final started = _first('session.started');
    metrics['session_id'] = started?['session_id'] ?? meta['session_id'];
    metrics['session_start_ms'] = started?['ms'];
    final failed = _first('session.start_failed');
    if (failed != null) {
      errors.add(
        'session start failed: ${failed['error']} '
        '(${failed['server_code'] ?? '-'})',
      );
    }
    final notGranted = started?['not_granted'] as String?;
    if (notGranted != null && notGranted.isNotEmpty) {
      warnings.add('capabilities not granted: $notGranted');
    }

    QaLine? pending;
    Map<String, Object?>? turn;
    for (final l in lines) {
      switch (l.event) {
        case 'chat.send':
          pending = l;
          turn = {
            'client_message_id': l['client_message_id'],
            'text_len': l['text_len'],
          };
          turns.add(turn);
          if (l['text'] is String) {
            transcript.add((speaker: 'user', text: l['text']! as String));
          }
        case 'chat.send_accepted' when turn != null:
          turn['send_http_ms'] = l['ms'];
        case 'chat.send_failed' when turn != null:
          turn['send_failed'] = l['error'];
          errors.add('send failed: ${l['error']} (${l['server_code'] ?? '-'})');
        case 'chat.assistant_started' when pending != null && turn != null:
          turn['assistant_started_ms'] = l.tMs - pending.tMs;
        case 'chat.assistant_first_delta' when pending != null && turn != null:
          turn['first_token_ms'] ??= l.tMs - pending.tMs;
        case 'chat.assistant_completed' when pending != null && turn != null:
          turn['total_ms'] = l.tMs - pending.tMs;
          turn['deltas'] = l['deltas'];
          turn['reply_len'] = l['text_len'];
          turn['finish'] = l['finish_reason'];
          if (l['text'] is String) {
            transcript.add((speaker: 'assistant', text: l['text']! as String));
          }
          pending = null;
        case 'chat.assistant_failed':
          errors.add('assistant failed: ${l['error_code']}');
          turn?['failed'] = l['error_code'];
          pending = null;
        case 'chat.stream_failed':
          warnings.add('event stream failed: ${l['error']}');
        case 'chat.reconnect_scheduled':
          warnings.add('event stream reconnect #${l['attempt']}');
        case 'chat.event_gap':
          warnings.add('event gap skipped at ${l['last_applied']}');
      }
    }
    final ttft = [for (final t in turns) t['first_token_ms']].whereType<int>();
    final total = [for (final t in turns) t['total_ms']].whereType<int>();
    metrics['turns'] = turns.length;
    metrics['first_token_ms'] = _stats(ttft);
    metrics['total_reply_ms'] = _stats(total);
    metrics['stream_reconnects'] = _named('chat.reconnect_scheduled').length;
    final single = turns.where((t) => t['deltas'] == 1).length;
    if (single > 0 &&
        single == turns.where((t) => t['deltas'] != null).length) {
      warnings.add(
        'every reply arrived as a single delta: no token streaming from the '
        'backend (first-token time equals total time)',
      );
    }

    missing
      ..add(
        'model/queue time inside the backend: chat events carry no '
        'per-stage timing, so first-token time = network + gateway + GPU '
        'queue + model, not separable from Flutter',
      )
      ..add(
        'server-side receive time of a message (only the HTTP round '
        'trip `send_http_ms` is measured)',
      );

    for (final t in turns) {
      final send = t['send_http_ms'] as int?;
      final first = t['first_token_ms'] as int?;
      if (send != null && send > 3000) {
        hypotheses.add(
          'send round trip $send ms: AWS Backend or network '
          '(the POST only enqueues the message)',
        );
      }
      if (first != null && first > 6000 && (send ?? 0) < 1500) {
        hypotheses.add(
          'first token after $first ms while the POST took '
          '${send ?? '?'} ms: queueing or model latency, most likely GPU '
          'Manager / model side',
        );
      }
    }
  }

  // --------------------------------------------------------------- voice

  void _voice() {
    final startT = _first('voice.start')?.tMs ?? 0;
    final created = _first('voice.created');
    metrics['voice_session_id'] = created?['voice_session_id'];
    metrics['chat_session_id'] = created?['chat_session_id'];
    metrics['permission_ms'] = _first('voice.permission')?['ms'];
    metrics['create_ms'] = created?['ms'];
    metrics['room_connect_ms'] = _first('voice.room_connected')?['ms'];
    final handshake = _first('voice.handshake_done');
    metrics['start_to_handshake_ms'] = handshake == null
        ? null
        : handshake.tMs - startT;
    final listening = _first('voice.phase', (l) => l['to'] == 'listening');
    metrics['start_to_listening_ms'] = listening == null
        ? null
        : listening.tMs - startT;

    final createFailed = _first('voice.create_failed');
    if (createFailed != null) {
      errors.add(
        'voice create failed: ${createFailed['error']} '
        'status=${createFailed['status']} '
        'code=${createFailed['server_code']}',
      );
      hypotheses.add(
        createFailed['server_code'] == 'voice_unavailable'
            ? 'voice_unavailable: no agent/GPU capacity → GPU Manager or AWS '
                  'Backend agent dispatch'
            : 'voice create rejected → AWS Backend (or credential scope)',
      );
    }
    final createMs = created?['ms'] as int?;
    if (createMs != null && createMs > 5000) {
      hypotheses.add(
        'create took $createMs ms (returns after the agent '
        'joined): agent dispatch on AWS Backend / GPU Manager',
      );
    }
    final roomFailed = _first('voice.room_connect_failed');
    if (roomFailed != null) {
      errors.add('LiveKit connect failed (${roomFailed['error']})');
      hypotheses.add(
        'LiveKit join failed: network path to the media server '
        '(firewall/ports) or LiveKit on AWS',
      );
    }

    // Media path.
    final ice = [
      for (final l in _named('voice.ice')) '${l['pc']}:${l['state']}',
    ];
    metrics['ice_states'] = ice.join(' > ');
    // Disconnected/Closed after End is the normal teardown, not a fault.
    final endT =
        _first('voice.ended')?.tMs ??
        _first('voice.teardown_done')?.tMs ??
        lines.last.tMs;
    final iceInCall = [
      for (final l in _named('voice.ice'))
        if (l.tMs < endT) '${l['pc']}:${l['state']}',
    ];
    final pairs = _named('voice.ice_pair').toList();
    if (pairs.isNotEmpty) {
      final p = pairs.last;
      metrics['ice_pair'] =
          '${p['local_type']}/${p['local_protocol']} → '
          '${p['remote_type']}/${p['remote_protocol']}'
          '${p['rtt_ms'] == null ? '' : ' rtt ${p['rtt_ms']} ms'}';
      if (pairs.any(
        (p) => p['local_cgnat'] == true || p['remote_cgnat'] == true,
      )) {
        warnings.add(
          'ICE uses a 100.64/10 address (VPN overlay such as '
          'NetBird): known to drop media (B10)',
        );
        hypotheses.add('media over a VPN overlay → network configuration');
      }
    }
    if (iceInCall.any(
      (s) => s.endsWith('Failed') || s.endsWith('Disconnected'),
    )) {
      warnings.add('ICE left the connected state during the call: $iceInCall');
    }
    metrics['mic_published'] =
        _first('voice.local_track_published', (l) => _isAudio(l)) != null;
    metrics['agent_audio_subscribed'] =
        _first(
          'voice.remote_track_subscribed',
          (l) => l['agent'] == true && _isAudio(l),
        ) !=
        null;
    if (metrics['mic_published'] != true) {
      errors.add('microphone track was never published');
    }
    if (metrics['agent_audio_subscribed'] != true) {
      errors.add('agent audio track was never subscribed');
    }
    _audioStats();

    // Turns (client receipt clock, and the agent clock where sent).
    _voiceTurns();

    // Interruptions, reconnects, network.
    final bargeAttempts = _bargeAttempts().length;
    final interrupted = _agent('interrupted').length;
    metrics['barge_in_attempts'] = bargeAttempts;
    metrics['interruptions_confirmed'] = interrupted;
    _bargeIns();
    if (bargeAttempts > interrupted) {
      warnings.add(
        '$bargeAttempts barge-in attempt(s), $interrupted '
        'confirmed by the agent (`interrupted`)',
      );
    }
    metrics['room_reconnects'] = _named('voice.room_reconnecting').length;
    metrics['recoveries'] = [
      for (final l in _named('voice.recover_done')) l['outcome'],
    ].join(', ');
    final weak = _named(
      'voice.connection_quality',
    ).where((l) => l['quality'] == 'poor' || l['quality'] == 'lost').length;
    final agentWeak = _agent(
      'network_quality',
    ).where((l) => l['weak'] == true).length;
    metrics['weak_network_events'] = weak + agentWeak;
    if (weak + agentWeak > 0) {
      warnings.add('weak network reported: LiveKit $weak, agent $agentWeak');
    }

    for (final l in _named('voice.event_rejected')) {
      errors.add('agent event rejected: ${l['reason']}');
    }
    if (_named('voice.event_gap').isNotEmpty) {
      warnings.add(
        '${_named('voice.event_gap').length} agent event gap(s) '
        '(repaired via resume)',
      );
    }
    for (final l in _agent('error')) {
      errors.add(
        'agent error ${l['code']} component=${l['component']} '
        'retryable=${l['retryable']}',
      );
      hypotheses.add(
        'agent reported `${l['code']}` from '
        '`${l['component'] ?? '?'}` → GPU Manager (STT/LLM/TTS) side',
      );
    }
    for (final l in _named('voice.failed')) {
      errors.add('voice failed: ${l['error']} (${l['server_code'] ?? '-'})');
    }
    if (_first('voice.agent_unresponsive') != null) {
      errors.add('agent never answered the resume handshake');
      hypotheses.add(
        'agent joined but did not answer RPC → GPU Manager / '
        'agent worker',
      );
    }
    final ended = _first('voice.ended');
    metrics['end_reason'] = ended?['reason'];
    final teardown = _first('voice.teardown_done');
    metrics['cleanup_ms'] = teardown?['ms'];
    final delete = http.where(
      (h) => h['method'] == 'DELETE' && '${h['path']}'.contains('/voice/'),
    );
    metrics['delete_status'] = delete.isEmpty ? null : delete.last['status'];
    if (teardown != null && delete.isEmpty) {
      warnings.add('no DELETE recorded for the voice session');
    }
    if (_first('voice.permission', (l) => l['granted'] == false) != null) {
      errors.add('microphone permission denied');
    }
  }

  /// Barge-in evidence for the backend (plan E-04): each attempt (the
  /// client entered `bargeIn`) is matched with the agent's `interrupted`
  /// that followed before the next attempt. Facts only: ids, whether the
  /// reply audio had started, how far into the reply the user spoke, and how
  /// long the agent took to confirm. Nothing is gated or hidden.
  /// Barge-in attempts: the client entered `bargeIn` (older builds, and
  /// speech while thinking) or logged speech during a reply.
  List<QaLine> _bargeAttempts() => [
    ..._named('voice.phase').where(
      (l) =>
          l['to'] == 'bargeIn' ||
          (l['from'] == 'aiSpeaking' && l['to'] == 'userSpeaking'),
    ),
    ..._named('voice.speech_during_reply'),
  ]..sort((a, b) => a.tMs.compareTo(b.tMs));

  void _bargeIns() {
    final audioStarts = _agent('assistant_audio_started').toList();
    final attempts = _bargeAttempts();
    final interrupts = _agent('interrupted').toList();
    final used = <QaLine>{};

    int? sinceAudio(int at) {
      QaLine? last;
      for (final a in audioStarts) {
        if (a.tMs <= at) last = a;
      }
      return last == null ? null : at - last.tMs;
    }

    for (final (i, a) in attempts.indexed) {
      final until = i + 1 < attempts.length ? attempts[i + 1].tMs : null;
      final hit = interrupts
          .where(
            (e) =>
                !used.contains(e) &&
                e.tMs >= a.tMs &&
                (until == null || e.tMs < until),
          )
          .firstOrNull;
      if (hit != null) used.add(hit);
      bargeIns.add({
        'at_ms': a.tMs,
        'confirmed': hit != null,
        'cancel_id': hit?['cancel_id'],
        'by_turn_id': hit?['by_turn_id'],
        'audio_started': hit?['audio_started'],
        'into_reply_ms': sinceAudio(a.tMs),
        'confirm_delay_ms': hit == null ? null : hit.tMs - a.tMs,
      });
    }
    // The agent interrupted without the client having seen an attempt.
    for (final e in interrupts.where((e) => !used.contains(e))) {
      bargeIns.add({
        'at_ms': e.tMs,
        'confirmed': true,
        'cancel_id': e['cancel_id'],
        'by_turn_id': e['by_turn_id'],
        'audio_started': e['audio_started'],
        'into_reply_ms': sinceAudio(e.tMs),
        'confirm_delay_ms': null,
      });
    }
    final confirmed = bargeIns.where((b) => b['confirmed'] == true).length;
    metrics['barge_ins_confirmed'] = confirmed;
    metrics['barge_ins_unconfirmed'] = bargeIns.length - confirmed;
    if (bargeIns.length > confirmed) {
      hypotheses.add(
        '${bargeIns.length - confirmed} speech start(s) during the reply '
        'ended without an `interrupted` event: the agent judged them not to '
        'be an interruption (or the event was lost; check the event gaps)',
      );
    }
    if (bargeIns.isNotEmpty) {
      missing.add(
        'local microphone level at each interruption (the record does not '
        'sample it); needed to tell room noise from the user',
      );
    }
  }

  Iterable<QaLine> _agent(String type) =>
      _named('voice.agent_event').where((l) => l['type'] == type);

  void _audioStats() {
    final samples = _named('voice.audio_stats').toList();
    metrics['audio_samples'] = samples.length;
    if (samples.isEmpty) {
      missing.add('WebRTC stats (sampler did not run)');
      return;
    }
    int? lastIn;
    int? lastOut;
    var inStall = 0;
    var maxInStall = 0;
    var outStall = 0;
    var maxOutStall = 0;
    double maxJitter = 0;
    for (final s in samples) {
      final inP = (s['in_packets'] as num?)?.toInt();
      final outP = (s['out_packets'] as num?)?.toInt();
      if (inP != null && lastIn != null) {
        inStall = inP > lastIn ? 0 : inStall + 1;
        maxInStall = math.max(maxInStall, inStall);
      }
      if (outP != null && lastOut != null) {
        outStall = outP > lastOut ? 0 : outStall + 1;
        maxOutStall = math.max(maxOutStall, outStall);
      }
      lastIn = inP ?? lastIn;
      lastOut = outP ?? lastOut;
      maxJitter = math.max(
        maxJitter,
        (s['in_jitter'] as num?)?.toDouble() ?? 0,
      );
    }
    final last = samples.lastWhere(
      (s) => s['in_packets'] != null,
      orElse: () => samples.last,
    );
    final received = (last['in_packets'] as num?)?.toInt() ?? 0;
    final lost = (last['in_lost'] as num?)?.toInt() ?? 0;
    metrics['inbound_packets'] = received;
    metrics['inbound_lost'] = lost;
    metrics['inbound_loss_pct'] = received + lost == 0
        ? null
        : double.parse((100 * lost / (received + lost)).toStringAsFixed(2));
    metrics['outbound_packets'] = lastOut;
    metrics['max_jitter_ms'] = (maxJitter * 1000).round();
    metrics['max_inbound_stall_samples'] = maxInStall;
    metrics['max_outbound_stall_samples'] = maxOutStall;
    if (maxInStall >= 3) {
      warnings.add('inbound audio stopped for ~$maxInStall s while connected');
      hypotheses.add(
        'agent audio stopped arriving: agent/TTS output (GPU '
        'Manager) or the media path (network); compare with ICE state',
      );
    }
    if (maxOutStall >= 3) {
      warnings.add('microphone packets stopped for ~$maxOutStall s');
      hypotheses.add(
        'outbound audio stalled: device audio capture (Flutter/'
        'OS) or uplink network',
      );
    }
    final loss = metrics['inbound_loss_pct'] as double?;
    if (loss != null && loss > 3) {
      warnings.add('inbound packet loss $loss %');
      hypotheses.add('packet loss above 3 % → network');
    }
  }

  void _voiceTurns() {
    final agentEvents = _named('voice.agent_event').toList();
    final hasMono = agentEvents.any((l) => l['mono_ms'] is num);
    final stageKeys = <String>{
      for (final l in agentEvents)
        for (final k in l.data.keys)
          if (k.endsWith('_ms') && k != 'mono_ms' && k != 'estimated_wait_ms')
            k,
    };
    final audible = _named(
      'voice.inbound_audio',
    ).where((l) => l['audible'] == true).toList();

    Map<String, Object?>? turn;
    QaLine? speechEnd;
    for (final l in agentEvents) {
      final t = l['type'];
      switch (t) {
        case 'user_speech_started':
          // A barge-in resumes the agent's turn id: keep one row per turn.
          final id = l['turn_id'];
          final same = id == null
              ? null
              : turns.where((t) => t['turn_id'] == id).firstOrNull;
          turn = same ?? {'turn_id': id};
          if (same == null) turns.add(turn);
          speechEnd = null;
        case 'user_speech_ended':
          turn ??= {'turn_id': l['turn_id']};
          if (!turns.contains(turn)) turns.add(turn);
          speechEnd = l;
        case 'transcript' when l['is_final'] == true && turn != null:
          _interval(turn, 'stt_final', speechEnd, l);
          if (l['text'] is String) {
            transcript.add((speaker: 'user', text: l['text']! as String));
          }
          turn['transcript_len'] = l['text_len'];
        case 'assistant_thinking' when turn != null:
          _interval(turn, 'thinking', speechEnd, l);
        case 'assistant_audio_started' when turn != null:
          _interval(turn, 'audio_started', speechEnd, l);
          // Only an onset near this turn's audio start counts: the energy
          // detector reports transitions at 1 s resolution.
          final heard = audible
              .where((a) => a.tMs >= l.tMs - 1000 && a.tMs <= l.tMs + 3000)
              .firstOrNull;
          if (heard != null && speechEnd != null) {
            turn['first_audible_client_ms'] = heard.tMs - speechEnd.tMs;
          }
        case 'assistant_text' when l['final'] == true && turn != null:
          if (l['text'] is String) {
            transcript.add((speaker: 'assistant', text: l['text']! as String));
          }
        case 'assistant_turn_ended' when turn != null:
          _interval(turn, 'turn_ended', speechEnd, l);
          turn['end_reason'] = l['reason'];
        case 'interrupted' when turn != null:
          turn['interrupted'] = true;
      }
    }
    metrics['turns'] = turns.length;
    metrics['stt_final_ms'] = _stats(_col('stt_final_client_ms'));
    metrics['speech_end_to_audio_started_ms'] = _stats(
      _col('audio_started_client_ms'),
    );
    metrics['first_audible_ms'] = _stats(_col('first_audible_client_ms'));
    if (hasMono) {
      metrics['agent_stt_final_ms'] = _stats(_col('stt_final_agent_ms'));
      metrics['agent_speech_end_to_audio_ms'] = _stats(
        _col('audio_started_agent_ms'),
      );
    } else {
      missing.add(
        'agent clock (`mono_ms`) on agent events: intervals are '
        'client receipt times only (include network and LiveKit delivery)',
      );
    }
    if (stageKeys.isEmpty) {
      missing.add(
        'STT / LLM / TTS component durations: agent events expose '
        'no per-stage timing fields. Intervals below are between agent '
        'events, not component latencies',
      );
    } else {
      metrics['backend_stage_fields'] = stageKeys.join(', ');
    }
    if (audible.isEmpty) {
      missing.add(
        'audible assistant output was never detected in inbound '
        'audio energy',
      );
    }
    missing.add(
      'time from end of user speech to the agent\'s VAD decision '
      '(`user_speech_ended` is the earliest point the client sees)',
    );

    for (final t in turns) {
      final stt = (t['stt_final_agent_ms'] ?? t['stt_final_client_ms']) as int?;
      final reply =
          (t['audio_started_agent_ms'] ?? t['audio_started_client_ms']) as int?;
      if (stt != null && stt > 2500) {
        hypotheses.add(
          'turn ${t['turn_id'] ?? '?'}: final transcript '
          '$stt ms after speech end → STT on GPU Manager',
        );
      }
      if (stt != null && reply != null && reply - stt > 3500) {
        hypotheses.add(
          'turn ${t['turn_id'] ?? '?'}: ${reply - stt} ms from '
          'final transcript to assistant audio → LLM + TTS first chunk on '
          'GPU Manager',
        );
      }
    }
    if (turns.isEmpty && _first('voice.handshake_done') != null) {
      warnings.add(
        'connected, but the agent reported no user speech: check '
        'microphone level (`mic_level`) and outbound packets',
      );
    }
  }

  static bool _isAudio(QaLine l) => '${l['kind']}'.toLowerCase() == 'audio';

  Iterable<int> _col(String key) =>
      [for (final t in turns) t[key]].whereType<int>();

  static void _interval(
    Map<String, Object?> turn,
    String name,
    QaLine? from,
    QaLine to,
  ) {
    if (from == null) return;
    turn['${name}_client_ms'] = to.tMs - from.tMs;
    final a = from['mono_ms'];
    final b = to['mono_ms'];
    if (a is num && b is num) turn['${name}_agent_ms'] = (b - a).round();
  }

  void _app() {
    final paused = _named(
      'app.lifecycle',
    ).where((l) => l['state'] == 'paused' || l['state'] == 'hidden');
    if (paused.isNotEmpty) {
      warnings.add(
        'app went to background ${paused.length}× during the '
        'session (screen off / app switch)',
      );
    }
    if (meta['outcome'] == 'incomplete') {
      warnings.add(
        'record is incomplete: the app exited before the session '
        'ended',
      );
    }
  }

  // ------------------------------------------------------------- helpers

  static Map<String, int>? _stats(Iterable<int> values) {
    final v = values.toList()..sort();
    if (v.isEmpty) return null;
    return {
      'n': v.length,
      'min': v.first,
      'p50': v[(v.length - 1) ~/ 2],
      'max': v.last,
    };
  }

  static String _fmt(int ms) {
    final s = ms / 1000;
    return '+${s.toStringAsFixed(3).padLeft(8)}s';
  }

  /// Compact metrics for the session index.
  Map<String, Object?> summary() => {
    for (final e in metrics.entries)
      if (e.value != null && e.value != '') e.key: e.value,
    'warnings': warnings.length,
    'errors': errors.length,
  };
}

/// Character error rate of [hypothesis] against the tester's [reference]
/// (Levenshtein distance / reference length), after normalising Arabic
/// diacritics, tatweel, alef/yaa/taa-marbuta variants, punctuation and case.
double characterErrorRate(String reference, String hypothesis) {
  final r = normaliseForCer(reference);
  final h = normaliseForCer(hypothesis);
  if (r.isEmpty) return h.isEmpty ? 0 : 1;
  var prev = List<int>.generate(h.length + 1, (i) => i);
  for (var i = 1; i <= r.length; i++) {
    final cur = List<int>.filled(h.length + 1, 0)..[0] = i;
    for (var j = 1; j <= h.length; j++) {
      final cost = r[i - 1] == h[j - 1] ? 0 : 1;
      cur[j] = math.min(
        math.min(cur[j - 1] + 1, prev[j] + 1),
        prev[j - 1] + cost,
      );
    }
    prev = cur;
  }
  return prev[h.length] / r.length;
}

String normaliseForCer(String s) {
  var out = s
      .toLowerCase()
      .replaceAll(RegExp('[ً-ْٰـ]'), '') // harakat, tatweel
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  out = out.replaceAll(' ', '');
  return out;
}
