// Plan D-01: the pending tool-workflow state (which session a call belongs
// to, its status, half-filled form values) survives a process restart. It
// never holds arguments or results, is bounded, expires, and is per account.
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

LabeebPendingState state({int calls = 1, DateTime? seen}) => LabeebPendingState(
  calls: {
    for (var i = 0; i < calls; i++)
      'tc_$i': LabeebPendingCall(
        sessionId: 'ses_$i',
        status: 'awaiting_approval',
        seenAt: seen ?? DateTime.utc(2026, 11, 3),
      ),
  },
  uiValues: const {
    'ui_1': {'opt': 'a', 'on': true},
  },
);

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('nexa_pending'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('in memory', () {
    test('round trip per conversation', () async {
      final s = InMemoryPendingStore();
      await s.save('conv_1', state());
      expect((await s.load('conv_1')).calls.keys, ['tc_0']);
      expect((await s.load('conv_2')).isEmpty, isTrue);
    });
  });

  group('json file', () {
    JsonFilePendingStore store() =>
        JsonFilePendingStore.forAccount(dir, 'acct');

    test('survives a new instance (the process restart)', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 3, 12)), () async {
        await store().save('conv_1', state());
        final loaded = await store().load('conv_1');
        expect(loaded.calls['tc_0']!.sessionId, 'ses_0');
        expect(loaded.calls['tc_0']!.status, 'awaiting_approval');
        expect(loaded.uiValues['ui_1'], {'opt': 'a', 'on': true});
      });
    });

    test('keeps at most 50 calls per conversation, newest first', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 3, 12)), () async {
        final many = LabeebPendingState(
          calls: {
            for (var i = 0; i < 60; i++)
              'tc_$i': LabeebPendingCall(
                sessionId: 's',
                status: 'running',
                seenAt: DateTime.utc(2026, 11, 3, 0, i),
              ),
          },
        );
        await store().save('conv_1', many);
        final loaded = await store().load('conv_1');
        expect(loaded.calls, hasLength(50));
        expect(loaded.calls.containsKey('tc_59'), isTrue);
        expect(loaded.calls.containsKey('tc_0'), isFalse);
      });
    });

    test('drops calls older than 7 days', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 20)), () async {
        await store().save('conv_1', state(seen: DateTime.utc(2026, 11, 3)));
      });
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 20)), () async {
        expect((await store().load('conv_1')).calls, isEmpty);
      });
    });

    test(
      'an empty state removes the conversation; unreadable file is empty',
      () async {
        await withClock(Clock.fixed(DateTime.utc(2026, 11, 3, 12)), () async {
          final s = store();
          await s.save('conv_1', state());
          await s.save('conv_1', const LabeebPendingState());
          expect((await s.load('conv_1')).isEmpty, isTrue);
          store().file.writeAsStringSync('{ not json');
          expect((await store().load('conv_1')).isEmpty, isTrue);
        });
      },
    );

    test('one file per account; the key is not in the file name', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 11, 3, 12)), () async {
        final a = JsonFilePendingStore.forAccount(dir, 'alice@example.com');
        final b = JsonFilePendingStore.forAccount(dir, 'bob@example.com');
        await a.save('conv_1', state());
        expect((await b.load('conv_1')).isEmpty, isTrue);
        final name = dir.listSync().single.uri.pathSegments.last;
        expect(name, matches(r'^pending_[0-9a-f]{8}\.json$'));
      });
    });

    test(
      'nothing sensitive is written (no arguments, results or text)',
      () async {
        await withClock(Clock.fixed(DateTime.utc(2026, 11, 3, 12)), () async {
          await store().save('conv_1', state());
          final raw = dir
              .listSync()
              .whereType<File>()
              .single
              .readAsStringSync();
          final json = jsonDecode(raw) as Map<String, Object?>;
          expect(raw, isNot(contains('arguments')));
          expect(raw, isNot(contains('result')));
          expect(json.keys, ['conv_1']);
        });
      },
    );
  });
}
