import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:nexa_core/nexa_core.dart';
import 'package:pinenacl/ed25519.dart' as nacl;
import 'package:test/test.dart';

const handoff = '../../docs/contracts/voice-v1/handoff-1.0.0-4cd5247';

/// Signs events with the backend's PUBLISHED TEST seed (protects nothing),
/// exactly as event-verification.md describes.
final class TestSigner {
  TestSigner(this.voiceSessionId) {
    final vectors =
        jsonDecode(
              File(
                '$handoff/fixtures/verification/test_vectors.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final seed = VoiceGrant.decodeBase64Url(
      vectors['test_seed_base64url']! as String,
    );
    _key = nacl.SigningKey.fromSeed(seed);
    publicKeyB64 = vectors['public_key_base64url']! as String;
  }

  final String voiceSessionId;
  late final nacl.SigningKey _key;
  late final String publicKeyB64;

  Uint8List get publicKey => Uint8List.fromList(_key.verifyKey.asTypedList);

  String envelope(
    int seq,
    String type, [
    Map<String, Object?> extra = const {},
  ]) {
    final e = jsonEncode({
      'v': voiceContractV1,
      'type': type,
      'seq': seq,
      'event_id': 'vev_$seq',
      'voice_session_id': voiceSessionId,
      'occurred_at': '2026-10-24T12:00:00.000Z',
      ...extra,
    });
    final message = Uint8List.fromList([
      ...utf8.encode('$voiceContractV1\u0000'),
      ...utf8.encode(e),
    ]);
    final sig = _key.sign(message).signature.asTypedList;
    final hex = sig.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return jsonEncode({'e': e, 'sig': hex, 'alg': 'ed25519'});
  }
}

void main() {
  late TestSigner signer;
  late List<RealtimeVoiceEvent> out;
  late int resumeRequests;
  late VoiceEventPipeline pipeline;

  setUp(() {
    signer = TestSigner('vs_PIPE');
    out = [];
    resumeRequests = 0;
    pipeline = VoiceEventPipeline(
      grant: VoiceGrant(
        voiceSessionId: 'vs_PIPE',
        liveKitUrl: Uri.parse('wss://lk'),
        roomName: 'nexa-vs_PIPE',
        participantIdentity: 'nexa-user-vs_PIPE',
        participantToken: 't',
        tokenExpiresAt: DateTime.now().add(const Duration(seconds: 60)),
        eventAlgorithm: VoiceEventAlgorithm.ed25519,
        eventKey: signer.publicKey,
        maxSeconds: 60,
      ),
      emit: out.add,
      requestResume: () => resumeRequests++,
    )..beginConnection();
  });

  test('the published test seed derives the published public key', () {
    expect(
      base64Url.encode(signer.publicKey).replaceAll('=', ''),
      signer.publicKeyB64,
    );
  });

  test(
    'agent_ready completes the handshake once, then events map in order',
    () {
      pipeline
        ..onPacket(signer.envelope(1, 'agent_ready', {'state': 'listening'}))
        ..onPacket(signer.envelope(2, 'session_state', {'state': 'listening'}))
        ..onPacket(
          signer.envelope(3, 'user_speech_started', {'turn_id': 'turn_1'}),
        );
      expect(out.map((e) => e.runtimeType), [
        RealtimeConnected,
        RealtimeAgentReady,
        RealtimeSessionSnapshot,
        RealtimeUserSpeechStarted,
      ]);
      expect(pipeline.isConnected, isTrue);
      expect(pipeline.lastApplied, 3);
    },
  );

  test(
    'duplicates are dropped silently; a gap requests resume and holds events',
    () {
      pipeline
        ..onPacket(signer.envelope(1, 'agent_ready'))
        ..onPacket(signer.envelope(1, 'agent_ready'))
        ..onPacket(
          signer.envelope(3, 'user_speech_ended', {'turn_id': 'turn_1'}),
        );
      expect(resumeRequests, 1);
      expect(pipeline.lastApplied, 1);
      expect(
        out.whereType<RealtimeUserSpeechEnded>(),
        isEmpty,
        reason: 'nothing past a gap',
      );
      pipeline.onPacket(
        signer.envelope(2, 'user_speech_started', {'turn_id': 'turn_1'}),
      );
      expect(pipeline.lastApplied, 3);
      expect(out.skip(2).map((e) => e.runtimeType), [
        RealtimeUserSpeechStarted,
        RealtimeUserSpeechEnded,
      ]);
    },
  );

  test(
    'resume answer: verifies entries, completes handshake, reports has_more',
    () {
      final more = pipeline.onResumeResponse(
        jsonEncode({
          'state': 'thinking',
          'last_seq': 2,
          'covers': true,
          'has_more': true,
          'events': [
            signer.envelope(1, 'agent_ready'),
            signer.envelope(2, 'assistant_thinking', {'turn_id': 'turn_1'}),
          ],
        }),
      );
      expect(more, isTrue);
      expect(pipeline.lastApplied, 2);
      expect(out.whereType<RealtimeConnected>().length, 1);
      expect(out.whereType<RealtimeAssistantThinking>().length, 1);
      expect(
        (out.whereType<RealtimeSessionSnapshot>().single).state,
        'thinking',
      );
    },
  );

  test('covers:false jumps the cursor to last_seq and relies on state', () {
    pipeline.onPacket(signer.envelope(1, 'agent_ready'));
    pipeline.onPacket(
      signer.envelope(400, 'network_quality', {
        'weak': true,
        'quality': 'poor',
      }),
    );
    expect(pipeline.lastApplied, 1);
    pipeline.onResumeResponse(
      jsonEncode({
        'state': 'listening',
        'last_seq': 399,
        'covers': false,
        'has_more': false,
        'events': <String>[],
      }),
    );
    expect(
      pipeline.lastApplied,
      400,
      reason: 'held 400 released after the jump',
    );
    expect(out.whereType<RealtimeNetworkQuality>().single.weak, isTrue);
  });

  test(
    'forged / wrong-session / unknown-type packets are rejected and never applied',
    () {
      final other = TestSigner('vs_OTHER');
      pipeline
        ..onPacket('}{')
        ..onPacket(other.envelope(1, 'agent_ready'))
        ..onPacket(signer.envelope(1, 'agent_mood'));
      final forged = jsonDecode(signer.envelope(1, 'agent_ready')) as Map;
      forged['e'] = (forged['e'] as String).replaceAll(
        'agent_ready',
        'session_ended',
      );
      pipeline.onPacket(jsonEncode(forged));
      expect(out.whereType<RealtimeEventRejected>().length, 4);
      expect(out.whereType<RealtimeConnected>(), isEmpty);
      expect(pipeline.lastApplied, 0);
    },
  );

  test(
    'assistant_text chunks fold per turn in index order; turn end resets',
    () {
      pipeline
        ..onPacket(signer.envelope(1, 'agent_ready'))
        ..onPacket(
          signer.envelope(2, 'assistant_text', {
            'turn_id': 'turn_1',
            'text': 'world',
            'index': 1,
            'final': false,
          }),
        )
        ..onPacket(
          signer.envelope(3, 'assistant_text', {
            'turn_id': 'turn_1',
            'text': 'Hello ',
            'index': 0,
            'final': true,
          }),
        )
        ..onPacket(
          signer.envelope(4, 'assistant_turn_ended', {
            'turn_id': 'turn_1',
            'reason': 'completed',
          }),
        )
        ..onPacket(
          signer.envelope(5, 'assistant_text', {
            'turn_id': 'turn_2',
            'text': 'Next',
            'index': 0,
            'final': true,
          }),
        );
      final captions = out.whereType<RealtimeAssistantTranscript>().toList();
      expect(captions.map((c) => c.text), ['world', 'Hello world', 'Next']);
      expect(captions[1].isFinal, isTrue);
    },
  );

  test('a rejoin re-handshakes but keeps the seq cursor', () {
    pipeline.onPacket(signer.envelope(1, 'agent_ready'));
    pipeline.beginConnection();
    expect(pipeline.isConnected, isFalse);
    pipeline.onPacket(signer.envelope(1, 'agent_ready')); // old seq: dropped
    expect(out.whereType<RealtimeConnected>().length, 1);
    pipeline.onPacket(
      signer.envelope(2, 'session_state', {'state': 'listening'}),
    );
    expect(out.whereType<RealtimeConnected>().length, 2);
  });
}
