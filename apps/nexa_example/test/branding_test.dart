// The approved AMEER logo and the assets generated from it (see
// docs/mobile/AMEER_BRANDING.md): the bundled logo, the Android launcher /
// adaptive / monochrome / splash / notification resources, and where the app
// shows its own brand.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/brand/ameer_logo.dart';
import 'package:nexa_example/brand/labeeb_brand.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';
import 'package:nexa_example/main.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

const res = 'android/app/src/main/res';

Future<({int w, int h, Uint8List rgba})> decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!;
  return (w: image.width, h: image.height, rgba: data.buffer.asUint8List());
}

/// The decoder returns premultiplied alpha: a white pixel of alpha `a` has
/// R = G = B = a.
void expectWhite(
  ({int w, int h, Uint8List rgba}) im,
  int pixel, {
  String? reason,
}) {
  final a = im.rgba[pixel * 4 + 3];
  for (var k = 0; k < 3; k++) {
    expect(
      (im.rgba[pixel * 4 + k] - a).abs(),
      lessThanOrEqualTo(2),
      reason: '${reason ?? ''} pixel $pixel is not white',
    );
  }
}

double dist(num dx, num dy) => math.sqrt(dx * dx + dy * dy);

int alphaAt(({int w, int h, Uint8List rgba}) im, int x, int y) =>
    im.rgba[(y * im.w + x) * 4 + 3];

