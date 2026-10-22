import 'dart:async';

import 'package:nexa_reference_gateway/nexa_reference_gateway.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  late ReferenceGateway gw;
  late GwClient c;

  setUp(() async {
    gw = await ReferenceGateway.start(port: 0, options: fastOptions);
    c = GwClient(gw);
  });

  tearDown(() async {
    c.close();
    await gw.close();
  });

  group('auth and session creation', () {
    test('healthz reports the contract version', () async {
      final (status, body) = await c.call('GET', '/healthz', auth: false);
      expect(status, 200);
      expect(body['contract_version'], contractVersion);
      expect(body['reference_implementation'], isTrue);
    });

    test(
      'missing / invalid / expired tokens are 401 with stable codes',
      () async {
        final (s1, b1) = await c.createSession();
        expect(s1, 401);
        expect((b1['error']! as Map)['code'], 'missing_token');

        c.token = 'nrg_not_a_real_token';
        final (s2, b2) = await c.createSession();
        expect(s2, 401);
        expect((b2['error']! as Map)['code'], 'invalid_token');

        await c.mint(ttlSeconds: 1);
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        final (s3, b3) = await c.createSession();
        expect(s3, 401);
        expect((b3['error']! as Map)['code'], 'token_expired');
        expect((b3['error']! as Map)['retryable'], isTrue);
      },
    );

    test(
      'application identity is bound server-side, not by the header',
      () async {
        await c.mint();
        final other = GwClient(gw, appId: 'app_other')..token = c.token;
        final (status, body) = await other.createSession();
        expect(status, 403);
        expect((body['error']! as Map)['code'], 'application_mismatch');
        other.close();
      },
    );

    test(
      'creates a session, filters capabilities, emits session_started',
      () async {
        await c.mint();
        final (status, body) = await c.createSession(
          caps: const ['textChat', 'liveVoice', 'bogus', 'toolCalling'],
        );
        expect(status, 201);
        expect(body['granted_capabilities'], ['textChat', 'toolCalling']);
        expect(body['last_sequence'], 0);
        final (_, page) = await c.poll(body['session_id']! as String);
        final events = (page['events']! as List).cast<Map<String, Object?>>();
        expect(types(events), ['session_started']);
        expect(events.single['sequence'], 1);
        expect(events.single['event_id'], isA<String>());
      },
    );

    test('rejects an unsupported language with 422', () async {
      await c.mint();
      final (status, _) = await c.createSession(lang: 'fr');
      expect(status, 422);
    });
  });

  group('messages over long-poll', () {
    test(
      'streams a reply, completes with full_text, cursor advances',
      () async {
        await c.mint();
        final sid = await c.session();
        final (status, _) = await c.send(sid, 'cm1', 'hello there');
        expect(status, 202);
        final events = await c.pollUntil(sid, 'assistant_message_completed');
        final t = types(events);
        expect(t.first, 'session_started');
        expect(t, contains('user_message_accepted'));
        expect(t, contains('assistant_message_started'));
        expect(
          t.where((x) => x == 'assistant_text_delta').length,
          greaterThan(3),
        );
        final completed = events.last;
        expect(completed['finish_reason'], 'stop');
        expect(completed['full_text'], contains('You said: "hello there"'));
        final seqs = [for (final e in events) e['sequence']! as int];
        expect(
          seqs,
          List.generate(seqs.length, (i) => i + 1),
          reason: 'contiguous',
        );
        final deltas = events.where((e) => e['type'] == 'assistant_text_delta');
        expect([
          for (final d in deltas) d['delta_index'],
        ], List.generate(deltas.length, (i) => i));
      },
    );

    test(
      'idempotency: same key+body replays 202 without new events; different body 409',
      () async {
        await c.mint();
        final sid = await c.session();
        await c.send(sid, 'cm1', 'hi');
        final before = (await c.pollUntil(
          sid,
          'assistant_message_completed',
        )).length;
        final (replay, _) = await c.send(sid, 'cm1', 'hi');
        expect(replay, 202);
        final (_, page) = await c.poll(sid);
        expect((page['events']! as List).length, before);
        final (conflict, body) = await c.send(sid, 'cm1', 'different');
        expect(conflict, 409);
        expect((body['error']! as Map)['code'], 'idempotency_conflict');
      },
    );

    test(
      'validation: missing key 400, key mismatch 422, empty text 422',
      () async {
        await c.mint();
        final sid = await c.session();
        final (s1, _) = await c.send(sid, 'cm1', 'x', key: '');
        expect(s1, 400);
        final (s2, _) = await c.send(sid, 'cm1', 'x', key: 'other');
        expect(s2, 422);
        final (s3, _) = await c.send(sid, 'cm2', '   ');
        expect(s3, 422);
      },
    );

    test('reject scenario emits user_message_rejected', () async {
      await c.mint();
      final sid = await c.session();
      await c.send(sid, 'cm1', 'please reject this');
      final events = await c.pollUntil(sid, 'user_message_rejected');
      expect(events.last['client_message_id'], 'cm1');
      expect((events.last['error']! as Map)['code'], 'policy_violation');
    });

    test('fail scenario emits message_failed (retryable)', () async {
      await c.mint();
      final sid = await c.session();
      await c.send(sid, 'cm1', 'fail please');
      final events = await c.pollUntil(sid, 'message_failed');
      expect((events.last['error']! as Map)['retryable'], isTrue);
    });

    test(
      'ratelimit scenario answers 429 once with retry_after_seconds',
      () async {
        await c.mint();
        final sid = await c.session();
        final (s1, b1) = await c.send(sid, 'cm1', 'ratelimit me');
        expect(s1, 429);
        expect((b1['error']! as Map)['retry_after_seconds'], 1);
        final (s2, _) = await c.send(sid, 'cm1', 'ratelimit me');
        expect(s2, 202);
      },
    );

    test(
      'second message while a reply is in progress is 409 assistant_busy',
      () async {
        await c.mint();
        final sid = await c.session();
        await c.send(sid, 'cm1', 'slow');
        final (status, body) = await c.send(sid, 'cm2', 'again');
        expect(status, 409);
        expect((body['error']! as Map)['code'], 'assistant_busy');
      },
    );

    test('Arabic sessions get Arabic text', () async {
      await c.mint();
      final sid = await c.session(lang: 'ar');
      await c.send(sid, 'cm1', 'مرحبا');
      final events = await c.pollUntil(sid, 'assistant_message_completed');
      expect(events.last['full_text'], contains('قلت'));
    });
  });

  group('cancellation', () {
    test(
      'cancel during streaming yields message_cancelled; after finish 409',
      () async {
        await c.mint();
        final sid = await c.session();
        await c.send(sid, 'cm1', 'slow reply');
        final started = await c.pollUntil(sid, 'assistant_message_started');
        final mid = started.last['message_id']! as String;
        final (status, _) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/messages/$mid/cancel',
        );
        expect(status, 202);
        final events = await c.pollUntil(sid, 'message_cancelled');
        expect(types(events), isNot(contains('assistant_message_completed')));
        final (again, body) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/messages/$mid/cancel',
        );
        expect(again, 409);
        expect((body['error']! as Map)['code'], 'already_finished');
      },
    );
  });

  group('quota and session end', () {
    test(
      'quota scenario: exceeded event, session ends, new session 402, reset clears',
      () async {
        await c.mint();
        final sid = await c.session();
        await c.send(sid, 'cm1', 'quota');
        final events = await c.pollUntil(sid, 'session_ended');
        final t = types(events);
        expect(t, contains('quota_updated'));
        expect(
          events.firstWhere((e) => e['type'] == 'quota_updated')['exceeded'],
          isTrue,
        );
        expect(events.last['reason'], 'quota_exceeded');
        final (status, body) = await c.createSession();
        expect(status, 402);
        expect((body['error']! as Map)['quota_kind'], 'messages');
        await c.call(
          'POST',
          '/v1/dev/applications/app_test/reset',
          auth: false,
        );
        final (after, _) = await c.createSession();
        expect(after, 201);
      },
    );

    test('quota is per application: exhausted by count too', () async {
      await c.mint();
      final sid = await c.session();
      for (var i = 0; i < 5; i++) {
        await c.send(sid, 'cm$i', 'msg $i');
        await c.pollUntil(
          sid,
          'assistant_message_completed',
          after: i == 0 ? 0 : 1,
        );
      }
      final (status, _) = await c.send(sid, 'cm9', 'one more');
      expect(status, 402);
    });

    test('DELETE ends the session; subsequent calls are 410 / done', () async {
      await c.mint();
      final sid = await c.session();
      final (status, _) = await c.call('DELETE', '/v1/sdk/sessions/$sid');
      expect(status, 204);
      final (_, page) = await c.poll(sid);
      final events = (page['events']! as List).cast<Map<String, Object?>>();
      expect(types(events).last, 'session_ended');
      expect(events.last['reason'], 'user_ended');
      expect(page['done'], isTrue);
      final (gone, body) = await c.poll(sid, after: page['cursor']! as int);
      expect(gone, 410);
      expect((body['error']! as Map)['code'], 'session_ended');
      final (sendStatus, _) = await c.send(sid, 'cm1', 'late');
      expect(sendStatus, 410);
      final (again, _) = await c.call('DELETE', '/v1/sdk/sessions/$sid');
      expect(again, 204, reason: 'idempotent');
    });

    test('expire scenario ends with reason expired', () async {
      await c.mint();
      final sid = await c.session();
      await c.send(sid, 'cm1', 'expire');
      final events = await c.pollUntil(sid, 'session_ended');
      expect(events.last['reason'], 'expired');
    });
  });

  group('SSE stream', () {
    test(
      'delivers the same events as long-poll and closes on session_ended',
      () async {
        await c.mint();
        final sid = await c.session();
        final collected = <Map<String, Object?>>[];
        final done = c.stream(sid).listen(collected.add).asFuture<void>();
        await c.send(sid, 'cm1', 'hello');
        await c.pollUntil(sid, 'assistant_message_completed');
        await c.call('DELETE', '/v1/sdk/sessions/$sid');
        await done.timeout(const Duration(seconds: 5));
        final t = types(collected);
        expect(t.first, 'session_started');
        expect(t.last, 'session_ended');
        expect(t, contains('assistant_message_completed'));
      },
    );

    test(
      'interrupt scenario drops the stream after the 3rd delta; after= resumes',
      () async {
        await c.mint();
        final sid = await c.session();
        final first = <Map<String, Object?>>[];
        final firstDone = c.stream(sid).listen(first.add).asFuture<void>();
        await c.send(sid, 'cm1', 'interrupt');
        await firstDone.timeout(const Duration(seconds: 5));
        final deltas = first
            .where((e) => e['type'] == 'assistant_text_delta')
            .toList();
        expect(deltas.length, 3, reason: 'server closed after 3rd delta');
        expect(types(first), isNot(contains('assistant_message_completed')));
        final last = first.last['sequence']! as int;
        // long-poll also fails once (503) for this scenario, then recovers
        final (status, _) = await c.poll(sid);
        expect(status, 503);
        final (ok, _) = await c.poll(sid);
        expect(ok, 200);
        final rest = <Map<String, Object?>>[];
        c.collect(sid, rest, after: last);
        await c.pollUntil(sid, 'assistant_message_completed');
        await Future<void>.delayed(const Duration(milliseconds: 100));
        expect(rest.first['sequence'], last + 1);
        expect(types(rest), contains('assistant_message_completed'));
      },
    );

    test('duplicate scenario sends every reply event twice', () async {
      await c.mint();
      final sid = await c.session();
      final collected = <Map<String, Object?>>[];
      c.collect(sid, collected);
      await c.send(sid, 'cm1', 'duplicate');
      await c.pollUntil(sid, 'assistant_message_completed');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final ids = [for (final e in collected) e['event_id']];
      final completedIds = collected
          .where((e) => e['type'] == 'assistant_message_completed')
          .map((e) => e['event_id'])
          .toList();
      expect(completedIds.length, 2);
      expect(completedIds.toSet().length, 1, reason: 'same event_id twice');
      expect(ids.length, greaterThan(ids.toSet().length));
    });
  });

  group('tools and permissions', () {
    test(
      'booking: confirmation requested, confirmed action → result + completion',
      () async {
        await c.mint();
        final sid = await c.session();
        await c.send(sid, 'cm1', 'book a table');
        final events = await c.pollUntil(sid, 'user_confirmation_requested');
        final callId = events.last['tool_call_id']! as String;
        final (status, _) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/tool-actions',
          body: {
            'kind': 'confirmed',
            'tool_call_id': callId,
            'confirmation_id': (events.last['confirmation']! as Map)['id'],
          },
        );
        expect(status, 202);
        final rest = await c.pollUntil(
          sid,
          'assistant_message_completed',
          after: events.last['sequence']! as int,
        );
        expect(
          types(rest),
          containsAllInOrder([
            'tool_execution_progress',
            'tool_result_received',
            'assistant_message_completed',
          ]),
        );
        final (again, body) = await c.call(
          'POST',
          '/v1/sdk/sessions/$sid/tool-actions',
          body: {'kind': 'confirmed', 'tool_call_id': callId},
        );
        expect(again, 409);
        expect((body['error']! as Map)['code'], 'not_awaiting_action');
      },
    );

    test('weather: tool call, progress, result, text', () async {
      await c.mint();
      final sid = await c.session();
      await c.send(sid, 'cm1', 'weather today?');
      final events = await c.pollUntil(sid, 'assistant_message_completed');
      expect(
        types(events),
        containsAllInOrder([
          'tool_call_requested',
          'tool_execution_progress',
          'tool_result_received',
          'assistant_message_completed',
        ]),
      );
      final result =
          events.firstWhere(
                (e) => e['type'] == 'tool_result_received',
              )['result']!
              as Map;
      expect(result['kind'], 'weather');
    });

    test('mic: permission requested; result recorded with 204', () async {
      await c.mint();
      final sid = await c.session();
      await c.send(sid, 'cm1', 'use the mic');
      final events = await c.pollUntil(sid, 'permission_requested');
      final reqId =
          events.firstWhere(
                (e) => e['type'] == 'permission_requested',
              )['request_id']!
              as String;
      final (status, _) = await c.call(
        'POST',
        '/v1/sdk/sessions/$sid/permissions/$reqId',
        body: {'granted': false},
      );
      expect(status, 204);
      expect(gw.store.sessions[sid]!.permissions[reqId], isFalse);
    });
  });
}
