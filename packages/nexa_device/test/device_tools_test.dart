import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_ui/nexa_ui.dart';

final class FakeLocation implements LocationPlatform {
  FakeLocation({
    this.service = true,
    this.state = LocationPermissionState.notDetermined,
    this.afterRequest = LocationPermissionState.granted,
    this.fixError,
  });

  bool service;
  LocationPermissionState state;
  LocationPermissionState afterRequest;
  ClientToolErrorCode? fixError;
  int requests = 0;

  @override
  Future<bool> serviceEnabled() async => service;
  @override
  Future<LocationPermissionState> permission() async => state;
  @override
  Future<LocationPermissionState> requestPermission() async {
    requests++;
    return state = afterRequest;
  }

  @override
  Future<LocationFix> currentFix({
    required bool highAccuracy,
    required Duration timeout,
  }) async {
    if (fixError != null) throw LocationFixException(fixError!);
    return LocationFix(
      latitude: 33.3152,
      longitude: 44.3661,
      accuracyMeters: 12.4,
      timestamp: DateTime.utc(2026, 10, 28, 9),
    );
  }

  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

final class FakeOpener implements UrlOpener {
  FakeOpener({this.app = true, this.browser = true});
  final bool app;
  final bool browser;
  final opened = <(String, Uri)>[];

  @override
  Future<bool> openInApp(Uri uri) async {
    if (app) opened.add(('app', uri));
    return app;
  }

  @override
  Future<bool> openInBrowser(Uri uri) async {
    if (browser) opened.add(('browser', uri));
    return browser;
  }

  @override
  Future<bool> canOpen(Uri uri) async => app;
}

ClientToolRequest req(String tool, [Map<String, Object?> args = const {}]) =>
    ClientToolRequest(
      callId: 'c',
      toolId: tool,
      version: 1,
      arguments: args,
      origin: ClientToolOrigin.user,
    );

void main() {
  group('device.location.get_current', () {
    Future<ClientToolResult> run(FakeLocation p) => LocationTool(
      platform: p,
    ).execute(req(LocationTool.id), onPhase: (_) {});

    test(
      'asks permission only when needed, returns a structured fix',
      () async {
        final p = FakeLocation();
        final r = await run(p);
        expect(r.isSuccess, isTrue);
        expect(p.requests, 1);
        expect(r.output!['latitude'], 33.3152);
        expect(r.output!['accuracy_m'], 12.4);
        expect(r.output!['timestamp'], '2026-10-28T09:00:00.000Z');
        expect(r.output!.containsKey('address'), isFalse); // never invented
        final again = await run(p);
        expect(again.isSuccess, isTrue);
        expect(p.requests, 1);
      },
    );

    test('denied, blocked, service off and timeout are structured', () async {
      final denied = await run(
        FakeLocation(afterRequest: LocationPermissionState.denied),
      );
      expect(denied.error!.code, ClientToolErrorCode.permissionDenied);
      expect(denied.error!.retryable, isTrue);

      final blocked = await run(
        FakeLocation(state: LocationPermissionState.blocked),
      );
      expect(blocked.error!.code, ClientToolErrorCode.permissionBlocked);
      expect(blocked.error!.canOpenSettings, isTrue);

      final off = await run(FakeLocation(service: false));
      expect(off.error!.code, ClientToolErrorCode.serviceDisabled);
      expect(off.error!.canOpenSettings, isTrue);

      final slow = await run(
        FakeLocation(
          state: LocationPermissionState.granted,
          fixError: ClientToolErrorCode.timeout,
        ),
      );
      expect(slow.error!.code, ClientToolErrorCode.timeout);
      expect(slow.error!.retryable, isTrue);
    });

    test('availability reflects permission without prompting', () async {
      final p = FakeLocation(state: LocationPermissionState.blocked);
      expect(
        await LocationTool(platform: p).availability(),
        ClientToolAvailability.permissionBlocked,
      );
      expect(p.requests, 0);
    });
  });

  group('maps.open_directions', () {
    test('builds a validated api=1 URL to a specific destination', () {
      final url = googleMapsDirectionsUrl(
        latitude: 33.3152,
        longitude: 44.3661,
        placeId: 'ChIJ_sample_place_0001',
        travelMode: 'walking',
      )!;
      expect(url.scheme, 'https');
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters, {
        'api': '1',
        'destination': '33.315200,44.366100',
        'destination_place_id': 'ChIJ_sample_place_0001',
        'travelmode': 'walking',
      });
      final byName = googleMapsDirectionsUrl(
        placeId: 'ChIJ_sample_place_0002',
        name: 'مطعم تجريبي',
      )!;
      expect(byName.queryParameters['destination'], 'مطعم تجريبي');
    });

    test('rejects vague or invalid destinations', () {
      expect(googleMapsDirectionsUrl(name: 'somewhere'), isNull);
      expect(googleMapsDirectionsUrl(latitude: 91, longitude: 0), isNull);
      expect(
        googleMapsDirectionsUrl(
          latitude: 1,
          longitude: 1,
          placeId: 'bad id; rm',
        ),
        isNull,
      );
      expect(
        googleMapsDirectionsUrl(latitude: 1, longitude: 1, travelMode: 'fly'),
        isNull,
      );
    });

    test('opens the maps app, else falls back to the browser', () async {
      final args = {'latitude': 1.5, 'longitude': 2.5};
      final app = FakeOpener();
      final r1 = await DirectionsTool(
        opener: app,
      ).execute(req(DirectionsTool.id, args), onPhase: (_) {});
      expect(r1.output!['opened_in'], 'app');
      final web = FakeOpener(app: false);
      final r2 = await DirectionsTool(
        opener: web,
      ).execute(req(DirectionsTool.id, args), onPhase: (_) {});
      expect(r2.output!['opened_in'], 'browser');
      expect(web.opened.single.$1, 'browser');
      final none = await DirectionsTool(
        opener: FakeOpener(app: false, browser: false),
      ).execute(req(DirectionsTool.id, args), onPhase: (_) {});
      expect(none.error!.code, ClientToolErrorCode.unsupported);
      final invalid = await DirectionsTool(
        opener: app,
      ).execute(req(DirectionsTool.id, {'name': 'x'}), onPhase: (_) {});
      expect(invalid.error!.code, ClientToolErrorCode.invalidArguments);
    });
  });

