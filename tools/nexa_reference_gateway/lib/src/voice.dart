import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:nexa_reference_gateway/src/livekit.dart';
import 'package:nexa_reference_gateway/src/store.dart';
import 'package:pinenacl/ed25519.dart' as nacl;

/// Contract id mirrored from the backend handoff 1.0.0.
const voiceContractV1 = 'nexa.voice.v1';

/// Voice API `nexa.voice.v1` + a scripted **mock agent** for the reference
/// gateway. DEVELOPMENT INFRASTRUCTURE; mirrors the backend handoff 1.0.0
/// (`docs/contracts/voice-v1/handoff-1.0.0-4cd5247`) closely enough to run
/// the SDK end to end, with these documented differences:
///
/// * no `nexa.voice.resume` RPC: the server-side data API cannot answer
///   RPCs, so the SDK's handshake completes on the signed `agent_ready` /
///   `session_state` packets (allowed by the compatibility matrix §A);
/// * the "agent" is not a pipeline: events are scripted and, when the `lk`
///   CLI and an audio file are available, a participant with the agent
///   identity publishes a synthetic tone;
/// * dev-only endpoints simulate server-side ends (`agent_lost`, `revoked`).
final class VoiceSessionState {
  VoiceSessionState({
    required this.id,
    required this.applicationId,
    required this.subject,
    required this.languageTag,
    required this.signingKey,
    required this.maxSeconds,
  });

  final String id;
  final String applicationId;

  /// The token holder (stand-in for the backend's subject).
  final String subject;
  final String languageTag;
  final nacl.SigningKey signingKey;
  final int maxSeconds;

  String get roomName => 'nexa-$id';
  String get participantIdentity => 'nexa-user-$id';
  String get agentIdentity => 'nexa-agent-$id';

  String status = 'provisioning';
  String agentState = 'joined';
  String? endReason;
  int seq = 0;
  int refreshes = 0;
  DateTime? startedAt;
  Process? agentProcess;
  Timer? capTimer;

  /// Envelopes published so far (for tests and diagnostics).
  final List<String> sealed = [];

  String get publicKeyB64 =>
      base64Url.encode(signingKey.verifyKey.asTypedList).replaceAll('=', '');

  Map<String, Object?> statusJson() => {
    'voice_session_id': id,
    'status': status,
    'end_reason': endReason,
    'max_seconds': maxSeconds,
    'reserved_seconds': maxSeconds,
    'used_seconds': status == 'ended' ? _used() : null,
    'language_tag': languageTag,
    'agent_state': agentState,
    if (status == 'active') 'remaining_seconds': max(0, maxSeconds - _used()),
  };

  int _used() {
    final s = startedAt;
    if (s == null) return 0;
    return min(maxSeconds, DateTime.now().difference(s).inSeconds);
  }
}

final class VoiceOptions {
  const VoiceOptions({
    this.liveKitUrl,
    this.liveKitPublicUrl,
    this.liveKitApiKey = 'devkey',
    this.liveKitApiSecret = 'secret',
    this.joinTokenTtl = const Duration(seconds: 60),
    this.maxSeconds = 600,
    this.agentAudioFile,
    this.scriptStep = const Duration(milliseconds: 900),
    this.voiceSecondsPerApplication = 3600,
    this.maxRefreshes = 30,
    this.graceSeconds = 30,
  });

  /// Null disables voice (`403 capability_not_granted`).
  final Uri? liveKitUrl;

  /// URL handed to clients when it differs (Android emulator: 10.0.2.2).
  final Uri? liveKitPublicUrl;
  final String liveKitApiKey;
  final String liveKitApiSecret;
  final Duration joinTokenTtl;
  final int maxSeconds;
  final String? agentAudioFile;
  final Duration scriptStep;
  final int voiceSecondsPerApplication;
  final int maxRefreshes;
  final int graceSeconds;
}

final class VoiceService {
  VoiceService(this.options, this.store)
    : livekit = options.liveKitUrl == null
          ? null
          : LiveKitDev(
              url: options.liveKitUrl!,
              apiKey: options.liveKitApiKey,
              apiSecret: options.liveKitApiSecret,
            );

  final VoiceOptions options;
  final GatewayStore store;
  final LiveKitDev? livekit;
  final Map<String, VoiceSessionState> sessions = {};
  final Map<String, int> _secondsLeft = {};
  final Random _random = Random.secure();
  void Function(String)? log;

  /// When true, the next create fails with `503 voice_unavailable`
  /// (no agent capacity) — for tests.
  bool failNextCreate = false;

  String _rand(int n) =>
      List.generate(n, (_) => _random.nextInt(36).toRadixString(36)).join();

  int secondsLeft(String applicationId) => _secondsLeft.putIfAbsent(
    applicationId,
    () => options.voiceSecondsPerApplication,
  );

