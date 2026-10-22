import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import 'helpers.dart';

void main() {
  tearDown(() async {
    if (Nexa.isInitialized) await Nexa.instance.dispose();
  });

  group('Nexa.initialize / dispose', () {
    test('validates config before building the container', () async {
      expect(
        () => Nexa.initialize(
          config: NexaConfig(
            applicationId: '',
            gatewayBaseUri: Uri.parse('https://x'),
          ),
          auth: MockAuthProvider(),
        ),
        throwsA(isA<ConfigurationException>()),
      );
      expect(Nexa.isInitialized, isFalse);
    });

    test('initialises once, exposes instance, refuses double init', () async {
      final client = await initMockClient();
      expect(Nexa.isInitialized, isTrue);
      expect(identical(Nexa.instance, client), isTrue);
      expect(() => initMockClient(), throwsA(isA<ConfigurationException>()));
    });

    test('instance before init throws NotInitializedException', () {
      expect(() => Nexa.instance, throwsA(isA<NotInitializedException>()));
    });

    test('lifecycle: start, end, dispose', () async {
      final client = await initMockClient();
      final events = <NexaLifecycleEvent>[];
      final sub = client.lifecycle.listen(events.add);
      final handle = await client.startSession();
      expect(handle.grantedCapabilities, contains(NexaCapability.textChat));
      expect(client.currentSession, isNotNull);
      await client.endSession();
      expect(client.currentSession, isNull);
      await client.dispose();
      await settle();
      await sub.cancel();
      expect(events.whereType<NexaCredentialRefreshed>(), isNotEmpty);
      expect(events.whereType<NexaSessionStarted>().length, 1);
      expect(events.whereType<NexaSessionEnded>().length, 1);
      expect(events.whereType<NexaDisposed>().length, 1);
      expect(Nexa.isInitialized, isFalse);
      expect(
        () => client.startSession(),
        throwsA(isA<NotInitializedException>()),
      );
    });

    test(
      'auth failure surfaces as AuthenticationException + lifecycle error',
      () async {
        final client = await initMockClient(
          auth: MockAuthProvider(failWith: 'nope'),
        );
        final errors = <NexaErrorOccurred>[];
        client.lifecycle.whereType<NexaErrorOccurred>().listen(errors.add);
        await expectLater(
          client.startSession(),
          throwsA(isA<AuthenticationException>()),
        );
        await settle();
        expect(errors.single.error, isA<AuthenticationException>());
      },
    );

    test('setLanguage validates and updates settings', () async {
      final client = await initMockClient();
      client.setLanguage('ar');
      expect(client.uiSettings.value.languageTag, 'ar');
      expect(
        () => client.setLanguage('fr'),
        throwsA(isA<ConfigurationException>()),
      );
    });

    test('concurrent startSession calls share one session', () async {
      final transport = fastMock();
      final client = await initMockClient(transport: transport);
      final results = await Future.wait([
        client.startSession(),
        client.startSession(),
      ]);
      expect(results[0].sessionId, results[1].sessionId);
    });
  });
}

extension<T> on Stream<T> {
  Stream<R> whereType<R>() => where((e) => e is R).cast<R>();
}
