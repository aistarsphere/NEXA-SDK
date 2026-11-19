// Real NEXA backend voice probe: microphone → LiveKit → agent → speaker.
//
// NOT part of CI. Skips unless an SDK session token is supplied at build time
// from a file OUTSIDE the repository:
//
//   flutter test integration_test/real_backend_voice_test.dart \
//     -d emulator-5554 --dart-define-from-file=$HOME/.nexa/real-voice.json
//
// The file holds NEXA_GATEWAY_URL, NEXA_APP_ID, NEXA_SDK_TOKEN and
// NEXA_SDK_TOKEN_EXPIRES_AT. The token is a short-lived SDK session token
// minted by the host backend; the tenant API key never reaches this device.
//
// Proves, against the real gateway: voice-session API, LiveKit WSS join,
// selected ICE transport, microphone published, agent audio received, signed
// events driving the capsule. It prints evidence; it never prints the token.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:livekit_client/livekit_client.dart' show Room;
import 'package:nexa_realtime/nexa_realtime.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

const _gateway = String.fromEnvironment('NEXA_GATEWAY_URL');
const _appId = String.fromEnvironment('NEXA_APP_ID');
const _token = String.fromEnvironment('NEXA_SDK_TOKEN');
const _expiresAt = String.fromEnvironment('NEXA_SDK_TOKEN_EXPIRES_AT');
const _language = String.fromEnvironment(
  'NEXA_VOICE_LANGUAGE',
  defaultValue: 'ar',
);

/// How long to keep the call open for the conversation.
const _conversationWindow = Duration(seconds: 120);

void _log(String line) => debugPrint('[real-voice] $line');