  void resetQuota(String applicationId) =>
      _secondsLeft[applicationId] = options.voiceSecondsPerApplication;

  void setQuota(String applicationId, int seconds) =>
      _secondsLeft[applicationId] = seconds;

  VoiceSessionState? liveFor(String subject) {
    for (final v in sessions.values) {
      if (v.subject == subject && v.status != 'ended') return v;
    }
    return null;
  }

  Uri get _clientUrl => options.liveKitPublicUrl ?? livekit!.url;

  Map<String, Object?> _livekitBlock(VoiceSessionState s) => {
    'url': _clientUrl.toString(),
    'room': s.roomName,
    'identity': s.participantIdentity,
    'token': livekit!.participantToken(
      room: s.roomName,
      identity: s.participantIdentity,
      ttl: options.joinTokenTtl,
    ),
    'token_expires_at': DateTime.now()
        .toUtc()
        .add(options.joinTokenTtl)
        .toIso8601String(),
  };

  /// `POST /v1/sdk/voice/sessions` body (201). Caller authorised the token,
  /// scope, capability, quota and concurrency.
  Future<Map<String, Object?>> create({
    required String applicationId,
    required String subject,
    required String languageTag,
    String scenario = '',
  }) async {
    final left = secondsLeft(applicationId);
    final maxSeconds = min(options.maxSeconds, left);
    final seed = Uint8List.fromList(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    final s = VoiceSessionState(
      id: 'vs_${_rand(12)}',
      applicationId: applicationId,
      subject: subject,
      languageTag: languageTag,
      signingKey: nacl.SigningKey.fromSeed(seed),
      maxSeconds: maxSeconds,
    );
    sessions[s.id] = s;
    _secondsLeft[applicationId] = left - maxSeconds; // reserved
    unawaited(_runMockAgent(s, scenario: scenario));
    return {
      'voice_session_id': s.id,
      'contract': voiceContractV1,
      'livekit': _livekitBlock(s),
      'events': {
        'topic': 'nexa.voice.events',
        'resume_rpc': 'nexa.voice.resume',
        'format': 'sealed',
        'alg': 'ed25519',
        'public_key': s.publicKeyB64,
      },
      'limits': {'max_seconds': maxSeconds, 'reserved_seconds': maxSeconds},
      'reconnect': {
        'grace_seconds': options.graceSeconds,
        'token_refresh_path': '/v1/sdk/voice/sessions/${s.id}/token',
        'max_refreshes': options.maxRefreshes,
      },
      'join_deadline_seconds': 60,
    };
  }

  Map<String, Object?> refresh(VoiceSessionState s) {
    s.refreshes++;
    return {'voice_session_id': s.id, 'livekit': _livekitBlock(s)};
  }

  /// Ends the session server-side: settles quota, deletes the room (which
  /// disconnects the client without any event). Idempotent.
  Future<void> end(
    VoiceSessionState s,
    String reason, {
    String agentState = 'ended',
  }) async {
    if (s.status == 'ended') return;
    s.status = 'ended';
    s.endReason = reason;
    s.agentState = agentState;
    s.capTimer?.cancel();
    s.agentProcess?.kill();
    s.agentProcess = null;
    final used = s.statusJson()['used_seconds']! as int;
    _secondsLeft[s.applicationId] =
        secondsLeft(s.applicationId) + (s.maxSeconds - used); // refund
    final lk = livekit;
    if (lk != null) await lk.deleteRoom(s.roomName);
  }

  Future<void> dispose() async {
    for (final s in sessions.values.toList()) {
      await end(s, 'room_closed');
    }
  }

  // ---------------------------------------------------------- signing

  /// Seals one event exactly as event-verification.md specifies.
  static String seal(nacl.SigningKey key, Map<String, Object?> event) {
    final e = jsonEncode(event);
    final message = Uint8List.fromList([
      ...utf8.encode('$voiceContractV1\u0000'),
      ...utf8.encode(e),
    ]);
    final sig = key.sign(message).signature.asTypedList;
    final hex = sig.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return jsonEncode({'e': e, 'sig': hex, 'alg': 'ed25519'});
  }

  Future<void> _emit(
    VoiceSessionState s,
    String type, [
    Map<String, Object?> fields = const {},
  ]) async {
    final seq = ++s.seq;
    final envelope = seal(s.signingKey, {
      'v': voiceContractV1,
      'type': type,
      'seq': seq,
      'event_id': 'vev_${s.id}_$seq',
      'voice_session_id': s.id,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
      'mono_ms': DateTime.now().millisecondsSinceEpoch,
      ...fields,
    });
    s.sealed.add(envelope);
    await livekit!.sendData(
      s.roomName,
      data: utf8.encode(envelope),
      topic: 'nexa.voice.events',
      destinationIdentities: [s.participantIdentity],
    );
  }

  // ---------------------------------------------------------- mock agent

  /// Waits for the user to join (real signal from LiveKit), then plays a
  /// scripted session. NOT a model.
  Future<void> _runMockAgent(
    VoiceSessionState s, {
    required String scenario,
  }) async {
    final lk = livekit!;
    await _startAgentAudio(s);
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    var joined = false;
    while (DateTime.now().isBefore(deadline) && s.status != 'ended') {
      try {
        final ids = await lk.listParticipants(s.roomName);
        if (ids.contains(s.participantIdentity)) {
          joined = true;
          break;
        }
      } on Object catch (e) {
        log?.call('voice ${s.id}: listParticipants: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    if (s.status == 'ended') return;
    if (!joined) {
      await end(s, 'join_timeout');
      return;
    }
    s.status = 'active';
    s.startedAt = DateTime.now();
    s.capTimer = Timer(Duration(seconds: s.maxSeconds), () async {
      await _emit(s, 'quota_exceeded', {'quota_kind': 'voice_seconds'});
      await _emit(s, 'session_ended', {'reason': 'quota_exceeded'});
    });
    log?.call('voice ${s.id}: user joined ${s.roomName}');
    final ar = s.languageTag == 'ar';
    Future<void> step([int n = 1]) =>
        Future<void>.delayed(options.scriptStep * n);
    try {
      await _emit(s, 'agent_ready', {
        'state': 'listening',
        'capabilities': {
          'stt': {'streaming': false, 'interim_results': false},
          'llm': {'token_streaming': false},
          'tts': {'streaming_audio': false},
        },
      });
      await _emit(s, 'session_state', {
        'state': 'listening',
        'current_turn_id': null,
        'last_seq': s.seq,
        'elapsed_s': 0,
        'max_seconds': s.maxSeconds,
      });
      await _emit(s, 'network_quality', {
        'weak': false,
        'quality': 'excellent',
      });
      await step();
      if (s.status == 'ended') return;
      // One scripted turn (as if the user had asked something).
      const t = {'turn_id': 'turn_1'};
      await _emit(s, 'user_speech_started', t);
      await _emit(s, 'user_speech_ended', t);
      await _emit(s, 'transcript', {
        ...t,
        'text': ar ? 'شكد الساعة؟' : 'what time is it',
        'is_final': true,
        'language': s.languageTag,
      });
      await _emit(s, 'assistant_thinking', t);
      await step();
      await _emit(s, 'assistant_audio_started', t);
      await _emit(s, 'assistant_text', {
        ...t,
        'text': ar
            ? 'هذا رد تجريبي من الوكيل الوهمي. الصوت مصطنع.'
            : 'This is a mock reply from the reference agent. The audio is synthetic.',
        'index': 0,
        'final': true,
      });
      await step(3);
      if (s.status == 'ended') return;
      await _emit(s, 'assistant_turn_ended', {...t, 'reason': 'completed'});
      if (scenario.contains('busy')) {
        await _emit(s, 'model_busy', {
          'turn_id': 'turn_2',
          'estimated_wait_ms': 2000,
        });
        await step(2);
        await _emit(s, 'model_available', {'turn_id': 'turn_2'});
      }
      if (scenario.contains('quota')) {
        await step();
        await _emit(s, 'quota_exceeded', {'quota_kind': 'voice_seconds'});
        await _emit(s, 'session_ended', {'reason': 'quota_exceeded'});
      }
    } on Object catch (e) {
      log?.call('voice ${s.id}: mock agent stopped: $e');
    }
  }

  Future<void> _startAgentAudio(VoiceSessionState s) async {
    final file = options.agentAudioFile;
    if (file == null || !File(file).existsSync()) return;
    final lkPath = _which('lk');
    if (lkPath == null) {
      log?.call('voice: `lk` CLI not found; agent audio disabled');
      return;
    }
    final lk = livekit!;
    try {
      s.agentProcess = await Process.start(lkPath, [
        'room',
        'join',
        '--url',
        lk.url.toString(),
        '--api-key',
        lk.apiKey,
        '--api-secret',
        lk.apiSecret,
        '--identity',
        s.agentIdentity,
        '--publish',
        file,
        s.roomName,
      ]);
      unawaited(s.agentProcess!.stderr.drain<void>());
      unawaited(s.agentProcess!.stdout.drain<void>());
    } on Object catch (e) {
      log?.call('voice ${s.id}: could not start lk: $e');
    }
  }

  static String? _which(String name) {
    for (final dir in (Platform.environment['PATH'] ?? '').split(':')) {
      final f = File('$dir/$name');
      if (f.existsSync()) return f.path;
    }
    for (final p in ['/opt/homebrew/bin/$name', '/usr/local/bin/$name']) {
      if (File(p).existsSync()) return p;
    }
    return null;
  }
}
