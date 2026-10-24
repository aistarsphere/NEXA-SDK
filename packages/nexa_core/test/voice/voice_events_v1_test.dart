// Consumer contract tests for backend handoff 1.0.0 (contract nexa.voice.v1).
// Fixtures are the backend's files, vendored byte-for-byte under
// docs/contracts/voice-v1/handoff-1.0.0-4cd5247 (hashes checked below).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:test/test.dart';

const handoff = '../../docs/contracts/voice-v1/handoff-1.0.0-4cd5247';

Map<String, Object?> readJson(String path) =>
    jsonDecode(File('$handoff/$path').readAsStringSync())
        as Map<String, Object?>;

/// Replaces documented placeholders with concrete values (README of the
/// handoff: `vs_<id>`, `<number>`, `<iso8601-utc>` ...).
Object? concretize(Object? v, {String id = 'vs_FIXTURE01'}) {
  if (v is Map) {
    return {
      for (final e in v.entries) e.key as String: concretize(e.value, id: id),
    };
  }
  if (v is List) return v.map((x) => concretize(x, id: id)).toList();
  if (v == '<number>') return 7;
  if (v is String) {
    return v
        .replaceAll('vs_<id>', id)
        .replaceAll('vev_<id>', 'vev_fixture')
        .replaceAll('<iso8601-utc>', '2026-10-24T12:00:00.000Z');
  }
  return v;
}