  group('camera capture screen', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('nexa_cam'));
    tearDown(() => tmp.deleteSync(recursive: true));

    Widget host(Widget child) => MaterialApp(
      localizationsDelegates: NexaLocale.delegates,
      supportedLocales: NexaLocale.supported,
      home: child,
    );

    /// Opens the screen; the outcome lands in the returned list on pop.
    Future<List<CameraCaptureOutcome?>> open(
      WidgetTester tester,
      FakeCameraSession session,
    ) async {
      final outcomes = <CameraCaptureOutcome?>[];
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => outcomes.add(
                await Navigator.of(context).push(
                  MaterialPageRoute<CameraCaptureOutcome>(
                    builder: (_) => NexaCameraCaptureScreen(
                      sessionFactory: () => session,
                      onOpenSettings: () {},
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return outcomes;
    }

    Future<void> shutter(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('nexa_camera_shutter')));
      await tester.pumpAndSettle();
    }

    testWidgets('preview → capture → review → retake → use', (tester) async {
      final session = FakeCameraSession(tmp);
      final outcomes = await open(tester, session);
      expect(find.byKey(const Key('fake_preview')), findsOneWidget);
      await shutter(tester);
      expect(find.byKey(const Key('nexa_camera_review')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_camera_retake')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fake_preview')), findsOneWidget);
      await shutter(tester);
      await tester.tap(find.byKey(const Key('nexa_camera_use')));
      await tester.pumpAndSettle();
      expect(session.pictures, 2);
      expect(outcomes.single, isA<CameraCaptured>());
      expect((outcomes.single! as CameraCaptured).path, endsWith('p2.jpg'));
      expect(find.byKey(const Key('nexa_camera_screen')), findsNothing);
      expect(session.closed, isTrue);
    });

    testWidgets('cancel before capture shares nothing', (tester) async {
      final session = FakeCameraSession(tmp);
      final outcomes = await open(tester, session);
      await tester.tap(find.byKey(const Key('nexa_camera_cancel')));
      await tester.pumpAndSettle();
      expect(outcomes.single, isA<CameraCaptureCancelled>());
      expect(session.pictures, 0);
    });

    testWidgets('denied camera shows Open settings and reports it', (
      tester,
    ) async {
      final session = FakeCameraSession(
        tmp,
        openError: ClientToolErrorCode.permissionBlocked,
      );
      final outcomes = await open(tester, session);
      expect(find.byKey(const Key('nexa_camera_error')), findsOneWidget);
      expect(find.byKey(const Key('nexa_camera_settings')), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_camera_cancel')));
      await tester.pumpAndSettle();
      expect(
        (outcomes.single! as CameraCaptureFailed).code,
        ClientToolErrorCode.permissionBlocked,
      );
    });
  });
}

final class FakeCameraSession implements NexaCameraSession {
  FakeCameraSession(this.dir, {this.openError});

  final Directory dir;
  final ClientToolErrorCode? openError;
  int pictures = 0;
  bool closed = false;

  @override
  Future<void> open() async {
    if (openError != null) throw CameraOpenException(openError!);
  }

  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(key: Key('fake_preview'), color: Colors.grey);

  @override
  Future<String> takePicture() async {
    pictures++;
    final f = File('${dir.path}/p$pictures.jpg')..writeAsBytesSync([1, 2, 3]);
    return f.path;
  }

  @override
  Future<void> close() async => closed = true;
}
