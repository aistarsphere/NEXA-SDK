import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

import '../helpers.dart';

final class _Location implements LocationPlatform {
  _Location({this.after = LocationPermissionState.granted});
  final LocationPermissionState after;
  LocationPermissionState state = LocationPermissionState.notDetermined;

  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermissionState> permission() async => state;
  @override
  Future<LocationPermissionState> requestPermission() async => state = after;
  @override
  Future<LocationFix> currentFix({
    required bool highAccuracy,
    required Duration timeout,
  }) async => LocationFix(
    latitude: 33.31520,
    longitude: 44.36610,
    accuracyMeters: 9,
    timestamp: DateTime.utc(2026, 10, 28),
  );
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

final class _Opener implements UrlOpener {
  final opened = <Uri>[];
  @override
  Future<bool> openInApp(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<bool> openInBrowser(Uri uri) async => false;

  @override
  Future<bool> canOpen(Uri uri) async => false;
}

final class _Camera implements NexaCameraSession {
  _Camera(this.dir);
  final Directory dir;
  @override
  Future<void> open() async {}
  @override
  Widget buildPreview(BuildContext context) =>
      const ColoredBox(color: Colors.grey);

  /// A valid 1×1 PNG.
  static final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
  );

  @override
  Future<String> takePicture() async =>
      (File('${dir.path}/shot.png')..writeAsBytesSync(png)).path;
  @override
  Future<void> close() async {}
}

void main() {
  late Directory tmp;
  late _Location location;
  late _Opener opener;
  late NexaClient client;
  late InMemoryHistoryStore historyStore;

  Future<void> init(WidgetTester tester, {_Location? loc}) async {
    tmp = Directory.systemTemp.createTempSync('nexa_mm');
    location = loc ?? _Location();
    opener = _Opener();
    historyStore = InMemoryHistoryStore();
    client = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_test',
        gatewayBaseUri: Uri.parse('http://localhost:1'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
      ),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: fastMock(),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: const _AllowAll(),
      ),
      clientTools: NexaClientToolOptions(
        locationPlatform: location,
        urlOpener: opener,
        cameraSessionFactory: () => _Camera(tmp),
        mediaStore: NexaMediaStore(root: Directory('${tmp.path}/media')),
        onOpenSettings: () {},
      ),
      history: NexaHistoryOptions(cache: historyStore),
    );
    addTearDown(() async {
      await client.dispose();
      tmp.deleteSync(recursive: true);
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  /// Lets real file I/O started by the UI progress step by step.
  Future<void> io(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The live voice page animates continuously (capsule): no settling.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget app() => MaterialApp(
    home: client.assistantView(brand: const NexaBrand(name: 'LABEEB')),
  );

  Future<void> allow(WidgetTester tester, {bool settle = true}) async {
    // Inline approval in the tool card (no dialog).
    expect(find.byKey(const Key('nexa_tool_state_approval')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_tool_allow')));
    await (settle ? tester.pumpAndSettle() : frames(tester));
  }

  testWidgets('host voice requests open live voice once', (tester) async {
    await init(tester);
    final requests = StreamController<void>.broadcast();
    addTearDown(requests.close);
    await tester.pumpWidget(
      MaterialApp(
        home: client.assistantView(
          brand: const NexaBrand(name: 'LABEEB'),
          voiceRequests: requests.stream,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live_voice_view')), findsNothing);

    requests
      ..add(null)
      ..add(null); // a repeated wake must not stack a second call
    await frames(tester);
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);

    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    expect(find.byKey(const Key('live_voice_view')), findsNothing);

    requests.add(null);
    await frames(tester);
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);
  });

  testWidgets('share location from chat: approval → structured card', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_composer_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_attach_location')));
    await tester.pumpAndSettle();
    await allow(tester);
    expect(find.text('33.31520, 44.36610'), findsOneWidget);
    expect(find.byKey(const Key('nexa_tool_not_delivered')), findsOneWidget);
    final run = client.media.items.whereType<NexaToolRunItem>().single;
    expect(run.result!.output!['accuracy_m'], 9);
    expect(run.delivered, isFalse);
  });

  testWidgets('denied location shows a structured error with retry', (
    tester,
  ) async {
    await init(tester, loc: _Location(after: LocationPermissionState.denied));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_composer_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_attach_location')));
    await tester.pumpAndSettle();
    await allow(tester);
    expect(find.byKey(const Key('nexa_tool_state_denied')), findsOneWidget);
    expect(find.byKey(const Key('nexa_tool_retry')), findsOneWidget);
  });

  testWidgets('declining the approval runs nothing', (tester) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_composer_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_attach_location')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_tool_decline')));
    await tester.pumpAndSettle();
    expect(location.state, LocationPermissionState.notDetermined);
    expect(find.text('Cancelled. Nothing was shared.'), findsOneWidget);
  });

  testWidgets('places card keeps ordinals; directions use the place id', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    final shown = client.deviceActions.showPlaces({
      'contract': placesContractV1,
      'result_id': 'r1',
      'status': 'ok',
      'query': 'Restaurants nearby',
      'attribution': 'Provider',
      'places': [
        {
          'place_id': 'ChIJ_first_000001',
          'name': 'First Grill',
          'category': 'Restaurant',
          'rating': 4.5,
          'user_rating_count': 10,
          'distance_m': 350,
          'location': {'lat': 33.1, 'lng': 44.1},
        },
        {
          'place_id': 'ChIJ_second_00002',
          'name': 'Second Kitchen',
          'distance_m': 1250,
          'location': {'lat': 33.2, 'lng': 44.2},
        },
      ],
    });
    expect(shown, isTrue);
    await tester.pumpAndSettle();
    expect(find.text('First Grill'), findsOneWidget);
    expect(find.text('Restaurant · 350 m away'), findsOneWidget);
    expect(find.text('1.3 km away'), findsOneWidget);
    expect(client.media.placeAt(2)!.placeId, 'ChIJ_second_00002');
    expect(
      (client.media.placesContext!['places']! as List).last,
      containsPair('ordinal', 2),
    );
    await tester.tap(find.byKey(const Key('nexa_place_directions_2')));
    await tester.pumpAndSettle();
    final url = opener.opened.single;
    expect(url.queryParameters['api'], '1');
    expect(url.queryParameters['destination_place_id'], 'ChIJ_second_00002');
    expect(url.queryParameters['destination'], '33.200000,44.200000');
    // Malformed results are not shown.
    expect(client.deviceActions.showPlaces({'contract': 'x'}), isFalse);
  });

