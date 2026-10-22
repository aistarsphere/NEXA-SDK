// Widget-level states of the embedded chat: reconnecting / auth / expired
// banners, jump-to-latest, streaming caret, unmount during streaming, and
// RTL + theme switching with content present.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_bloc.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_event.dart';
import 'package:nexa_sdk/src/features/chat/bloc/chat_state.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

void main() {
  late NexaClient client;

  tearDown(() => client.dispose());

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

  ChatBloc blocOf(WidgetTester tester) {
    final context = tester.element(find.byType(NexaComposer));
    return BlocProviderReader.of(context);
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('nexa_composer_field')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('nexa_composer_send')));
    await tester.pump();
  }

  group('connection and error banners', () {
    testWidgets('reconnecting banner appears and clears', (tester) async {
      client = await initMockClient(
        config: testConfig(eventPollInterval: const Duration(seconds: 1)),
      );
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      final bloc = blocOf(tester);
      bloc.add(const ChatTransportFailed(TransportException('drop')));
      await tester.pump(); // bloc processes the event
      await tester.pump(); // consumer rebuilds
      expect(find.byKey(const Key('nexa_reconnecting_banner')), findsOneWidget);
      expect(find.text('Reconnecting…'), findsOneWidget);
      // Composer is disabled while reconnecting.
      final field = tester.widget<TextField>(
        find.byKey(const Key('nexa_composer_field')),
      );
      expect(field.enabled, isFalse);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_reconnecting_banner')), findsNothing);
      expect(bloc.state.connection, ChatConnection.connected);
    });

    testWidgets('auth error shows a localised banner with Retry', (
      tester,
    ) async {
      client = await initMockClient();
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      blocOf(
        tester,
      ).add(const ChatTransportFailed(AuthenticationException('nope')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_error_banner')), findsOneWidget);
      expect(find.textContaining("couldn't verify"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_error_banner')), findsNothing);
    });

    testWidgets('session expiry ends the chat with the expired message', (
      tester,
    ) async {
      client = await initMockClient();
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      blocOf(tester).add(const ChatTransportFailed(SessionExpiredException()));
      await tester.pumpAndSettle();
      expect(find.textContaining('session expired'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('quota: banner, composer locked, ended text', (tester) async {
      client = await initMockClient();
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await send(tester, 'quota');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('nexa_session_ended')), findsOneWidget);
      expect(find.textContaining('usage limit'), findsWidgets);
      expect(find.byType(NexaComposer), findsNothing);
    });

    testWidgets('Arabic banners under RTL', (tester) async {
      client = await initMockClient(
        lang: 'ar',
        config: testConfig(
          lang: 'ar',
          eventPollInterval: const Duration(seconds: 1),
        ),
      );
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      blocOf(tester).add(const ChatTransportFailed(TransportException('x')));
      await tester.pump();
      await tester.pump();
      expect(find.text('جارٍ إعادة الاتصال…'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const Key('nexa_reconnecting_banner'))),
        ),
        TextDirection.rtl,
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
    });
  });

  group('streaming and scrolling', () {
    testWidgets('streaming text shows a caret, completed text does not', (
      tester,
    ) async {
      client = await initMockClient(
        transport: MockChatTransport(
          tokenDelay: const Duration(milliseconds: 50),
          thinkDelay: Duration.zero,
        ),
      );
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await send(tester, 'hello');
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.byType(NexaStreamingCaret), findsOneWidget);
      expect(find.byKey(const Key('nexa_composer_stop')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(NexaStreamingCaret), findsNothing);
      expect(find.byKey(const Key('nexa_composer_send')), findsOneWidget);
    });

    testWidgets(
      'jump-to-latest appears when scrolled up and new content lands',
      (tester) async {
        client = await initMockClient();
        await tester.pumpWidget(host(client.chatView()));
        await tester.pumpAndSettle();
        // Fill the list.
        for (var i = 0; i < 6; i++) {
          await send(tester, 'message number $i with some extra words to wrap');
          await tester.pumpAndSettle();
        }
        final list = find.byKey(const Key('nexa_message_list'));
        final controller = tester.widget<ListView>(list).controller!;
        expect(controller.position.maxScrollExtent, greaterThan(0));
        final jump = find.byKey(const Key('nexa_jump_to_latest'));
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(of: jump, matching: find.byType(IgnorePointer))
                    .first,
              )
              .ignoring,
          isTrue,
          reason: 'hidden while at bottom',
        );
        // Scroll to the top, then receive new content.
        controller.jumpTo(0);
        await tester.pumpAndSettle();
        await send(tester, 'new content');
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IgnorePointer>(
                find
                    .ancestor(of: jump, matching: find.byType(IgnorePointer))
                    .first,
              )
              .ignoring,
          isFalse,
          reason: 'visible after new content',
        );
        expect(
          controller.offset,
          lessThan(controller.position.maxScrollExtent),
        );
        await tester.tap(jump);
        await tester.pumpAndSettle();
        expect(controller.offset, controller.position.maxScrollExtent);
      },
    );

    testWidgets('unmounting mid-stream does not throw and closes the bloc', (
      tester,
    ) async {
      client = await initMockClient(
        transport: MockChatTransport(
          tokenDelay: const Duration(milliseconds: 40),
          thinkDelay: Duration.zero,
        ),
      );
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await send(tester, 'hello there');
      await tester.pump(const Duration(milliseconds: 60));
      final bloc = blocOf(tester);
      expect(bloc.state.generating, isNotNull, reason: 'mid-stream');
      await tester.pumpWidget(host(const SizedBox()));
      await tester.pumpAndSettle();
      expect(bloc.isClosed, isTrue);
      expect(tester.takeException(), isNull);
      // Let the mock's scripted reply timers run out (test hygiene only).
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('language and theme switch with content present', (
      tester,
    ) async {
      client = await initMockClient();
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await send(tester, 'hello');
      await tester.pumpAndSettle();
      client
        ..setLanguage('ar')
        ..setThemeMode(NexaThemeMode.dark);
      await tester.pumpAndSettle();
      final bubble = tester.element(find.text('hello'));
      expect(Directionality.of(bubble), TextDirection.rtl);
      expect(Theme.of(bubble).brightness, Brightness.dark);
      expect(find.text('اكتب رسالة'), findsOneWidget);
      // Messages survive the switch.
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('live announcer reports assistant completion', (tester) async {
      final handle = tester.ensureSemantics();
      client = await initMockClient();
      await tester.pumpWidget(host(client.chatView()));
      await tester.pumpAndSettle();
      await send(tester, 'hi');
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel('Assistant finished responding'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}

/// Reads the bloc from a context under `BlocProvider.value`.
abstract final class BlocProviderReader {
  static ChatBloc of(BuildContext context) => context.read<ChatBloc>();
}
