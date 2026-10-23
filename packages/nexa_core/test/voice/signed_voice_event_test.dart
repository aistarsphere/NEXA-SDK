import 'package:clock/clock.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

Map<String, Object?> event({
  required int seq,
  String type = 'assistant_speaking_started',
  String session = 'vs_1',
  Map<String, Object?> payload = const {},
  int? issuedAt,
  String? key = 'k',
  int version = 1,
}) {
  final issued = issuedAt ?? clock.now().millisecondsSinceEpoch;
  final e = <String, Object?>{
    'v': version,
    'type': type,
    'seq': seq,
    'voice_session_id': session,
    'issued_at': issued,
    'payload': payload,
  };
  if (key != null) {
    e['sig'] = SignedVoiceEvent.sign(
      key,
      '$version|$session|$seq|$type|$issued|${SignedVoiceEvent.canonicalJson(payload)}',
    );
  }
  return e;
}

void main() {
  group('VoiceEventVerifier', () {
    late VoiceEventVerifier v;
    setUp(() => v = VoiceEventVerifier(voiceSessionId: 'vs_1', key: 'k'));

    test('accepts a correctly signed, fresh, in-order event', () {
      final verdict = v.verify(event(seq: 1));
      expect(verdict, isA<VoiceEventAccepted>());
      expect((verdict as VoiceEventAccepted).verified, isTrue);
      expect(v.lastSequence, 1);
    });

    test('payload key order does not affect the signature', () {
      final a = event(
        seq: 1,
        payload: {
          'b': 1,
          'a': {'y': 2, 'x': 1},
        },
      );
      final b = event(
        seq: 2,
        payload: {
          'a': {'x': 1, 'y': 2},
          'b': 1,
        },
      );
      expect(v.verify(a), isA<VoiceEventAccepted>());
      expect(v.verify(b), isA<VoiceEventAccepted>());
    });

    test('rejects a bad signature', () {
      final e = event(seq: 1)..['sig'] = 'AAAA';
      final r = v.verify(e) as VoiceEventRejected;
      expect(r.reason, VoiceEventRejection.badSignature);
    });

    test('rejects a tampered payload', () {
      final e = event(seq: 1, payload: {'text': 'hi'});
      (e['payload']! as Map<String, Object?>)['text'] = 'bye';
      expect(
        (v.verify(e) as VoiceEventRejected).reason,
        VoiceEventRejection.badSignature,
      );
    });

    test('rejects a missing signature when a key was issued', () {
      expect(
        (v.verify(event(seq: 1, key: null)) as VoiceEventRejected).reason,
        VoiceEventRejection.missingSignature,
      );
    });

    test('rejects replayed and stale sequences', () {
      expect(v.verify(event(seq: 2)), isA<VoiceEventAccepted>());
      expect(
        (v.verify(event(seq: 2)) as VoiceEventRejected).reason,
        VoiceEventRejection.duplicateOrStaleSequence,
      );
      expect(
        (v.verify(event(seq: 1)) as VoiceEventRejected).reason,
        VoiceEventRejection.duplicateOrStaleSequence,
      );
      expect(v.verify(event(seq: 3)), isA<VoiceEventAccepted>());
    });

    test('rejects events for another voice session', () {
      expect(
        (v.verify(event(seq: 1, session: 'vs_other')) as VoiceEventRejected)
            .reason,
        VoiceEventRejection.wrongSession,
      );
    });

    test('rejects events outside the clock-skew window', () {
      final old = clock.now().millisecondsSinceEpoch - 10 * 60 * 1000;
      expect(
        (v.verify(event(seq: 1, issuedAt: old)) as VoiceEventRejected).reason,
        VoiceEventRejection.clockSkew,
      );
      expect(v.lastSequence, 0, reason: 'rejected events do not advance');
    });

    test('rejects malformed envelopes and unsupported versions', () {
      expect(
        (v.verify({'type': 'x'}) as VoiceEventRejected).reason,
        VoiceEventRejection.malformed,
      );
      expect(
        (v.verify('nope') as VoiceEventRejected).reason,
        VoiceEventRejection.malformed,
      );
      expect(
        (v.verify(event(seq: 1, version: 2)) as VoiceEventRejected).reason,
        VoiceEventRejection.unsupportedVersion,
      );
    });

    test(
      'without a key, unsigned events are accepted but marked unverified',
      () {
        final dev = VoiceEventVerifier(voiceSessionId: 'vs_1');
        final r = dev.verify(event(seq: 1, key: null)) as VoiceEventAccepted;
        expect(r.verified, isFalse);
      },
    );
  });

  group('realtimeEventFromSigned', () {
    SignedVoiceEvent signed(String type, [Map<String, Object?> p = const {}]) =>
        SignedVoiceEvent.tryParse(event(seq: 1, type: type, payload: p))!;

    test('maps every documented agent event type', () {
      expect(
        realtimeEventFromSigned(signed('agent_joined', {'identity': 'a'})),
        isA<RealtimeAgentJoined>(),
      );
      expect(
        realtimeEventFromSigned(signed('user_speech_started')),
        isA<RealtimeUserSpeechStarted>(),
      );
      expect(
        realtimeEventFromSigned(signed('user_speech_ended')),
        isA<RealtimeUserSpeechEnded>(),
      );
      final t =
          realtimeEventFromSigned(
                signed('transcript', {'text': 'hi', 'is_final': true}),
              )
              as RealtimeTranscript;
      expect(t.isFinal, isTrue);
      expect(
        realtimeEventFromSigned(signed('assistant_transcript', {'text': 'x'})),
        isA<RealtimeAssistantTranscript>(),
      );
      expect(
        realtimeEventFromSigned(signed('assistant_thinking')),
        isA<RealtimeAssistantThinking>(),
      );
      expect(
        realtimeEventFromSigned(signed('assistant_speaking_started')),
        isA<RealtimeAssistantSpeakingStarted>(),
      );
      expect(
        realtimeEventFromSigned(signed('assistant_speaking_ended')),
        isA<RealtimeAssistantSpeakingEnded>(),
      );
      expect(
        realtimeEventFromSigned(signed('interrupted')),
        isA<RealtimeInterrupted>(),
      );
      final busy =
          realtimeEventFromSigned(
                signed('model_busy', {'estimated_wait_ms': 1500}),
              )
              as RealtimeModelBusy;
      expect(busy.estimatedWait, const Duration(milliseconds: 1500));
      expect(
        realtimeEventFromSigned(signed('model_available')),
        isA<RealtimeModelAvailable>(),
      );
      final q =
          realtimeEventFromSigned(
                signed('quota_exceeded', {'quota_kind': 'voice_minutes'}),
              )
              as RealtimeQuotaExceeded;
      expect(q.quotaKind, 'voice_minutes');
      expect(
        realtimeEventFromSigned(signed('session_ending', {'reason': 'max'})),
        isA<RealtimeSessionEnding>(),
      );
    });

    test('unknown types map to null (ignored, forward compatible)', () {
      expect(realtimeEventFromSigned(signed('agent_mood_changed')), isNull);
    });
  });

  group('VoiceGrant', () {
    test('redacts secrets in toString and reports expiry', () {
      final g = VoiceGrant(
        voiceSessionId: 'vs',
        liveKitUrl: Uri.parse('ws://x'),
        participantToken: 'SECRET_TOKEN',
        roomName: 'r',
        participantIdentity: 'u',
        expiresAt: clock.now().subtract(const Duration(seconds: 1)),
        eventVerificationKey: 'SECRET_KEY',
      );
      expect(g.toString(), isNot(contains('SECRET')));
      expect(g.isExpired, isTrue);
    });
  });
}
