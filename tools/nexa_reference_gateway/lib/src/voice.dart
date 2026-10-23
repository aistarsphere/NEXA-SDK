import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:nexa_reference_gateway/src/livekit.dart';
import 'package:nexa_reference_gateway/src/store.dart';

/// Voice provisioning + a scripted **mock agent** for the reference gateway.
///
/// DEVELOPMENT INFRASTRUCTURE. There is no speech model here: once the SDK
/// participant is observed in the room (real signal, via LiveKit's
/// ListParticipants), the mock agent publishes a scripted sequence of signed
/// events through the server data API and, when the `lk` CLI and an audio
/// file are available, joins the room as `nexa-agent` publishing that file so
/// the SDK receives a real remote audio track. The audio is synthetic, not
/// assistant speech.
///
/// Event signing (PROPOSED, mirrors nexa_core `SignedVoiceEvent`):
/// `canonical = "$v|$voiceSessionId|$seq|$type|$issuedAtMs|" + sortedJson(payload)`
/// `sig = base64url(HMAC-SHA256(eventVerificationKey, canonical))`.
final class VoiceSessionState {
  VoiceSessionState({
    required this.id,
    required this.chatSessionId,
    required this.roomName,
    required this.participantIdentity,
    required this.agentIdentity,
    required this.eventKey,
    required this.expiresAt,
  });

  final String id;
  final String chatSessionId;
  final String roomName;
  final String participantIdentity;
  final String agentIdentity;
  final String eventKey;
  final DateTime expiresAt;

  int sequence = 0;
  bool ended = false;
  String? endReason;
  Process? agentProcess;
  Timer? watchdog;

  /// Signed events emitted so far (for tests and diagnostics).
  final List<Map<String, Object?>> emitted = [];
}

final class VoiceOptions {
  const VoiceOptions({
    this.liveKitUrl,
    this.liveKitPublicUrl,
    this.liveKitApiKey = 'devkey',
    this.liveKitApiSecret = 'secret',
    this.grantTtl = const Duration(minutes: 10),
    this.maxDuration = const Duration(minutes: 5),
    this.agentAudioFile,
    this.scriptStep = const Duration(milliseconds: 900),
    this.signEvents = true,
    this.voiceQuotaPerApplication = 20,
  });

  /// Null disables voice provisioning (503 voice_unavailable). Used by the
  /// gateway itself (token minting, Twirp API).
  final Uri? liveKitUrl;

  /// URL handed to clients when it differs from [liveKitUrl], e.g.
  /// `ws://10.0.2.2:7880` for an Android emulator reaching the host.
  final Uri? liveKitPublicUrl;
  final String liveKitApiKey;
  final String liveKitApiSecret;
  final Duration grantTtl;
  final Duration maxDuration;

  /// Ogg/Opus (or other `lk`-publishable) file the mock agent streams.
  final String? agentAudioFile;
  final Duration scriptStep;
  final bool signEvents;
  final int voiceQuotaPerApplication;
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
  final Map<String, int> _voiceQuota = {};
  final Random _random = Random.secure();
  void Function(String)? log;

  String _rand(int n) =>
      List.generate(n, (_) => _random.nextInt(36).toRadixString(36)).join();

  int voiceQuotaRemaining(String applicationId) => _voiceQuota.putIfAbsent(
    applicationId,
    () => options.voiceQuotaPerApplication,
  );

  void resetQuota(String applicationId) =>
      _voiceQuota[applicationId] = options.voiceQuotaPerApplication;

  /// Active voice session for a chat session, if any.
  VoiceSessionState? forChatSession(String chatSessionId) {
    for (final v in sessions.values) {
      if (v.chatSessionId == chatSessionId && !v.ended) return v;
    }
    return null;
  }

