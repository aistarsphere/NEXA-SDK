import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/brand/labeeb_palette.dart';
import 'package:nexa_example/brand/labeeb_theme_controller.dart';
import 'package:nexa_example/dev/demo_surfaces.dart';
import 'package:nexa_example/dev/dynamic_ui_gallery_page.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('labeeb_theme'));
  tearDown(() => dir.deleteSync(recursive: true));
  File prefs() => File('${dir.path}/labeeb_theme.json');

  group('LabeebThemeController', () {
    test('defaults to the original (Mocha, system) without a file', () async {
      final c = await LabeebThemeController.load(prefs());
      expect(c.appliedPaletteId, 'pal_mocha');
      expect(c.appliedAppearance, NexaAppearance.system);
      expect(c.palettes, hasLength(6));
      expect(c.colors(Brightness.light).$1, LabeebPalette.light);
    });

    test('preview is temporary; cancel restores; nothing persisted', () async {
      final c = await LabeebThemeController.load(prefs());
      expect(await c.preview('pal_ruby', NexaAppearance.dark), isTrue);
      expect(c.effectivePalette, 'pal_ruby');
      expect(c.themeMode, ThemeMode.dark);
      expect(c.appliedPaletteId, 'pal_mocha');
      expect(c.colors(Brightness.dark).$1.primary, const Color(0xFFFF9C93));
      await c.cancelPreview();
      expect(c.effectivePalette, 'pal_mocha');
      expect(c.themeMode, ThemeMode.system);
      expect(prefs().existsSync(), isFalse);
    });

    test('apply persists across loads; reset returns to original', () async {
      final c = await LabeebThemeController.load(prefs());
      expect(await c.apply('pal_ocean', NexaAppearance.light), isTrue);
      final again = await LabeebThemeController.load(prefs());
      expect(again.appliedPaletteId, 'pal_ocean');
      expect(again.appliedAppearance, NexaAppearance.light);
      await again.reset();
      final third = await LabeebThemeController.load(prefs());
      expect(third.appliedPaletteId, 'pal_mocha');
      expect(third.appliedAppearance, NexaAppearance.system);
    });

    test('unknown palette refused; corrupt file falls back', () async {
      final c = await LabeebThemeController.load(prefs());
      expect(await c.preview('pal_neon', NexaAppearance.dark), isFalse);
      expect(await c.apply('pal_neon', NexaAppearance.dark), isFalse);
      prefs().writeAsStringSync('{not json');
      final d = await LabeebThemeController.load(prefs());
      expect(d.appliedPaletteId, 'pal_mocha');
    });
  });

  Future<NexaClient> client(NexaHostCapabilities host) async {
    final c = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {NexaCapability.textChat},
      ),
      auth: MockAuthProvider(),
      host: host,
      overrides: NexaOverrides(chatTransport: MockChatTransport()),
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> phone(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('settings → theme picker previews app-wide; cancel restores', (
    tester,
  ) async {
    await phone(tester);
    final theme = (await tester.runAsync(
      () => LabeebThemeController.load(prefs()),
    ))!;
    final c = await client(NexaHostCapabilities(theme: theme));
    await tester.pumpWidget(
      ExampleApp(
        client: c,
        auth: MockAuthProvider(),
        theme: theme,
        initialLocation: '/settings',
      ),
    );
    await tester.pumpAndSettle();
    Color primary() => Theme.of(
      tester.element(find.byType(Scaffold).first),
    ).colorScheme.primary;
    final original = primary();

    await tester.tap(find.byKey(const Key('settings_color_theme')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_surface_sheet')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_palette_pal_forest')));
    await tester.pumpAndSettle();
    expect(theme.previewing, isTrue);
    expect(primary(), isNot(original), reason: 'preview is app-wide');

    await tester.tap(find.byKey(const Key('nexa_action_a_cancel')).first);
    await tester.pumpAndSettle();
    expect(theme.previewing, isFalse);
    expect(primary(), original);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings without a host theme: no color theme tile', (
    tester,
  ) async {
    await phone(tester);
    final c = await client(const NexaHostCapabilities());
    await tester.pumpWidget(
      ExampleApp(
        client: c,
        auth: MockAuthProvider(),
        initialLocation: '/settings',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings_theme')), findsOneWidget);
    expect(find.byKey(const Key('settings_color_theme')), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('gallery renders every category and state ($lang)', (
      tester,
    ) async {
      await phone(tester);
      final c = await client(const NexaHostCapabilities());
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          supportedLocales: NexaLocale.supported,
          localizationsDelegates: NexaLocale.delegates,
          home: DynamicUiGalleryPage(client: c),
        ),
      );
      await tester.pump();
      final ids = [
        'demo_theme',
        for (final j in [
          ...demoSurfaces(arabic: lang == 'ar'),
          ...demoStateSurfaces(arabic: lang == 'ar'),
        ])
          j['surface_id']! as String,
      ];
      expect(
        {
          'themes_appearance', // built from the host (see the gallery)
          for (final j in demoSurfaces(arabic: false)) j['category'],
        },
        {for (final cat in NexaSurfaceCategory.values) cat.wire},
        reason: 'one demo per category',
      );
      // A future schema has no tree of its own: only its fallback renders.
      final targets = [
        for (final id in ids)
          id == 'demo_state_future_schema'
              ? const Key('nexa_surface_unsupported')
              : Key('nexa_surface_$id'),
      ];
      for (final key in targets) {
        await tester.scrollUntilVisible(
          find.byKey(key),
          300,
          scrollable: find.byType(Scrollable).first,
        );
      }
      expect(find.byKey(const Key('nexa_surface_demo')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
