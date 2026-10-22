// End-to-end journey on a real device/simulator against the LOCAL REFERENCE
// GATEWAY (`make gateway` or `tool/e2e.sh`). Real sockets, real SSE, host
// auth provider minting tokens from the dev endpoint. Not a production
// backend test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

Future<void> _send(WidgetTester tester, String text) async {
  final field = find.byKey(const Key('nexa_composer_field'));
  final send = find.byKey(const Key('nexa_composer_send'));
  // Wait until the previous reply finished (send button back, field enabled).
  await _until(tester, send);
  await _until(
    tester,
    find.byWidgetPredicate(
      (w) =>
          w is TextField &&
          w.key == const Key('nexa_composer_field') &&
          w.enabled != false,
    ),
  );
  // The integration binding does not register the fake IME (`TestTextInput`),
  // so enterText is unreliable on a real simulator. Drive the composer the
  // way a keyboard would: set the field's controller value, then tap send.
  final controller = tester.widget<TextField>(field).controller!;
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );
  await tester.pump(const Duration(milliseconds: 100));
  expect(tester.widget<TextField>(field).controller?.text, text);
  await tester.tap(send);
  await tester.pump(const Duration(milliseconds: 100));
  expect(
    tester.widget<TextField>(field).controller?.text,
    isEmpty,
    reason: 'composer clears after a successful send',
  );
}

Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full chat journey over HTTP/SSE to the reference gateway', (
    tester,
  ) async {
    final auth = HostAuthProvider(
      hostBackendUri: ExampleConfig.gatewayUri,
      applicationId: ExampleConfig.applicationId,
    );
    final client = await Nexa.initialize(
      config: NexaConfig(
        applicationId: ExampleConfig.applicationId,
        gatewayBaseUri: ExampleConfig.gatewayUri,
        environment: NexaEnvironment.development,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.toolCalling,
          NexaCapability.richResults,
        },
      ),
      auth: auth,
    );
    final lifecycle = <NexaLifecycleEvent>[];
    client.lifecycle.listen(lifecycle.add);

    await tester.pumpWidget(ExampleApp(client: client, auth: auth));
    await _until(tester, find.textContaining('reachable'));

    // 1-4: open the modal chat -> session is created with a host token.
    await tester.tap(find.byKey(const Key('open_chat')));
    await _until(tester, find.byKey(const Key('nexa_composer_field')));
    await _until(tester, find.text('Assistant'));
    expect(auth.issued, 1);
    expect(client.currentSession, isNotNull);

    // 5-6: send and stream.
    await _send(tester, 'hello from the device');
    await _until(tester, find.textContaining('reference gateway'));
    expect(find.text('hello from the device'), findsOneWidget);

    // 7: stop a slow reply.
    await _send(tester, 'slow');
    await _until(tester, find.byKey(const Key('nexa_composer_stop')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('nexa_composer_stop')));
    await _until(tester, find.text('Stopped.'));

    // 8: retry after a 429.
    await _send(tester, 'ratelimit');
    await _until(tester, find.text('Retry'));
    await tester.tap(find.text('Retry'));
    await _until(tester, find.textContaining('You said: "ratelimit"'));

    // 9: connection interruption -> reconnect -> full text.
    await _send(tester, 'interrupt');
    await _until(
      tester,
      find.textContaining('resumes once the SDK reconnects successfully'),
    );

    // 10: quota -> ended state with the quota message.
    await _send(tester, 'quota');
    await _until(tester, find.byKey(const Key('nexa_session_ended')));
    expect(find.textContaining('usage limit'), findsWidgets);

    // 11: close and dispose.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();
    await client.dispose();
    expect(lifecycle.whereType<NexaSessionStarted>(), isNotEmpty);
    expect(lifecycle.whereType<NexaSessionEnded>(), isNotEmpty);
    expect(lifecycle.whereType<NexaDisposed>().length, 1);
  });
}
