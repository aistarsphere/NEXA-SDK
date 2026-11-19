import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

void main() {
  group('nexaTextDirectionOf', () {
    test('first strong character decides', () {
      expect(nexaTextDirectionOf('Hello, عالم'), TextDirection.ltr);
      expect(nexaTextDirectionOf('مرحبا world'), TextDirection.rtl);
      expect(nexaTextDirectionOf('123 — مرحبا'), TextDirection.rtl);
      expect(nexaTextDirectionOf('**Bold** text'), TextDirection.ltr);
      expect(nexaTextDirectionOf('42 😊'), isNull);
    });
  });

  group('NexaRichText', () {
    String plain(WidgetTester tester) => tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('\n');

    testWidgets('renders headings, lists and inline marks without syntax', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          const NexaRichText(
            '### Data & Analysis\n'
            '- Analyze **trends** in text\n'
            '2. Use `code` and *care*\n'
            '\n'
            'What would you like help with today?',
          ),
        ),
      );
      final text = plain(tester);
      expect(text, contains('Data & Analysis'));
      expect(text, contains('Analyze trends in text'));
      expect(text, contains('Use code and care'));
      expect(text, isNot(contains('**')));
      expect(text, isNot(contains('###')));
      expect(find.text('•'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
    });

    testWidgets('an English reply stays LTR inside the Arabic UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(
          NexaMessageBubble(
            message: ChatMessage(
              id: const MessageId('m'),
              role: MessageRole.assistant,
              text: 'Analyze trends in text data.',
              status: MessageStatus.completed,
              createdAt: DateTime(2026),
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      final rich = tester.widget<RichText>(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText() == 'Analyze trends in text data.',
        ),
      );
      expect(rich.textDirection, TextDirection.ltr);
      expect(find.byKey(const Key('nexa_message_copy')), findsOneWidget);
    });

    testWidgets('unterminated code fence while streaming is still shown', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(const NexaRichText('Try:\n```\nprint(1)')),
      );
      expect(plain(tester), contains('print(1)'));
    });
  });
}