Future<bool> _until(
  bool Function() condition, {
  required WidgetTester tester,
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (condition()) return true;
  }
  return false;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'real backend: one voice conversation',
    (tester) async {
      if (_token.isEmpty || _gateway.isEmpty || _appId.isEmpty) {
        markTestSkipped('no NEXA_SDK_TOKEN / NEXA_GATEWAY_URL / NEXA_APP_ID');
        return;
      }
      final transport = LiveKitVoiceTransport(logger: const _Logger());
      final client = await Nexa.initialize(
        config: NexaConfig(
          applicationId: _appId,
          gatewayBaseUri: Uri.parse(_gateway),
          environment: NexaEnvironment.staging,
          languageTag: _language,
          requestedCapabilities: const {NexaCapability.liveVoice},
        ),
        auth: _SuppliedTokenAuthProvider(),
        overrides: NexaOverrides(
          voiceTransport: transport,
          permissionHandler: const _PreGranted(), // granted via adb beforehand
          logger: const _Logger(),
        ),
      );
      final v = client.voice;
      final events = <NexaVoiceEvent>[];
      final sub = v.events.listen((e) {
        events.add(e);
        switch (e) {
          case NexaVoicePhaseChanged(:final from, :final to):
            _log('phase ${from.name} -> ${to.name}');
          case NexaVoiceTranscriptUpdated(:final entry) when entry.isFinal:
            _log('transcript ${entry.speaker.name}: ${entry.text}');
          case NexaVoiceErrorOccurred(:final error):
            _log('error $error');
          case NexaVoiceEventRejected(:final reason):
            _log('REJECTED event: $reason');
          case NexaVoiceEnded(:final reason):
            _log('ended: $reason');
          default:
        }
      });

      try {
        await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: client.voiceView())),
        );
        await tester.pumpAndSettle();
        final started = DateTime.now();
        await tester.tap(find.byKey(const Key('nexa_voice_start')));

        final joined = await _until(
          () =>
              v.state.value.phase == VoiceState.listening ||
              v.state.value.phase.isTerminal ||
              v.state.value.phase == VoiceState.disconnected,
          tester: tester,
          timeout: const Duration(seconds: 90),
        );
        final s = v.state.value;
        _log(
          'after start (${DateTime.now().difference(started).inMilliseconds} ms): '
          'phase=${s.phase.name} error=${s.error} endReason=${s.endReason}',
        );
        expect(
          joined && s.phase == VoiceState.listening,
          isTrue,
          reason: 'voice session + LiveKit join: ${s.error}',
        );

        final g = v.currentGrant!;
        _log('API PASS voice_session_id=${g.voiceSessionId}');
        _log(
          'grant livekit.url=${g.liveKitUrl} room=${g.roomName} '
          'identity=${g.participantIdentity} '
          'token_expires_at=${g.tokenExpiresAt.toIso8601String()} '
          'alg=${g.eventAlgorithm.name} max_seconds=${g.maxSeconds}',
        );
        final room = transport.room!;
        _log(
          'LiveKit WSS PASS connectionState=${room.connectionState.name} '
          'serverVersion=${room.serverVersion} region=${room.serverRegion}',
        );

        final mic = await _until(() => v.microphoneEnabled, tester: tester);
        _log('microphone published: $mic');
        final agent = await _until(
          () => v.state.value.agentPresent && v.state.value.agentAudioActive,
          tester: tester,
        );
        _log(
          'agent present + audio track subscribed: $agent '
          '(${room.remoteParticipants.values.map((p) => p.identity).join(',')})',
        );
        await _logIce(room);

        final roomEvents = room.createListener()
          ..listen((e) => _log('room event ${e.runtimeType}'));
        _log('NEXA_PROBE_READY speak now');
        final end = DateTime.now().add(_conversationWindow);
        var nextStats = DateTime.now();
        var spoke = false;
        while (DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 200));
          if (DateTime.now().isAfter(nextStats)) {
            nextStats = DateTime.now().add(const Duration(seconds: 2));
            await _logIce(room, compact: true);
          }
          final st = v.state.value;
          if (st.phase.isTerminal || st.phase == VoiceState.disconnected) break;
          final userFinal = st.transcript.any(
            (t) => t.speaker == VoiceSpeaker.user && t.isFinal,
          );
          final aiSpoke = events.whereType<NexaVoicePhaseChanged>().any(
            (e) => e.from == VoiceState.aiSpeaking,
          );
          if (userFinal && aiSpoke && !spoke) {
            spoke = true;
            _log('full turn observed; collecting 10 s more of stats');
            await _pumpFor(tester, const Duration(seconds: 10));
            break;
          }
        }
        await _logIce(room);
        await roomEvents.dispose();
        final st = v.state.value;
        _log(
          'summary: phase=${st.phase.name} eventsVerified=${st.eventsVerified} '
          'rejected=${st.rejectedEvents} turns=${st.transcript.length} '
          'phases=${events.whereType<NexaVoicePhaseChanged>().map((e) => e.to.name).join('>')}',
        );
        expect(st.rejectedEvents, 0);
        expect(spoke, isTrue, reason: 'user transcript + assistant speech');
      } finally {
        // DELETE before leaving the room, on every exit path.
        await v.end();
        await _until(() => v.state.value.phase.isTerminal, tester: tester);
        _log('end: phase=${v.state.value.phase.name}');
        await sub.cancel();
        await client.dispose();
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _pumpFor(WidgetTester tester, Duration d) async {
  final until = DateTime.now().add(d);
  while (DateTime.now().isBefore(until)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Selected ICE candidate pair and audio counters of both peer connections.
/// [compact]: one line per peer connection (periodic timeline).
Future<void> _logIce(Room room, {bool compact = false}) async {
  // Diagnostics only: the peer connections are LiveKit internals.
  // ignore_for_file: invalid_use_of_internal_member
  final engine = room.engine;
  for (final (name, t) in [
    ('publisher', engine.publisher),
    ('subscriber', engine.subscriber),
  ]) {
    if (t == null) {
      _log('ICE $name: none');
      continue;
    }
    final reports = await t.pc.getStats().timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        _log('ICE $name: getStats timed out');
        return const [];
      },
    );
    if (reports.isEmpty) continue;
    final byId = {for (final r in reports) r.id: r};
    if (compact) {
      String addr(Object? id) {
        final c = byId[id]?.values ?? const {};
        return '${c['candidateType']}:${c['address'] ?? c['ip']}:${c['port']}/${c['protocol']}';
      }

      final tr = reports.where((r) => r.type == 'transport').firstOrNull;
      final pair = byId[tr?.values['selectedCandidatePairId']]?.values;
      final audio = reports
          .where(
            (r) =>
                (r.type == 'inbound-rtp' || r.type == 'outbound-rtp') &&
                r.values['kind'] == 'audio',
          )
          .map((r) => r.values)
          .firstOrNull;
      final src = reports
          .where((r) => r.type == 'media-source' && r.values['kind'] == 'audio')
          .map((r) => r.values)
          .firstOrNull;
      _log(
        'T $name ice=${t.pc.iceConnectionState?.name.replaceAll('RTCIceConnectionState', '')} '
        'pair=${pair == null ? '-' : '${addr(pair['localCandidateId'])}->${addr(pair['remoteCandidateId'])} '
                  'req=${pair['requestsSent']} resp=${pair['responsesReceived']}'} '
        'transport rx=${tr?.values['bytesReceived']} tx=${tr?.values['bytesSent']} '
        'audio pkts=${audio?['packetsReceived'] ?? audio?['packetsSent']} '
        'energy=${audio?['totalAudioEnergy']}'
        '${src == null ? '' : ' mic_level=${src['audioLevel']} mic_energy=${src['totalAudioEnergy']}'}',
      );
      continue;
    }
    _log('ICE $name iceConnectionState=${t.pc.iceConnectionState?.name}');
    for (final r in reports) {
      final v = r.values;
      if (r.type == 'candidate-pair' &&
          v['state'] == 'succeeded' &&
          (v['nominated'] == true || v['selected'] == true)) {
        final l = byId[v['localCandidateId']]?.values ?? const {};
        final rm = byId[v['remoteCandidateId']]?.values ?? const {};
        _log(
          'ICE $name selected pair: '
          'local ${l['candidateType']} ${l['address'] ?? l['ip']}:${l['port']} '
          '${l['protocol']}${l['relayProtocol'] == null ? '' : ' relay=${l['relayProtocol']}'} '
          '-> remote ${rm['candidateType']} ${rm['address'] ?? rm['ip']}:${rm['port']} '
          '${rm['protocol']} rtt=${v['currentRoundTripTime']}',
        );
      }
      if (r.type == 'inbound-rtp' && v['kind'] == 'audio') {
        _log(
          'ICE $name inbound audio: packets=${v['packetsReceived']} '
          'bytes=${v['bytesReceived']} lost=${v['packetsLost']} '
          'energy=${v['totalAudioEnergy']} level=${v['audioLevel']}',
        );
      }
      if (r.type == 'outbound-rtp' && v['kind'] == 'audio') {
        _log(
          'ICE $name outbound audio: packets=${v['packetsSent']} '
          'bytes=${v['bytesSent']}',
        );
      }
    }
  }
}

/// Development-only: forwards the token supplied at build time. A real host
/// fetches a fresh token from its own backend instead.
final class _SuppliedTokenAuthProvider implements NexaAuthProvider {
  @override
  Future<SessionCredential> fetchSessionCredential() async => SessionCredential(
    token: _token,
    expiresAt: _expiresAt.isEmpty
        ? DateTime.now().add(const Duration(minutes: 30))
        : DateTime.parse(_expiresAt),
    scopes: const {'voice:session'},
  );
}

final class _PreGranted implements NexaPermissionHandler {
  const _PreGranted();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

final class _Logger implements NexaLogger {
  const _Logger();
  @override
  void log(
    NexaLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => debugPrint(
    '[nexa ${level.name}] $message${error == null ? '' : ' $error'}',
  );
}
