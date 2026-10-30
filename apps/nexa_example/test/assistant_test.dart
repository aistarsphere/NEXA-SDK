import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  // Widget tests use the labelled SDK mocks (no sockets under fake async).
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

  testWidgets('assistant: suggestions start a conversation', (tester) async {
    await phone(tester);
    final client = await mockClient();
    await tester.pumpWidget(
      ExampleApp(client: client, auth: MockAuthProvider()),
    );
    await tester.pumpAndSettle();

    expect(find.text('How can I help you today?'), findsOneWidget);
    await tester.tap(find.text('What can you help me with?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Welcome to NEXA'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant: live voice opens over the chat and closes', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    await tester.pumpWidget(
      ExampleApp(client: client, auth: MockAuthProvider()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nexa_composer_voice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Live conversation'), findsOneWidget);
    expect(find.byKey(const Key('nexa_voice_pill')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_voice_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Live conversation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('assistant: Arabic switches the whole app to RTL', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    await tester.pumpWidget(
      ExampleApp(client: client, auth: MockAuthProvider()),
    );
    client.setLanguage('ar');
    await tester.pumpAndSettle();

    expect(find.text('كيف يمكنني مساعدتك اليوم؟'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('لبيب'))),
      TextDirection.rtl,
    );
  });

  testWidgets('assistant: no token shows the not-connected state', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    final auth = DevTokenAuthProvider();
    await tester.pumpWidget(ExampleApp(client: client, auth: auth));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('assistant_not_connected')), findsOneWidget);
    // Development build (tests run in debug): explains the secrets file;
    // there is no in-app token entry.
    expect(find.byKey(const Key('assistant_dev_token_hint')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byKey(const Key('nexa_composer_field')), findsNothing);

    auth.setToken('nxs_test', expiresAt: DateTime.utc(2100));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_composer_field')), findsOneWidget);
  });

  testWidgets('settings: language, appearance, developer section in debug', (
    tester,
  ) async {
    await phone(tester);
    final client = await mockClient();
    await tester.pumpWidget(
      ExampleApp(client: client, auth: MockAuthProvider()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant_settings')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(client.uiSettings.value.themeMode, NexaThemeMode.dark);
    await tester.scrollUntilVisible(
      find.byKey(const Key('settings_playground')),
      200,
    );
    expect(find.byKey(const Key('settings_diagnostics')), findsOneWidget);
  });

  testWidgets(
    'assistant: LABEEB brand with text fallback, home and voice-only',
    (tester) async {
      await phone(tester);
      final client = await mockClient();
      Widget app(NexaLaunchMode mode, {bool voice = true}) => MaterialApp(
        key: ValueKey('$mode-$voice'),
        home: client.assistantView(
          brand: const NexaBrand(
            name: 'LABEEB',
            localizedNames: {'ar': 'لبيب'},
          ),
          launchMode: mode,
          features: NexaAssistantFeatures(voice: voice),
        ),
      );

      await tester.pumpWidget(app(NexaLaunchMode.chat));
      await tester.pumpAndSettle();
      expect(find.text('LABEEB'), findsOneWidget);
      expect(find.byKey(const Key('nexa_brand_fallback')), findsOneWidget);
      expect(find.byKey(const Key('assistant_voice')), findsOneWidget);

      // Hiding voice removes every entry point.
      await tester.pumpWidget(app(NexaLaunchMode.chat, voice: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_voice')), findsNothing);
      expect(find.byKey(const Key('nexa_composer_voice')), findsNothing);

      await tester.pumpWidget(app(NexaLaunchMode.home));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('assistant_home_chat')), findsOneWidget);
      expect(find.byKey(const Key('assistant_home_voice')), findsOneWidget);
      await tester.tap(find.byKey(const Key('assistant_home_chat')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_composer_field')), findsOneWidget);

      await tester.pumpWidget(app(NexaLaunchMode.voice));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_voice_start')), findsOneWidget);
      expect(find.byKey(const Key('nexa_composer_field')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
