// Plan G-02: components stay usable at 200 % text on a small phone.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

Future<void> smallPhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2220); // 360 x 740 dp
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  layoutTests();
  for (final locale in [const Locale('en'), const Locale('ar')]) {
    group('${locale.languageCode} at 200 % text', () {
      testWidgets('a banner with a long message and an action fits', (
        tester,
      ) async {
        await smallPhone(tester);
        var taps = 0;
        await tester.pumpWidget(
          harness(
            NexaStatusBanner(
              key: const Key('banner'),
              tone: NexaBannerTone.error,
              message: locale.languageCode == 'ar'
                  ? 'تعذّر الاتصال بالمساعد. تحقق من الشبكة ثم حاول مرة أخرى.'
                  : 'Could not reach the assistant. Check your network, then try again.',
              actionLabel: locale.languageCode == 'ar'
                  ? 'حاول مرة أخرى'
                  : 'Try again',
              onAction: () => taps++,
            ),
            locale: locale,
          ),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(TextButton));
        expect(taps, 1);
        // The action stays a full-size touch target.
        expect(
          tester.getSize(find.byType(TextButton)).height,
          greaterThanOrEqualTo(48),
        );
      });

      testWidgets('the call capsule with an error banner fits', (tester) async {
        await smallPhone(tester);
        await tester.pumpWidget(
          harness(
            SizedBox(
              width: 360,
              height: 740,
              child: NexaVoiceCapsule(
                state: VoiceState.microphoneDenied,
                transcript: [
                  VoiceTranscriptEntry(
                    speaker: VoiceSpeaker.user,
                    text: 'مرحبا كيف حالك اليوم',
                    isFinal: true,
                    at: DateTime(2026),
                  ),
                ],
                muted: false,
                error: const PermissionDeniedException('microphone'),
                onRetry: () {},
                onOpenSettings: () {},
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      });

      testWidgets('the call capsule in a live call fits', (tester) async {
        await smallPhone(tester);
        await tester.pumpWidget(
          harness(
            SizedBox(
              width: 360,
              height: 740,
              child: NexaVoiceCapsule(
                state: VoiceState.reconnecting,
                transcript: const [],
                muted: false,
                agentPresent: true,
                onEnd: () {},
                onToggleMute: () {},
              ),
            ),
            locale: locale,
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('nexa_voice_end')), findsOneWidget);
        expect(find.byKey(const Key('nexa_voice_mute')), findsOneWidget);
      });
    });
  }
}

/// The controls panel belongs at the bottom of the call screen: nothing may
/// leave a blank band under it (regression: a flexible banner area took half
/// of the free height even when empty).
void layoutTests() {
  for (final scale in [1.0, 2.0]) {
    for (final state in [
      VoiceState.listening,
      VoiceState.reconnecting,
      VoiceState.microphoneDenied,
    ]) {
      testWidgets('the call panel sits at the bottom ($state, x$scale)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1080, 2220); // 360 x 740 dp
        tester.view.devicePixelRatio = 3;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: NexaLocale.delegates,
            supportedLocales: NexaLocale.supported,
            home: Scaffold(
              body: NexaVoiceCapsule(
                state: state,
                transcript: const [],
                muted: false,
                agentPresent: true,
                error: state == VoiceState.microphoneDenied
                    ? const PermissionDeniedException('microphone')
                    : null,
                onEnd: () {},
                onToggleMute: () {},
                onStart: () {},
                onRetry: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
        final end = state == VoiceState.microphoneDenied
            ? find.byKey(const Key('nexa_voice_start'))
            : find.byKey(const Key('nexa_voice_end'));
        final bottom = tester.getBottomLeft(end).dy;
        // Within the bottom 18 % of the 740 dp screen (safe area included).
        expect(bottom, greaterThan(740 * 0.82), reason: 'blank band below');
      });
    }
  }
}
