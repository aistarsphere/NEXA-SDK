import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// WCAG 2.x relative luminance contrast ratio.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('Mocha theme accessibility baseline', () {
    for (final brightness in Brightness.values) {
      final theme = NexaTheme.forBrightness(brightness, const Locale('en'));
      final s = theme.colorScheme;
      final n = theme.extension<NexaColors>()!;

      final pairs = <String, (Color, Color)>{
        'onSurface/surface': (s.onSurface, s.surface),
        'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
        'onPrimary/primary': (s.onPrimary, s.primary),
        'onPrimaryContainer/primaryContainer': (
          s.onPrimaryContainer,
          s.primaryContainer,
        ),
        'onSecondaryContainer/secondaryContainer': (
          s.onSecondaryContainer,
          s.secondaryContainer,
        ),
        'onError/error': (s.onError, s.error),
        'onErrorContainer/errorContainer': (
          s.onErrorContainer,
          s.errorContainer,
        ),
        'onUserBubble/userBubble': (n.onUserBubble, n.userBubble),
        'onAssistantBubble/assistantBubble': (
          n.onAssistantBubble,
          n.assistantBubble,
        ),
        'onSuccess/success': (n.onSuccess, n.success),
        'onWarning/warning': (n.onWarning, n.warning),
      };

      for (final entry in pairs.entries) {
        test('${brightness.name}: ${entry.key} >= 4.5:1', () {
          final ratio = contrast(entry.value.$1, entry.value.$2);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} = ${ratio.toStringAsFixed(2)}',
          );
        });
      }

      test(
        '${brightness.name}: primary on surface >= 3:1 (UI component contrast)',
        () {
          expect(contrast(s.primary, s.surface), greaterThanOrEqualTo(3));
        },
      );
    }

    test('uses bundled fonts, not network fonts', () {
      final en = NexaTheme.light(const Locale('en'));
      final ar = NexaTheme.light(const Locale('ar'));
      expect(en.textTheme.bodyLarge!.fontFamily, contains('NotoSans'));
      expect(ar.textTheme.bodyLarge!.fontFamily, contains('Tajawal'));
    });

    test('host overrides stay within approved bounds', () {
      expect(
        () => NexaThemeOverrides(cornerScale: 2),
        throwsA(isA<AssertionError>()),
      );
      final themed = NexaTheme.light(
        const Locale('en'),
        overrides: const NexaThemeOverrides(userBubbleColor: Color(0xFF102030)),
      );
      final n = themed.extension<NexaColors>()!;
      expect(contrast(n.onUserBubble, n.userBubble), greaterThanOrEqualTo(4.5));
    });

    test('touch targets are at least 48dp', () {
      final theme = NexaTheme.light(const Locale('en'));
      final size = theme.filledButtonTheme.style!.minimumSize!.resolve({});
      expect(size!.height, greaterThanOrEqualTo(48));
    });
  });
}
