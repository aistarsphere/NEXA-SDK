// Route graph owned by the app (plan A-02): `/`, `/c/:id`, `/c/:id/call`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  Future<NexaClient> mockClient() async {
    final client = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
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
    return client;
  }

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  String path(ExampleApp app) => app.router.state.uri.path;

  testWidgets('double press on voice: one /call route; close returns to /', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    final app = ExampleApp(client: client, auth: MockAuthProvider());
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    final press = tester
        .widget<IconButton>(find.byKey(const Key('assistant_voice')))
        .onPressed!;
    press();
    press();
    await frames(tester);
    expect(path(app), '/c/new/call');
    expect(find.byKey(const Key('live_voice_close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    expect(path(app), '/');
    expect(find.byKey(const Key('live_voice_close')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/c/:id resumes that conversation and shows the chat', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    final app = ExampleApp(
      client: client,
      auth: MockAuthProvider(),
      initialLocation: '/c/conv_7',
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    expect(client.conversationId, 'conv_7');
    expect(find.byKey(const Key('assistant_voice')), findsOneWidget);
    expect(path(app), '/c/conv_7');
  });

  testWidgets('/c/:id/call opens the call page and back lands on the chat', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    final app = ExampleApp(
      client: client,
      auth: MockAuthProvider(),
      initialLocation: '/c/conv_7',
    );
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    unawaited(app.router.push<void>('/c/conv_7/call'));
    await frames(tester);
    expect(find.byKey(const Key('live_voice_close')), findsOneWidget);
    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    expect(path(app), '/c/conv_7');
    expect(find.byKey(const Key('assistant_voice')), findsOneWidget);
  });
}
