import 'dart:async';

import 'package:clock/clock.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_core/testing.dart';
import 'package:test/test.dart';

final class _Counting implements NexaAuthProvider {
  _Counting(this.lifetime);
  final Duration lifetime;
  int calls = 0;
  final completers = <Completer<SessionCredential>>[];

  @override
  Future<SessionCredential> fetchSessionCredential() {
    calls++;
    final c = Completer<SessionCredential>();
    completers.add(c);
    return c.future;
  }

  void release() {
    for (final c in completers.where((c) => !c.isCompleted)) {
      c.complete(
        SessionCredential(
          token: 't$calls',
          expiresAt: clock.now().add(lifetime),
        ),
      );
    }
  }
}

void main() {
  group('CredentialManager', () {
    test('caches a valid credential', () async {
      final p = MockAuthProvider(lifetime: const Duration(minutes: 10));
      final m = CredentialManager(p);
      final a = await m.getValid();
      final b = await m.getValid();
      expect(identical(a, b), isTrue);
      expect(p.issuedCount, 1);
    });

    test('refreshes within the (adaptive) skew window', () async {
      final t0 = DateTime.utc(2026);
      final p = MockAuthProvider(lifetime: const Duration(seconds: 20));
      final m = CredentialManager(p, refreshSkew: const Duration(seconds: 30));
      await withClock(Clock.fixed(t0), () async {
        await m.getValid();
        await m.getValid();
        expect(
          p.issuedCount,
          1,
          reason: '30s skew shrinks to lifetime/4 = 5s for a 20s token',
        );
      });
      await withClock(
        Clock.fixed(t0.add(const Duration(seconds: 16))),
        () async {
          await m.getValid();
          expect(p.issuedCount, 2, reason: 'inside the last 5s');
        },
      );
    });

    test('collapses concurrent refreshes', () async {
      final p = _Counting(const Duration(minutes: 5));
      final m = CredentialManager(p);
      final f1 = m.getValid();
      final f2 = m.getValid();
      p.release();
      final r = await Future.wait([f1, f2]);
      expect(p.calls, 1);
      expect(identical(r[0], r[1]), isTrue);
    });

    test('wraps provider failures as AuthenticationException', () async {
      final m = CredentialManager(
        MockAuthProvider(failWith: StateError('nope')),
      );
      expect(m.getValid(), throwsA(isA<AuthenticationException>()));
    });

    test('rejects already-expired credentials', () async {
      final m = CredentialManager(
        MockAuthProvider(lifetime: const Duration(seconds: -1)),
      );
      expect(m.getValid(), throwsA(isA<AuthenticationException>()));
    });
  });

  group('adaptive refresh skew', () {
    test('short-lived credentials are not refreshed on every call', () async {
      final provider = MockAuthProvider(lifetime: const Duration(seconds: 4));
      final manager = CredentialManager(provider); // default skew 30 s
      final t0 = DateTime(2026, 1, 1, 12);
      await withClock(Clock.fixed(t0), () async {
        await manager.getValid();
        await manager.getValid();
        expect(provider.issuedCount, 1, reason: 'outside the last quarter');
      });
      await withClock(
        Clock.fixed(t0.add(const Duration(milliseconds: 3500))),
        () async {
          await manager.getValid();
          expect(provider.issuedCount, 2, reason: 'inside the last quarter');
        },
      );
    });
  });
}