  /// Provisions a room-scoped grant. Caller has already authorised the chat
  /// session and checked the `liveVoice` capability.
  Future<Map<String, Object?>> provision(
    SessionState chat, {
    String? text,
  }) async {
    final lk = livekit!;
    final remaining = voiceQuotaRemaining(chat.applicationId);
    final id = 'vs_${_rand(10)}';
    final room = 'nexa-${chat.id}-${_rand(4)}';
    final identity = 'user-${chat.id}';
    const agentIdentity = 'nexa-agent';
    final key = _rand(32);
    final expiresAt = DateTime.now().toUtc().add(options.grantTtl);
    final state = VoiceSessionState(
      id: id,
      chatSessionId: chat.id,
      roomName: room,
      participantIdentity: identity,
      agentIdentity: agentIdentity,
      eventKey: key,
      expiresAt: expiresAt,
    );
    sessions[id] = state;
    _voiceQuota[chat.applicationId] = remaining - 1;
    state.watchdog = Timer(
      options.maxDuration,
      () => end(state, 'max_duration'),
    );
    unawaited(_runMockAgent(state, scenario: text ?? ''));
    return {
      'voice_session_id': id,
      'livekit_url': (options.liveKitPublicUrl ?? lk.url).toString(),
      'participant_token': lk.participantToken(
        room: room,
        identity: identity,
        ttl: options.grantTtl,
      ),
      'room_name': room,
      'participant_identity': identity,
      'agent_identity': agentIdentity,
      'expires_at': expiresAt.toIso8601String(),
      'event_verification_key': ?(options.signEvents ? key : null),
      'event_signature_alg': ?(options.signEvents ? 'HMAC-SHA256' : null),
      'max_duration_seconds': options.maxDuration.inSeconds,
    };
  }

  /// Ends the voice session: stops the mock agent, deletes the room.
  Future<void> end(VoiceSessionState state, String reason) async {
    if (state.ended) return;
    state.ended = true;
    state.endReason = reason;
    state.watchdog?.cancel();
    try {
      await _emit(state, 'session_ending', {'reason': reason});
    } on Object catch (e) {
      log?.call('voice ${state.id}: session_ending not delivered: $e');
    }
    state.agentProcess?.kill();
    state.agentProcess = null;
    final lk = livekit;
    if (lk != null) await lk.deleteRoom(state.roomName);
  }

  Future<void> dispose() async {
    for (final s in sessions.values.toList()) {
      await end(s, 'shutdown');
    }
  }

  /// Signs and publishes one event to the SDK participant.
  Future<Map<String, Object?>> _emit(
    VoiceSessionState state,
    String type,
    Map<String, Object?> payload,
  ) async {
    final event = signEvent(
      voiceSessionId: state.id,
      key: state.eventKey,
      sequence: ++state.sequence,
      type: type,
      payload: payload,
      sign: options.signEvents,
    );
    state.emitted.add(event);
    await livekit!.sendData(
      state.roomName,
      data: utf8.encode(jsonEncode(event)),
      topic: 'nexa.voice',
      destinationIdentities: [state.participantIdentity],
    );
    return event;
  }

  /// Builds (and optionally signs) one wire event. Public so contract tests
  /// can verify compatibility with the SDK's `VoiceEventVerifier` without a
  /// LiveKit room.
  static Map<String, Object?> signEvent({
    required String voiceSessionId,
    required String key,
    required int sequence,
    required String type,
    required Map<String, Object?> payload,
    bool sign = true,
    int? issuedAtMs,
  }) {
    final issuedAt = issuedAtMs ?? DateTime.now().millisecondsSinceEpoch;
    final event = <String, Object?>{
      'v': 1,
      'type': type,
      'seq': sequence,
      'voice_session_id': voiceSessionId,
      'issued_at': issuedAt,
      'payload': payload,
    };
    if (sign) {
      final canonical =
          '1|$voiceSessionId|$sequence|$type|$issuedAt|${canonicalJson(payload)}';
      event['sig'] = base64Url
          .encode(
            Hmac(
              sha256,
              utf8.encode(key),
            ).convert(utf8.encode(canonical)).bytes,
          )
          .replaceAll('=', '');
    }
    return event;
  }

