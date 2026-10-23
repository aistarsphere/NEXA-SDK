import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  testWidgets('host app opens the modal chat and gets a mocked reply', (
    tester,
  ) async {
    // Widget-test journey uses the labelled mock transport (no sockets under
    // fake async). The real-HTTP journey lives in integration_test/.
    final auth = HostAuthProvider(
      hostBackendUri: Uri.parse('http://localhost:1'),
      applicationId: 'app_test',
    );
    final client = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
      ),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: MockChatTransport(
          tokenDelay: Duration.zero,
          thinkDelay: Duration.zero,
        ),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
      ),
    );
    addTearDown(client.dispose);

    await tester.pumpWidget(ExampleApp(client: client, auth: auth));
    await tester.tap(find.byKey(const Key('open_chat')));
    await tester.pumpAndSettle();

    expect(find.text('Assistant'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('nexa_composer_field')),
      'hello',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('nexa_composer_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome to NEXA'), findsOneWidget);
  });
}
