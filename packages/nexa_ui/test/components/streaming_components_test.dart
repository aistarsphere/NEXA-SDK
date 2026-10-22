import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

ChatMessage streaming(String text) => ChatMessage(
  id: const MessageId('m'),
  role: MessageRole.assistant,
  status: MessageStatus.streaming,
  createdAt: DateTime(2026),
  text: text,
);

void main() {
  group('NexaStreamingCaret', () {
    testWidgets('animates by default and is static under reduced motion', (
      tester,
    ) async {
      final fade = find.descendant(
        of: find.byType(NexaStreamingCaret),
        matching: find.byType(FadeTransition),
      );
      await tester.pumpWidget(harness(const NexaStreamingCaret()));
      final animated = tester.widget<FadeTransition>(fade);
      await tester.pump(const Duration(milliseconds: 350));
      expect(animated.opacity.value, isNot(1.0));

      await tester.pumpWidget(
        harness(const NexaStreamingCaret(), reducedMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 350));
      final still = tester.widget<FadeTransition>(fade);
      expect(still.opacity.value, 1.0);
    });

    testWidgets('bubble shows caret only while streaming with text', (
      tester,
    ) async {
      await tester.pumpWidget(
        harness(NexaMessageBubble(message: streaming('partial'))),
      );
      expect(find.byType(NexaStreamingCaret), findsOneWidget);
      expect(find.byType(NexaTypingIndicator), findsNothing);
      await tester.pumpWidget(
        harness(NexaMessageBubble(message: streaming(''))),
      );
      expect(find.byType(NexaStreamingCaret), findsNothing);
      expect(find.byType(NexaTypingIndicator), findsOneWidget);
      await tester.pumpWidget(
        harness(
          NexaMessageBubble(
            message: streaming(
              'done',
            ).copyWith(status: MessageStatus.completed),
          ),
        ),
      );
      expect(find.byType(NexaStreamingCaret), findsNothing);
    });
  });

  group('NexaJumpToLatestButton', () {
    testWidgets(
      'hidden state ignores taps; visible state fires and is labelled',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          harness(
            NexaJumpToLatestButton(visible: false, onPressed: () => taps++),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('nexa_jump_to_latest')),
          warnIfMissed: false,
        );
        expect(taps, 0);
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(
          harness(
            NexaJumpToLatestButton(visible: true, onPressed: () => taps++),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('nexa_jump_to_latest')));
        expect(taps, 1);
        expect(find.bySemanticsLabel('Jump to latest'), findsOneWidget);
        handle.dispose();
      },
    );

    testWidgets('Arabic label', (tester) async {
      await tester.pumpWidget(
        harness(
          NexaJumpToLatestButton(visible: true, onPressed: () {}),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('الانتقال إلى الأحدث'), findsOneWidget);
    });
  });

  group('NexaLiveAnnouncer', () {
    testWidgets('exposes a live region with the message, nothing when empty', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(harness(const NexaLiveAnnouncer(message: null)));
      expect(
        find.descendant(
          of: find.byType(NexaLiveAnnouncer),
          matching: find.byType(Semantics),
        ),
        findsNothing,
      );
      await tester.pumpWidget(
        harness(const NexaLiveAnnouncer(message: 'Assistant finished')),
      );
      final node = tester.getSemantics(
        find.bySemanticsLabel('Assistant finished'),
      );
      expect(node.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