void main() {
  group('handoff integrity', () {
    test('every vendored file matches MANIFEST.json sha256', () {
      final manifest = readJson('MANIFEST.json');
      expect(manifest['wire_contract'], voiceContractV1);
      expect(manifest['contains_secrets'], isFalse);
      final files = (manifest['files']! as Map).cast<String, String>();
      expect(files.length, 32);
      for (final entry in files.entries) {
        final digest = sha256
            .convert(File('$handoff/${entry.key}').readAsBytesSync())
            .toString();
        expect(digest, entry.value, reason: entry.key);
      }
    });
  });

  group('event verification (fixtures/verification/test_vectors.json)', () {
    final vectors = readJson('fixtures/verification/test_vectors.json');
    final key = VoiceGrant.decodeBase64Url(
      vectors['public_key_base64url']! as String,
    );
    final sessionId = vectors['voice_session_id']! as String;
    VoiceEventVerifier verifier() => VoiceEventVerifier(
      voiceSessionId: sessionId,
      algorithm: VoiceEventAlgorithm.ed25519,
      key: key,
    );

    test('public key decodes to 32 bytes', () {
      expect(key.length, 32);
      expect((vectors['public_key_base64url']! as String).length, 43);
    });

    test('valid envelopes verify and decode to the published events', () {
      final v = verifier();
      final valid = (vectors['valid_envelopes']! as List).cast<String>();
      final expected = (vectors['events_after_verification']! as List)
          .cast<Map<String, Object?>>();
      for (var i = 0; i < valid.length; i++) {
        final verdict = v.verifyText(valid[i]);
        expect(verdict, isA<VoiceEventAuthentic>(), reason: '$verdict');
        final event = (verdict as VoiceEventAuthentic).event;
        expect(event.fields, expected[i]);
        expect(event.seq, expected[i]['seq']);
      }
    });

    test('must_reject entries are all rejected with the right reason', () {
      final reasons = {
        'tampered_body': VoiceEventRejection.badSignature,
        'algorithm_substitution': VoiceEventRejection.algorithmMismatch,
        'signed_by_another_key': VoiceEventRejection.badSignature,
        'not_json': VoiceEventRejection.malformedEnvelope,
      };
      final mustReject = (vectors['must_reject']! as List)
          .cast<Map<String, Object?>>();
      expect(mustReject.map((m) => m['name']), unorderedEquals(reasons.keys));
      for (final m in mustReject) {
        final verdict = verifier().verifyText(m['envelope']! as String);
        expect(verdict, isA<VoiceEventRejected>(), reason: '${m['name']}');
        expect((verdict as VoiceEventRejected).reason, reasons[m['name']]);
      }
    });

    test(
      'replay rule: first delivery applies, duplicate delivery does not',
      () {
        final results = vectors['replay_rule_results']! as Map;
        final v = verifier();
        final guard = VoiceReplayGuard();
        final valid = (vectors['valid_envelopes']! as List).cast<String>();
        List<bool> deliver() => [
          for (final env in valid)
            guard
                    .accept((v.verifyText(env) as VoiceEventAuthentic).event)
                    .verdict ==
                VoiceReplayVerdict.apply,
        ];
        expect(deliver(), results['first_delivery']);
        expect(deliver(), results['duplicate_delivery']);
      },
    );

    test(
      'an envelope for another session is rejected (cross-session replay)',
      () {
        final v = VoiceEventVerifier(
          voiceSessionId: 'vs_SOMEONEELSE',
          algorithm: VoiceEventAlgorithm.ed25519,
          key: key,
        );
        final env = (vectors['valid_envelopes']! as List).first as String;
        expect(
          (v.verifyText(env) as VoiceEventRejected).reason,
          VoiceEventRejection.wrongSession,
        );
      },
    );

    test('envelope shape errors are rejected before any parsing', () {
      final v = verifier();
      final valid =
          jsonDecode((vectors['valid_envelopes']! as List).first as String)
              as Map<String, Object?>;
      VoiceEventRejection reasonOf(Object? env) =>
          (v.verify(env) as VoiceEventRejected).reason;
      expect(reasonOf('x'), VoiceEventRejection.malformedEnvelope);
      expect(
        reasonOf({...valid, 'e': 1}),
        VoiceEventRejection.malformedEnvelope,
      );
      expect(
        reasonOf({...valid}..remove('sig')),
        VoiceEventRejection.malformedEnvelope,
      );
      expect(
        reasonOf({...valid, 'sig': (valid['sig']! as String).toUpperCase()}),
        VoiceEventRejection.malformedEnvelope,
        reason: 'lowercase hex only',
      );
      expect(
        reasonOf({...valid, 'sig': (valid['sig']! as String).substring(2)}),
        VoiceEventRejection.badSignature,
        reason: '63-byte signature cannot verify',
      );
      expect(
        reasonOf({...valid}..remove('alg')),
        VoiceEventRejection.algorithmMismatch,
      );
    });

    test('legacy hmac-sha256 mode: verifies without domain prefix', () {
      final hmacKey = Uint8List.fromList(List.generate(32, (i) => i));
      const e =
          '{"v":"nexa.voice.v1","voice_session_id":"vs_H","type":"agent_ready","seq":1,"event_id":"vev_1","occurred_at":"2026-01-01T00:00:00.000Z","state":"listening"}';
      final sig = Hmac(sha256, hmacKey).convert(utf8.encode(e)).toString();
      final v = VoiceEventVerifier(
        voiceSessionId: 'vs_H',
        algorithm: VoiceEventAlgorithm.hmacSha256,
        key: hmacKey,
      );
      expect(
        v.verify({'e': e, 'sig': sig, 'alg': 'hmac-sha256'}),
        isA<VoiceEventAuthentic>(),
      );
      // An Ed25519-pinned verifier must refuse the hmac envelope.
      final ed = verifier();
      expect(
        (ed.verify({'e': e, 'sig': sig, 'alg': 'hmac-sha256'})
                as VoiceEventRejected)
            .reason,
        VoiceEventRejection.algorithmMismatch,
      );
    });
  });

  group('event schema (fixtures/events/*.json)', () {
    test('every happy-path example parses and maps to the SDK event family', () {
      final fixture = readJson('fixtures/events/happy_path.json');
      final examples = (fixture['first_example_per_type']! as Map)
          .cast<String, Object?>();
      final expected = <String, Type?>{
        'agent_ready': RealtimeAgentReady,
        'session_state': RealtimeSessionSnapshot,
        'network_quality': RealtimeNetworkQuality,
        'user_speech_started': RealtimeUserSpeechStarted,
        'user_speech_ended': RealtimeUserSpeechEnded,
        'transcript': RealtimeTranscript,
        'assistant_thinking': RealtimeAssistantThinking,
        'assistant_audio_started': RealtimeAssistantSpeakingStarted,
        'assistant_text': null, // folded into captions by the transport
        'assistant_turn_ended': RealtimeAssistantSpeakingEnded,
      };
      expect(examples.keys, unorderedEquals(expected.keys));
      for (final entry in examples.entries) {
        final verdict = parseEventV1(concretize(entry.value));
        expect(verdict, isA<VoiceEventAuthentic>(), reason: entry.key);
        final mapped = realtimeEventFromV1(
          (verdict as VoiceEventAuthentic).event,
        );
        expect(mapped?.runtimeType, expected[entry.key], reason: entry.key);
      }
      final order =
          (fixture['ordered_types_excluding_session_state_and_network_quality']!
                  as List)
              .cast<String>();
      expect(order.first, 'agent_ready');
      expect(order.last, 'assistant_turn_ended');
    });

    test('quota exhausted in call: quota_exceeded then session_ended', () {
      final fixture = readJson('fixtures/events/quota_exhausted_in_call.json');
      final quota =
          parseEventV1(concretize(fixture['quota_exceeded']))
              as VoiceEventAuthentic;
      final ended =
          parseEventV1(concretize(fixture['session_ended']))
              as VoiceEventAuthentic;
      expect(
        (realtimeEventFromV1(quota.event)! as RealtimeQuotaExceeded).quotaKind,
        'voice_seconds',
      );
      expect(
        (realtimeEventFromV1(ended.event)! as RealtimeSessionEnding).reason,
        'quota_exceeded',
      );
      expect(ended.event.seq, quota.event.seq + 1, reason: 'gapless');
      // REST still says active after the agent's session_ended: the client
      // must DELETE (asserted at controller level).
      final get =
          (fixture['GET_after_session_ended_event']! as Map)['body']! as Map;
      expect(get['status'], 'active');
    });

    test('schema rejections', () {
      Map<String, Object?> base(String type) => {
        'v': voiceContractV1,
        'type': type,
        'seq': 1,
        'event_id': 'vev_1',
        'voice_session_id': 'vs_1',
        'occurred_at': '2026-01-01T00:00:00.000Z',
      };
      VoiceEventRejection? reason(Map<String, Object?> e) {
        final v = parseEventV1(e);
        return v is VoiceEventRejected ? v.reason : null;
      }

      expect(
        reason({...base('agent_ready'), 'v': 'nexa.voice.v2'}),
        VoiceEventRejection.unsupportedVersion,
      );
      expect(reason(base('agent_mood')), VoiceEventRejection.unknownType);
      expect(
        reason(base('user_speech_started')),
        VoiceEventRejection.malformedEvent,
        reason: 'turn-scoped without turn_id',
      );
      expect(
        reason({
          ...base('transcript'),
          'turn_id': 't',
          'text': 'x',
          'is_final': 'yes',
        }),
        VoiceEventRejection.malformedEvent,
      );
      expect(
        reason({...base('interrupted'), 'turn_id': 't'}),
        VoiceEventRejection.malformedEvent,
        reason: 'cancel_id required',
      );
      expect(
        reason({...base('session_ended'), 'reason': 'bored'}),
        VoiceEventRejection.malformedEvent,
      );
      expect(
        reason({...base('agent_ready'), 'seq': 0}),
        VoiceEventRejection.malformedEvent,
      );
      expect(
        reason({...base('agent_ready')}..remove('event_id')),
        VoiceEventRejection.malformedEvent,
      );
      for (final r in voiceSessionEndedReasons) {
        expect(
          reason({...base('session_ended'), 'reason': r}),
          isNull,
          reason: r,
        );
      }
    });

    test(
      'occurred_at is not used for freshness: an old timestamp is accepted',
      () {
        final e = parseEventV1({
          'v': voiceContractV1,
          'type': 'agent_ready',
          'seq': 1,
          'event_id': 'vev_1',
          'voice_session_id': 'vs_1',
          'occurred_at': '1999-01-01T00:00:00.000Z',
        });
        expect(e, isA<VoiceEventAuthentic>());
      },
    );

    test(
      'interrupted turn_ended does not produce a second listening signal',
      () {
        final e =
            parseEventV1({
                  'v': voiceContractV1,
                  'type': 'assistant_turn_ended',
                  'seq': 3,
                  'event_id': 'vev_3',
                  'voice_session_id': 'vs_1',
                  'occurred_at': 'x',
                  'turn_id': 'turn_1',
                  'reason': 'interrupted',
                  'cancel_id': 'c1',
                })
                as VoiceEventAuthentic;
        expect(realtimeEventFromV1(e.event), isNull);
      },
    );
  });

  group('VoiceReplayGuard', () {
    VoiceEventV1 ev(int seq) => VoiceEventV1(
      type: 'network_quality',
      seq: seq,
      eventId: 'vev_$seq',
      voiceSessionId: 'vs',
      occurredAt: 'x',
      fields: const {},
    );

    test('gapless apply, duplicates dropped, gap held until filled', () {
      final g = VoiceReplayGuard();
      expect(g.accept(ev(1)).verdict, VoiceReplayVerdict.apply);
      expect(g.accept(ev(1)).verdict, VoiceReplayVerdict.duplicate);
      expect(g.accept(ev(3)).verdict, VoiceReplayVerdict.gap);
      expect(g.accept(ev(4)).verdict, VoiceReplayVerdict.gap);
      expect(g.hasGap, isTrue);
      expect(g.lastApplied, 1, reason: 'nothing applied past a gap');
      final filled = g.accept(ev(2));
      expect(filled.verdict, VoiceReplayVerdict.apply);
      expect(filled.ready.map((e) => e.seq), [2, 3, 4]);
      expect(g.hasGap, isFalse);
      expect(g.accept(ev(3)).verdict, VoiceReplayVerdict.duplicate);
    });

    test('skipTo moves the cursor when resume no longer covers the gap', () {
      final g = VoiceReplayGuard()..accept(ev(1));
      g.accept(ev(10));
      final released = g.skipTo(9);
      expect(released.single.seq, 10, reason: 'held event now contiguous');
      expect(g.lastApplied, 10);
      expect(g.accept(ev(10)).verdict, VoiceReplayVerdict.duplicate);
    });
  });

  group('VoiceGrant', () {
    test('agent identity, token skew and redaction', () {
      final g = VoiceGrant(
        voiceSessionId: 'vs_X',
        liveKitUrl: Uri.parse('wss://lk'),
        roomName: 'nexa-vs_X',
        participantIdentity: 'nexa-user-vs_X',
        participantToken: 'SECRET.JWT.TOKEN',
        tokenExpiresAt: DateTime.now().subtract(const Duration(seconds: 30)),
        eventAlgorithm: VoiceEventAlgorithm.ed25519,
        eventKey: Uint8List(32),
        maxSeconds: 60,
      );
      expect(g.agentIdentity, 'nexa-agent-vs_X');
      expect(g.isTokenExpired, isFalse, reason: 'within ±60 s skew');
      expect(g.toString(), isNot(contains('SECRET')));
      final r = g.withRefreshedToken(
        liveKitUrl: g.liveKitUrl,
        roomName: g.roomName,
        participantIdentity: g.participantIdentity,
        participantToken: 'NEW',
        tokenExpiresAt: DateTime.now().add(const Duration(seconds: 60)),
      );
      expect(r.voiceSessionId, 'vs_X');
      expect(
        r.eventKey,
        same(g.eventKey),
        reason: 'refresh never re-sends the key',
      );
    });
  });
}
