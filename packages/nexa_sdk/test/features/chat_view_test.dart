import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

void main() {
  late NexaClient client;

  setUp(() async => client = await initMockClient());
  tearDown(() => client.dispose());

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('NexaChatView embedding', () {
    testWidgets('renders inside a host without NEXA localisation setup', (
      tester,
    ) async {
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_composer_field')), findsOneWidget);
      // Theme applied only within the SDK subtree.
      final field = tester.element(
        find.byKey(const Key('nexa_composer_field')),
      );
      expect(Theme.of(field).colorScheme.primary, MochaPalette.lightPrimary);
      expect(NexaLocalizations.of(field).send, 'Send');
    });

    testWidgets('sends a message and shows streamed reply and a tool card', (
      tester,
    ) async {
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nexa_composer_field')),
        'weather',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_composer_send')));
      await tester.pumpAndSettle();
      expect(find.text('weather'), findsOneWidget);
      expect(find.byType(NexaToolResultCard), findsOneWidget);
      expect(find.text('Baghdad'), findsOneWidget);
    });

    testWidgets('switches to Arabic + RTL at runtime', (tester) async {
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      client.setLanguage('ar');
      await tester.pumpAndSettle();
      final field = tester.element(
        find.byKey(const Key('nexa_composer_field')),
      );
      expect(Directionality.of(field), TextDirection.rtl);
      expect(find.text('اكتب رسالة'), findsOneWidget);
      expect(
        Theme.of(field).textTheme.bodyLarge!.fontFamily,
        contains('Tajawal'),
      );
    });

    testWidgets('dark mode override and brand seed apply', (tester) async {
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      client
        ..setThemeMode(NexaThemeMode.dark)
        ..setThemeOverrides(const NexaThemeOverrides(seedColor: Colors.indigo));
      await tester.pumpAndSettle();
      final field = tester.element(
        find.byKey(const Key('nexa_composer_field')),
      );
      expect(Theme.of(field).brightness, Brightness.dark);
      expect(Theme.of(field).colorScheme.surface, MochaPalette.darkSurface);
      expect(
        Theme.of(field).colorScheme.primary,
        isNot(MochaPalette.darkPrimary),
      );
    });

    testWidgets('end action ends the session', (tester) async {
      var ended = false;
      await tester.pumpWidget(
        host(client.chatView(showEndAction: true, onEnded: () => ended = true)),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('nexa_end_session')));
      await tester.tap(find.byKey(const Key('nexa_end_session')));
      await tester.pumpAndSettle();
      expect(ended, isTrue);
      expect(find.text('This chat has ended.'), findsOneWidget);
      expect(client.currentSession, isNull);
    });

    testWidgets('openChat pushes a full-screen route with the Mocha app bar', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => client.openChat(context),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Assistant'), findsOneWidget);
      expect(find.byType(NexaComposer), findsOneWidget);
    });

    testWidgets('accessibility baseline: semantics labels and tap targets', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('nexa_composer_field')),
        'hi',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_composer_send')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('You said: hi')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Assistant said')), findsOneWidget);
      final sendSize = tester.getSize(
        find.byKey(const Key('nexa_composer_send')),
      );
      expect(sendSize.width, greaterThanOrEqualTo(48));
      expect(sendSize.height, greaterThanOrEqualTo(48));
      handle.dispose();
    });
  });
}