  testWidgets('places loading / empty / denied states render', (tester) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    Map<String, Object?> r(String id, String status) => {
      'contract': placesContractV1,
      'result_id': id,
      'status': status,
    };
    client.deviceActions.showPlaces(r('a', 'loading'));
    await tester.pump();
    expect(find.byKey(const Key('nexa_places_loading')), findsOneWidget);
    client.deviceActions.showPlaces(r('a', 'zero_results'));
    await tester.pump();
    expect(find.text('No places found nearby.'), findsOneWidget);
    expect(find.byKey(const Key('nexa_places_loading')), findsNothing);
    client.deviceActions.showPlaces(r('b', 'location_denied'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_places_retry')), findsOneWidget);
    expect(find.byKey(const Key('nexa_places_settings')), findsOneWidget);
  });

  testWidgets('camera from live voice keeps the call; photo shows in both', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('assistant_voice')));
    await frames(tester);
    expect(client.voice.state.value.phase, isNot(VoiceState.idle));
    final phaseBefore = client.voice.state.value.phase;

    await tester.tap(find.byKey(const Key('live_voice_show')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('nexa_attach_camera')));
    await frames(tester);
    await allow(tester, settle: false);
    expect(find.byKey(const Key('nexa_camera_screen')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nexa_camera_shutter')));
    await frames(tester);
    await tester.tap(find.byKey(const Key('nexa_camera_use')));
    await io(tester); // importing the photo is real file I/O
    await frames(tester);

    // Back on the voice page, the call is still running.
    expect(find.byKey(const Key('live_voice_view')), findsOneWidget);
    expect(client.voice.state.value.phase, phaseBefore);
    expect(find.byKey(const Key('nexa_media_tray')), findsOneWidget);
    final item = client.media.attachments.single;
    expect(item.surface, NexaItemSurface.voice);
    expect(item.attachment.origin, NexaAttachmentOrigin.captured);
    expect(item.attachment.status, NexaAttachmentStatus.uploadUnavailable);
    expect(item.attachment.toJson().containsKey('local_path'), isFalse);

    // Closing voice ends the call; the chat shows the same photo.
    await tester.tap(find.byKey(const Key('live_voice_close')));
    await frames(tester);
    expect(
      find.byKey(Key('nexa_attachment_${item.attachment.id}')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nexa_attachment_status')), findsOneWidget);
  });

  testWidgets('history: cache-backed list, honest deletion flow', (
    tester,
  ) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('nexa_composer_field')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const Key('nexa_composer_send')));
    await tester.pumpAndSettle();
    final history = client.history!;
    expect(history.cachedEntries.single.displayTitle, 'hi');

    await tester.tap(find.byKey(const Key('assistant_history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_history_local_note')), findsOneWidget);
    await tester.tap(find.text('hi'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('nexa_history_resume')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('nexa_history_rename')))
          .onPressed,
      isNull,
    ); // the server has no rename API
    await tester.tap(find.byKey(const Key('nexa_history_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_deletion_confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nexa_deletion_local')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('nexa_deletion_server'))).data,
      "Server deletion isn't available yet, so nothing was deleted on the "
      'server.',
    );
    await tester.tap(find.byKey(const Key('nexa_deletion_done')));
    await tester.pumpAndSettle();
    expect(history.cachedEntries, isEmpty);
    expect(await historyStore.load(), isEmpty);
  });

  testWidgets('files, AI badge and place selection context', (tester) async {
    await init(tester);
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(NexaMediaStore.checkFile('bill.pdf', 1024), isNull);
    expect(NexaMediaStore.checkFile('run.exe', 10), 'unsupported_type');
    expect(NexaMediaStore.checkFile('big.pdf', 11 * 1024 * 1024), 'too_large');
    client.media
      ..add(
        NexaAttachmentItem(
          id: 'f1',
          createdAt: DateTime.now().toUtc(),
          attachment: NexaAttachment(
            id: 'att_f',
            kind: NexaAttachmentKind.file,
            origin: NexaAttachmentOrigin.uploaded,
            mimeType: 'application/pdf',
            createdAt: DateTime.now().toUtc(),
            name: 'contract-draft.pdf',
            byteLength: 2516582,
            status: NexaAttachmentStatus.uploadUnavailable,
          ),
        ),
      )
      ..add(
        NexaAttachmentItem(
          id: 'g1',
          createdAt: DateTime.now().toUtc(),
          fromUser: false,
          attachment: NexaAttachment(
            id: 'att_g',
            kind: NexaAttachmentKind.image,
            origin: NexaAttachmentOrigin.generated,
            mimeType: 'image/png',
            createdAt: DateTime.now().toUtc(),
          ),
        ),
      );
    await tester.pumpAndSettle();
    expect(find.text('contract-draft.pdf'), findsOneWidget);
    expect(find.text('2.4 MB'), findsOneWidget);
    expect(find.byKey(const Key('nexa_ai_badge')), findsOneWidget);
    expect(find.text('AI-generated'), findsOneWidget);

    client.deviceActions.showPlaces({
      'contract': placesContractV1,
      'result_id': 'r9',
      'status': 'ok',
      'places': [
        {
          'place_id': 'ChIJ_first_000001',
          'name': 'First',
          'location': {'lat': 1, 'lng': 1},
        },
        {
          'place_id': 'ChIJ_second_00002',
          'name': 'Second',
          'location': {'lat': 2, 'lng': 2},
        },
      ],
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_place_ChIJ_second_00002')));
    await tester.pumpAndSettle();
    expect(
      client.media.placesContext!['selected_place_id'],
      'ChIJ_second_00002',
    );
  });

  testWidgets('Arabic RTL tool card inherits the host theme', (tester) async {
    await init(tester);
    final hostTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: hostTheme,
        home: client.assistantView(brand: const NexaBrand(name: 'LABEEB')),
      ),
    );
    client.setLanguage('ar');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_composer_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nexa_attach_location')));
    await tester.pumpAndSettle();
    final allow = find.text('سماح لمرة واحدة');
    expect(allow, findsOneWidget);
    final ctx = tester.element(allow);
    expect(Directionality.of(ctx), TextDirection.rtl);
    expect(Theme.of(ctx).colorScheme.primary, hostTheme.colorScheme.primary);
  });
}

final class _AllowAll implements NexaPermissionHandler {
  const _AllowAll();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}