void main() {
  const densities = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  group('the approved logo', () {
    test('the source exists and is a transparent RGBA PNG', () async {
      final f = File('assets/new_logo.png');
      expect(f.existsSync(), isTrue, reason: 'single source of truth');
      final im = await decode(f.readAsBytesSync());
      expect((im.w, im.h), (1536, 1024));
      expect(alphaAt(im, 0, 0), 0, reason: 'transparent corner');
      expect(alphaAt(im, im.w - 1, im.h - 1), 0);
    });

    testWidgets('the bundled logo is square, transparent and not stretched', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final data = await rootBundle.load(AmeerLogo.asset);
        final im = await decode(data.buffer.asUint8List());
        expect(im.w, im.h);
        expect(alphaAt(im, 0, 0), 0);
        expect(alphaAt(im, im.w ~/ 2, im.h ~/ 2), greaterThan(200));
      });
    });

    testWidgets('AmeerLogo keeps a square slot and its spoken name', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: AmeerLogo(size: 48))),
      );
      expect(tester.getSize(find.byType(Image)), const Size(48, 48));
      expect(find.bySemanticsLabel('AMEER'), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.contain);
      expect(image.color, isNull, reason: 'never tinted');
    });
  });

  group('android launcher resources', () {
    test('adaptive icon declares background, foreground and monochrome', () {
      for (final name in ['ic_launcher', 'ic_launcher_round']) {
        final xml = File('$res/mipmap-anydpi-v26/$name.xml').readAsStringSync();
        expect(
          xml,
          contains(
            '<background android:drawable="@color/ic_launcher_background"',
          ),
        );
        expect(xml, contains('@drawable/ic_launcher_foreground'));
        expect(
          xml,
          contains(
            '<monochrome android:drawable="@drawable/ic_launcher_monochrome"',
          ),
        );
      }
      expect(
        File('$res/values/colors.xml').readAsStringSync(),
        contains('<color name="ic_launcher_background">#2E1C13</color>'),
      );
    });

    test('every density has the layers with the right size', () async {
      for (final MapEntry(key: d, value: scale) in densities.entries) {
        for (final name in [
          'ic_launcher_foreground',
          'ic_launcher_monochrome',
        ]) {
          final f = File('$res/drawable-$d/$name.png');
          expect(f.existsSync(), isTrue, reason: '$d $name');
          final im = await decode(f.readAsBytesSync());
          expect(im.w, (108 * scale).round(), reason: '$d $name');
          expect(im.h, im.w);
        }
        for (final name in ['ic_launcher', 'ic_launcher_round']) {
          final im = await decode(
            File('$res/mipmap-$d/$name.png').readAsBytesSync(),
          );
          expect(im.w, (48 * scale).round(), reason: '$d $name');
        }
      }
    });

    test(
      'the symbol stays inside the 66 dp safe circle (no clipping)',
      () async {
        for (final MapEntry(key: d, value: scale) in densities.entries) {
          final im = await decode(
            File(
              '$res/drawable-$d/ic_launcher_foreground.png',
            ).readAsBytesSync(),
          );
          final c = im.w / 2;
          final safe = 33 * scale + 1; // radius of the 66 dp circle
          var farthest = 0.0;
          for (var y = 0; y < im.h; y++) {
            for (var x = 0; x < im.w; x++) {
              if (alphaAt(im, x, y) >= 24) {
                farthest = math.max(farthest, dist(x + .5 - c, y + .5 - c));
              }
            }
          }
          expect(farthest, lessThanOrEqualTo(safe), reason: d);
          expect(farthest, greaterThan(safe * .6), reason: '$d: not tiny');
        }
      },
    );

    test('the monochrome layer is white with transparency only', () async {
      final im = await decode(
        File(
          '$res/drawable-xxxhdpi/ic_launcher_monochrome.png',
        ).readAsBytesSync(),
      );
      var visible = 0;
      for (var i = 0; i < im.w * im.h; i++) {
        final a = im.rgba[i * 4 + 3];
        if (a == 0) continue;
        visible++;
        expectWhite(im, i);
      }
      expect(visible, greaterThan(1000));
    });

    test('the app name is AMEER (أمير in Arabic) and icons are wired', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest, contains('android:label="@string/app_name"'));
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(
        manifest,
        contains('android:roundIcon="@mipmap/ic_launcher_round"'),
      );
      expect(
        File('$res/values/strings.xml').readAsStringSync(),
        contains('>AMEER<'),
      );
      expect(
        File('$res/values-ar/strings.xml').readAsStringSync(),
        contains('>أمير<'),
      );
    });
  });

  group('splash', () {
    test('Android 12+ and earlier versions, light and dark', () {
      for (final f in ['values-v31', 'values-night-v31']) {
        final xml = File('$res/$f/styles.xml').readAsStringSync();
        expect(xml, contains('windowSplashScreenBackground'));
        expect(xml, contains('@drawable/ic_splash_icon'));
        expect(
          xml,
          isNot(contains('windowSplashScreenAnimationDuration')),
          reason: 'no extra delay or animation',
        );
      }
      for (final f in ['drawable', 'drawable-v21']) {
        final xml = File('$res/$f/launch_background.xml').readAsStringSync();
        expect(xml, contains('@drawable/ic_splash_icon'));
        expect(xml, contains('@color/labeeb_launch_background'));
      }
      expect(
        File('$res/values/colors.xml').readAsStringSync(),
        contains('#F7F3F0'),
      );
      expect(
        File('$res/values-night/colors.xml').readAsStringSync(),
        contains('#110D0B'),
      );
    });

    test('the splash icon fits the 192 dp circle of a 288 dp canvas', () async {
      for (final MapEntry(key: d, value: scale) in densities.entries) {
        final im = await decode(
          File('$res/drawable-$d/ic_splash_icon.png').readAsBytesSync(),
        );
        expect(im.w, (288 * scale).round(), reason: d);
        final c = im.w / 2;
        var farthest = 0.0;
        for (var y = 0; y < im.h; y += 2) {
          for (var x = 0; x < im.w; x += 2) {
            if (alphaAt(im, x, y) >= 24) {
              farthest = math.max(farthest, dist(x - c, y - c));
            }
          }
        }
        expect(farthest, lessThanOrEqualTo(96 * scale + 2), reason: d);
      }
    });
  });

  group('notification icon', () {
    test('a white silhouette on transparent at every density', () async {
      for (final MapEntry(key: d, value: scale) in densities.entries) {
        final im = await decode(
          File('$res/drawable-$d/nexa_notification_icon.png').readAsBytesSync(),
        );
        expect(im.w, (24 * scale).round(), reason: d);
        var visible = 0;
        for (var i = 0; i < im.w * im.h; i++) {
          if (im.rgba[i * 4 + 3] == 0) continue;
          visible++;
          expectWhite(im, i, reason: d);
        }
        expect(visible, greaterThan(20), reason: d);
        expect(
          visible,
          lessThan(im.w * im.h * 0.9),
          reason: '$d is not a blob',
        );
      }
    });

    test('the plugin prefers it and the shrinker keeps it', () {
      final kt = File(
        '../../packages/nexa_assistant/android/src/main/kotlin/com/nexa/assistant/Activation.kt',
      ).readAsStringSync();
      expect(kt, contains('"nexa_notification_icon"'));
      expect(kt, contains('R.drawable.nexa_assistant_mic'), reason: 'fallback');
      expect(
        File('$res/raw/keep.xml').readAsStringSync(),
        contains('@drawable/nexa_notification_icon'),
      );
    });

    test('channels and ids are unchanged', () {
      final svc = File(
        '../../packages/nexa_assistant/android/src/main/kotlin/com/nexa/assistant/CallForegroundService.kt',
      ).readAsStringSync();
      expect(svc, contains('CHANNEL = "nexa_call"'));
      expect(svc, contains('NOTIFICATION_ID = 0x4E41'));
    });
  });

  group('names', () {
    test('AMEER | أمير', () {
      expect(Labeeb.nameEn, 'AMEER');
      expect(Labeeb.nameAr, 'أمير');
      expect(Labeeb.name('ar'), 'أمير');
      expect(Labeeb.logoAsset, AmeerLogo.asset);
    });

    test(
      'the wake phrase is a detector setting, not renamed with the brand',
      () {
        // The on-device detector is enrolled on this phrase; a visible rename
        // alone would not make it recognise another one (see AMEER_BRANDING.md).
        final src = File(
          'lib/assistant/device_assistant.dart',
        ).readAsStringSync();
        expect(src, contains("wakePhrase = 'يا لبيب'"));
      },
    );
  });

  group('no old brand left in visible labels', () {
    test('the default palette is named AMEER Mocha', () {
      final src = File(
        'lib/brand/labeeb_theme_controller.dart',
      ).readAsStringSync();
      expect(src, contains("en: 'AMEER Mocha'"));
      expect(src, contains("ar: 'أمير موكا'"));
      expect(src, isNot(contains('LABEEB Mocha')));
      expect(src, isNot(contains('لبيب موكا')));
    });

    test('user-facing string files only keep the wake phrase', () {
      for (final f in [
        'lib/assistant/app_strings.dart',
        'lib/assistant/device_assistant_strings.dart',
      ]) {
        final text = File(f).readAsStringSync();
        expect(text.contains('LABEEB'), isFalse, reason: f);
        // «يا لبيب» is the detector's phrase; any other use is an old name.
        final stripped = text.replaceAll('يا لبيب', '');
        expect(stripped.contains('لبيب'), isFalse, reason: f);
      }
    });
  });

  group('where the app shows its brand', () {
    Future<NexaClient> client() async {
      final c = await Nexa.initialize(
        config: NexaConfig(
          applicationId: 'app_test',
          gatewayBaseUri: Uri.parse('http://localhost'),
          environment: NexaEnvironment.development,
          requestedCapabilities: const {NexaCapability.textChat},
        ),
        auth: MockAuthProvider(),
        overrides: NexaOverrides(
          chatTransport: MockChatTransport(
            tokenDelay: Duration.zero,
            thinkDelay: Duration.zero,
          ),
        ),
      );
      addTearDown(c.dispose);
      return c;
    }

    Future<void> phone(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    testWidgets('the assistant header shows the AMEER logo and name', (
      tester,
    ) async {
      await phone(tester);
      await tester.runAsync(Labeeb.loadAssets);
      final c = await client();
      await tester.pumpWidget(
        ExampleApp(
          client: c,
          auth: MockAuthProvider(),
          initialLocation: '/c/new',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AmeerLogo), findsWidgets);
      expect(find.text('AMEER'), findsWidgets);
      expect(find.text('LABEEB'), findsNothing);
    });

    testWidgets('settings About shows the logo, name and version', (
      tester,
    ) async {
      await phone(tester);
      await tester.runAsync(Labeeb.loadAssets);
      final c = await client();
      await tester.pumpWidget(
        ExampleApp(
          client: c,
          auth: MockAuthProvider(),
          initialLocation: '/settings',
        ),
      );
      await tester.pumpAndSettle();
      final about = find.byKey(const Key('settings_about'));
      await tester.scrollUntilVisible(about, 300);
      expect(
        find.descendant(of: about, matching: find.byType(AmeerLogo)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: about, matching: find.text('AMEER')),
        findsOneWidget,
      );
    });

    testWidgets('the not-connected screen shows the logo', (tester) async {
      await phone(tester);
      final c = await client();
      await tester.pumpWidget(
        ExampleApp(client: c, auth: DevTokenAuthProvider()),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('assistant_not_connected_logo')),
        findsOneWidget,
      );
    });
  });
}