  /// JSON with recursively sorted keys (must match the SDK verifier).
  static String canonicalJson(Object? value) => jsonEncode(_sorted(value));

  static Object? _sorted(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _sorted(value[k])};
    }
    if (value is List) return value.map(_sorted).toList();
    return value;
  }

  /// MOCK AGENT. Waits for the SDK participant to actually join (real
  /// signal), optionally starts `lk` publishing synthetic audio as the agent,
  /// then plays a scripted conversation of signed events.
  Future<void> _runMockAgent(
    VoiceSessionState state, {
    required String scenario,
  }) async {
    final lk = livekit!;
    final deadline = DateTime.now().add(const Duration(seconds: 30));
    var joined = false;
    while (DateTime.now().isBefore(deadline) && !state.ended) {
      try {
        final ids = await lk.listParticipants(state.roomName);
        if (ids.contains(state.participantIdentity)) {
          joined = true;
          break;
        }
      } on Object catch (e) {
        log?.call('voice ${state.id}: listParticipants: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    if (!joined || state.ended) return;
    log?.call('voice ${state.id}: participant joined ${state.roomName}');

    await _startAgentAudio(state);
    Future<void> step([int n = 1]) =>
        Future<void>.delayed(options.scriptStep * n);
    try {
      await _emit(state, 'agent_joined', {'identity': state.agentIdentity});
      await step();
      if (state.ended) return;
      // Greeting turn: the mock "assistant" speaks first.
      await _emit(state, 'assistant_thinking', {});
      await step();
      await _emit(state, 'assistant_speaking_started', {});
      await _emit(state, 'assistant_transcript', {
        'text':
            'Hello from the NEXA reference mock agent. This audio is synthetic.',
        'is_final': true,
      });
      await step(3);
      if (state.ended) return;
      await _emit(state, 'assistant_speaking_ended', {});
      if (scenario.contains('busy')) {
        await _emit(state, 'model_busy', {'estimated_wait_ms': 2000});
        await step(2);
        await _emit(state, 'model_available', {});
      }
      if (scenario.contains('quota')) {
        await step();
        _voiceQuota[_appOf(state)] = 0;
        await _emit(state, 'quota_exceeded', {'quota_kind': 'voice_minutes'});
        await end(state, 'quota_exceeded');
      }
    } on Object catch (e) {
      log?.call('voice ${state.id}: mock agent stopped: $e');
    }
  }

  String _appOf(VoiceSessionState state) =>
      store.sessions[state.chatSessionId]?.applicationId ?? 'unknown';

  /// Handles an intent the SDK published (observed through the room's data
  /// channel is impossible from the server API, so intents are delivered to
  /// the gateway over HTTP by the SDK as well: `POST .../voice/intents`).
  Future<void> onIntent(VoiceSessionState state, String type) async {
    switch (type) {
      case 'interrupt':
        await _emit(state, 'interrupted', {});
        await _emit(state, 'assistant_speaking_ended', {});
      default:
        break;
    }
  }

  Future<void> _startAgentAudio(VoiceSessionState state) async {
    final file = options.agentAudioFile;
    if (file == null || !File(file).existsSync()) return;
    final lkPath = _which('lk');
    if (lkPath == null) {
      log?.call('voice: `lk` CLI not found; agent audio disabled');
      return;
    }
    final lk = livekit!;
    try {
      state.agentProcess = await Process.start(lkPath, [
        'room',
        'join',
        '--url',
        lk.url.toString(),
        '--api-key',
        lk.apiKey,
        '--api-secret',
        lk.apiSecret,
        '--identity',
        state.agentIdentity,
        '--publish',
        file,
        state.roomName,
      ]);
      unawaited(state.agentProcess!.stderr.drain<void>());
      unawaited(state.agentProcess!.stdout.drain<void>());
      log?.call('voice ${state.id}: lk agent publishing $file');
    } on Object catch (e) {
      log?.call('voice ${state.id}: could not start lk: $e');
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
