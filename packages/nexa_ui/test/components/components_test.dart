import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

ChatMessage msg(MessageRole role, MessageStatus status, String text) =>
    ChatMessage(
      id: const MessageId('m'),
      role: role,
      status: status,
      createdAt: DateTime(2026),
      text: text,
      retryable: status == MessageStatus.failed,
    );

void main() {
  group('NexaMessageBubble', () {
    testWidgets('user bubble aligns end and assistant aligns start (LTR)', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              NexaMessageBubble(
                message: msg(MessageRole.user, MessageStatus.sent, 'u'),
              ),
              NexaMessageBubble(
                message: msg(
                  MessageRole.assistant,
                  MessageStatus.completed,
                  'a',
                ),
              ),
            ],
          ),
        ),
      );
      final user = tester.getTopLeft(find.text('u'));
      final assistant = tester.getTopLeft(find.text('a'));
      expect(user.dx, greaterThan(assistant.dx));
    });

    testWidgets('mirrors under Arabic RTL', (tester) async {
      await tester.pumpWidget(
        harness(
          Column(
            children: [
              NexaMessageBubble(
                message: msg(MessageRole.user, MessageStatus.sent, 'u'),
              ),
              NexaMessageBubble(
                message: msg(
                  MessageRole.assistant,
                  MessageStatus.completed,
                  'a',
                ),
              ),
            ],
          ),
          locale: const Locale('ar'),
        ),
      );
      expect(
        Directionality.of(tester.element(find.text('u'))),
        TextDirection.rtl,
      );
      final user = tester.getTopLeft(find.text('u'));
      final assistant = tester.getTopLeft(find.text('a'));
      expect(user.dx, lessThan(assistant.dx));
    });

    testWidgets('failed user message shows retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        harness(
          NexaMessageBubble(
            message: msg(MessageRole.user, MessageStatus.failed, 'x'),
            onRetry: () => retried = true,
          ),
        ),
      );
      expect(find.text("Couldn't send this message."), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });

    testWidgets(
      'streaming with no text shows typing indicator; static under reduced motion',
      (tester) async {
        await tester.pumpWidget(
          harness(
            NexaMessageBubble(
              message: msg(MessageRole.assistant, MessageStatus.streaming, ''),
            ),
            reducedMotion: true,
          ),
        );
        expect(find.byType(NexaTypingIndicator), findsOneWidget);
        expect(find.bySemanticsLabel('Assistant is typing'), findsOneWidget);
      },
    );
  });

  group('NexaComposer', () {
    testWidgets('sends trimmed text and clears', (tester) async {
      String? sent;
      await tester.pumpWidget(harness(NexaComposer(onSend: (t) => sent = t)));
      await tester.enterText(
        find.byKey(const Key('nexa_composer_field')),
        '  hi  ',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_composer_send')));
      expect(sent, 'hi');
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('nexa_composer_field')))
            .controller!
            .text,
        '',
      );
    });

    testWidgets('shows stop while generating', (tester) async {
      var stopped = false;
      await tester.pumpWidget(
        harness(
          NexaComposer(
            onSend: (_) {},
            isGenerating: true,
            onStop: () => stopped = true,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('nexa_composer_stop')));
      expect(stopped, isTrue);
    });

    testWidgets('Arabic hint under RTL', (tester) async {
      await tester.pumpWidget(
        harness(NexaComposer(onSend: (_) {}), locale: const Locale('ar')),
      );
      expect(find.text('اكتب رسالة'), findsOneWidget);
    });
  });

  group('NexaToolResultCard', () {
    const id = ToolCallId('t');

    testWidgets('confirmation emits confirmed / declined', (tester) async {
      final actions = <ToolAction>[];
      await tester.pumpWidget(
        harness(
          NexaToolResultCard(
            toolCallId: id,
            result: const ToolResult.confirmation(
              confirmation: ConfirmationSpec(
                id: 'c',
                title: 'Book',
                description: 'Sure?',
              ),
            ),
            onAction: actions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('nexa_confirm_c')));
      expect(actions.single, isA<ConfirmedAction>());
    });

    testWidgets('form validates required fields then submits values', (
      tester,
    ) async {
      final actions = <ToolAction>[];
      await tester.pumpWidget(
        harness(
          NexaToolResultCard(
            toolCallId: id,
            result: const ToolResult.form(
              form: FormSpec(
                id: 'f',
                title: 'Contact',
                fields: [
                  FormFieldSpec(
                    id: 'name',
                    label: 'Name',
                    type: FormFieldType.text,
                    required: true,
                  ),
                ],
              ),
            ),
            onAction: actions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('nexa_form_submit_f')));
      await tester.pump();
      expect(find.text('Required'), findsOneWidget);
      expect(actions, isEmpty);
      await tester.enterText(
        find.byKey(const Key('nexa_form_field_name')),
        'Ali',
      );
      await tester.tap(find.byKey(const Key('nexa_form_submit_f')));
      await tester.pump();
      final a = actions.single as FormSubmittedAction;
      expect(a.values, {'name': 'Ali'});
    });

    testWidgets('selection enforces single choice', (tester) async {
      final actions = <ToolAction>[];
      await tester.pumpWidget(
        harness(
          NexaToolResultCard(
            toolCallId: id,
            result: const ToolResult.selection(
              selection: SelectionSpec(
                id: 's',
                prompt: 'Pick',
                options: [
                  SelectionOption(id: 'a', label: 'A'),
                  SelectionOption(id: 'b', label: 'B'),
                ],
              ),
            ),
            onAction: actions.add,
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('nexa_option_a')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_option_b')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_selection_submit_s')));
      final a = actions.single as OptionSelectedAction;
      expect(a.optionIds, ['b']);
    });

    testWidgets('resolved cards disable controls', (tester) async {
      await tester.pumpWidget(
        harness(
          NexaToolResultCard(
            toolCallId: id,
            resolved: true,
            result: const ToolResult.confirmation(
              confirmation: ConfirmationSpec(
                id: 'c',
                title: 'Book',
                description: 'Sure?',
              ),
            ),
            onAction: (_) => fail('must not fire'),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('nexa_confirm_c')))
            .onPressed,
        isNull,
      );
    });

    testWidgets('renders every non-interactive variant without error', (
      tester,
    ) async {
      final results = <ToolResult>[
        const ToolResult.text(text: 'hi'),
        const ToolResult.richCard(
          card: RichCard(
            title: 'T',
            actions: [CardAction(id: 'a', label: 'A')],
          ),
        ),
        const ToolResult.restaurants(
          items: [
            RestaurantResult(id: 'r', name: 'R', rating: 4, openNow: true),
          ],
        ),
        const ToolResult.mapRoute(
          route: MapRoute(
            origin: GeoPoint(latitude: 1, longitude: 2),
            destination: GeoPoint(latitude: 3, longitude: 4),
            distanceMeters: 1500,
            duration: Duration(minutes: 5),
          ),
        ),
        ToolResult.weather(
          weather: WeatherData(
            locationName: 'B',
            temperatureC: 30,
            condition: 'Clear',
            forecast: [
              DailyForecast(
                date: DateTime(2026, 10, 23),
                highC: 33,
                lowC: 20,
                condition: 'Clear',
              ),
            ],
          ),
        ),
        ToolResult.media(
          items: [
            MediaItem(kind: MediaKind.video, uri: Uri.parse('https://x/v.mp4')),
          ],
        ),
        const ToolResult.error(
          error: ToolError(code: 'invalid_tool_result', message: 'bad'),
        ),
      ];
      for (final r in results) {
        await tester.pumpWidget(
          harness(
            SingleChildScrollView(
              child: NexaToolResultCard(
                toolCallId: id,
                result: r,
                onAction: (_) {},
              ),
            ),
          ),
        );
        expect(
          tester.takeException(),
          isNull,
          reason: r.runtimeType.toString(),
        );
      }
      expect(
        find.text("The assistant returned something we couldn't display."),
        findsOneWidget,
      );
    });
  });

  group('Localization', () {
    testWidgets('direction follows locale', (tester) async {
      expect(NexaLocale.directionOf(const Locale('ar')), TextDirection.rtl);
      expect(NexaLocale.directionOf(const Locale('en')), TextDirection.ltr);
      expect(NexaLocale.fromTag('ar-IQ').languageCode, 'ar');
      expect(NexaLocale.fromTag('fr').languageCode, 'en');
    });
  });
}
