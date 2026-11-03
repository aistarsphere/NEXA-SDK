import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// A recorded request.
typedef _Req = ({String method, String path, Object? body});

/// Routes Dio requests to in-memory handlers (contract shapes only).
final class _FakeGateway implements HttpClientAdapter {
  final List<_Req> requests = [];
  final Map<String, (int, Object?) Function(_Req)> routes = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Object? body = options.data;
    if (requestStream != null) {
      final bytes = await requestStream.expand((c) => c).toList();
      body = Uint8List.fromList(bytes);
      try {
        body = jsonDecode(utf8.decode(bytes));
      } on Object {
        // raw upload bytes
      }
    }
    final req = (method: options.method, path: options.path, body: body);
    requests.add(req);
    final handler = routes['${options.method} ${options.path}'];
    final (status, json) = handler == null
        ? (
            404,
            {
              'error': {'code': 'not_found', 'retryable': false},
            },
          )
        : handler(req);
    return ResponseBody.fromString(
      jsonEncode(json),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _call(
  String id,
  String tool,
  String status, {
  String side = 'client',
  Map<String, Object?> arguments = const {},
  bool asynchronous = false,
  Map<String, Object?>? result,
  Map<String, Object?>? error,
}) => {
  'tool_call_id': id,
  'tool': tool,
  'side': side,
  'arguments': arguments,
  'status': status,
  'approval_required': side == 'client',
  'deadline_at': '2030-01-01T00:00:00Z',
  'result': result,
  'error': error,
  'asynchronous': asynchronous,
};

ConversationEvent _event(String type, Map<String, Object?> fields, int seq) =>
    ConversationEvent.tryParse({
      'type': type,
      'event_id': 'evt_$seq',
      'session_id': 'ses_1',
      'sequence': seq,
      'occurred_at': '2026-10-28T10:00:00.000Z',
      ...fields,
    })!;

final class _FakeLocation implements LocationPlatform {
  @override
  Future<bool> serviceEnabled() async => true;
  @override
  Future<LocationPermissionState> permission() async =>
      LocationPermissionState.granted;
  @override
  Future<LocationPermissionState> requestPermission() async =>
      LocationPermissionState.granted;
  @override
  Future<LocationFix> currentFix({
    required bool highAccuracy,
    required Duration timeout,
  }) async => LocationFix(
    latitude: 33.3,
    longitude: 44.4,
    accuracyMeters: 12,
    timestamp: DateTime.utc(2026, 10, 28, 10),
  );
  @override
  Future<bool> openAppSettings() async => true;
  @override
  Future<bool> openLocationSettings() async => true;
}

final class _FakeOpener implements UrlOpener {
  final List<Uri> opened = [];
  @override
  Future<bool> canOpen(Uri uri) async => true;
  @override
  Future<bool> openInApp(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<bool> openInBrowser(Uri uri) async {
    opened.add(uri);
    return true;
  }
}

final class _FakeTheme extends ChangeNotifier
    implements NexaHostThemeController {
  NexaThemeSpec? previewed;
  NexaThemeSpec? applied;
  bool cancelled = false;
  @override
  List<NexaThemeOption> get palettes => const [];
  @override
  String get appliedPaletteId => applied?.paletteId ?? 'original';
  @override
  NexaAppearance get appliedAppearance =>
      applied?.appearance ?? NexaAppearance.system;
  @override
  Future<bool> preview(String p, NexaAppearance a) async => true;
  @override
  Future<bool> cancelPreview() async {
    cancelled = true;
    previewed = null;
    return true;
  }

  @override
  Future<bool> apply(String p, NexaAppearance a) async => true;
  @override
  Future<bool> reset() async {
    applied = null;
    return true;
  }

  @override
  Future<bool> previewSpec(NexaThemeSpec spec) async {
    previewed = spec;
    return true;
  }

  @override
  Future<bool> applySpec(NexaThemeSpec spec) async {
    applied = spec;
    return true;
  }
}

void main() {
  late _FakeGateway gw;
  late LabeebToolCallController c;
  late NexaConversationMedia media;
  late _FakeOpener opener;
  late _FakeTheme theme;
  BuildContext? ctx;

  setUp(() {
    gw = _FakeGateway();
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test/nexa/api'))
      ..httpClientAdapter = gw;
    media = NexaConversationMedia();
    opener = _FakeOpener();
    theme = _FakeTheme();
    c =
        LabeebToolCallController(
            api: LabeebSdkClient(dio),
            media: media,
            host: NexaHostCapabilities(theme: theme),
            tools: [
              LabeebLocationTool(_FakeLocation()),
              LabeebOpenUrlTool(opener),
              LabeebDirectionsTool(opener),
              const LabeebThemeApplyTool(),
            ],
          )
          ..chatSession = (() => 'ses_1')
          ..conversation = (() => 'conv_1')
          ..presenter = (() => ctx);
  });

  LabeebToolCallController restarted(LabeebPendingStore store) {
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test/nexa/api'))
      ..httpClientAdapter = gw;
    return LabeebToolCallController(
        api: LabeebSdkClient(dio),
        media: NexaConversationMedia(),
        tools: [LabeebLocationTool(_FakeLocation())],
      )
      ..chatSession = (() => 'ses_chat')
      ..conversation = (() => 'conv_1')
      ..pendingStore = store;
  }

  /// Lets in-memory HTTP round trips started in the fake zone finish.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 5));
    }
  }

  Future<void> host(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: NexaLocale.supported,
        localizationsDelegates: NexaLocale.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return SingleChildScrollView(child: child);
            },
          ),
        ),
      ),
    );
  }

  test('declares only the device tools it implements', () async {
    expect(await c.declaredTools(), [
      'device.location.get_current',
      'maps.open_directions',
      'browser.open_url',
      'app.theme.apply',
    ]);
  });

  test('declares at most 8 tools (production limit), by priority', () async {
    final all = LabeebToolCallController(
      api: c.api,
      media: media,
      tools: labeebDeviceTools(const NexaClientToolOptions(), theme: theme),
    );
    final declared = await all.declaredTools();
    expect(declared, hasLength(8));
    expect(declared.first, 'device.location.get_current');
    expect(
      declared,
      containsAll(['app.theme.apply', 'device.microphone.record_sample']),
    );
    expect(declared, isNot(contains('device.network.get_status')));
  });

  test('the host chooses the declaration order', () async {
    final all = LabeebToolCallController(
      api: c.api,
      media: media,
      tools: labeebDeviceTools(const NexaClientToolOptions(), theme: theme),
      priority: const [
        'device.network.get_status',
        'device.microphone.record_sample',
      ],
    );
    final declared = await all.declaredTools();
    expect(declared.take(2), [
      'device.network.get_status',
      'device.microphone.record_sample',
    ]);
    expect(declared, hasLength(8));
  });

  test('with a readable catalogue only usable tools are declared', () async {
    gw.routes['GET /v1/sdk/tools'] = (r) => (
      200,
      {
        'enabled': true,
        'tools': [
          {'name': 'device.location.get_current', 'available': true},
          {
            'name': 'device.camera.capture',
            'available': false,
            'unavailable_reason': 'not_enabled_for_application',
          },
          {
            'name': 'device.microphone.record_sample',
            'available': false,
            'unavailable_reason': 'client_does_not_support',
          },
        ],
      },
    );
    final all = LabeebToolCallController(
      api: c.api,
      media: media,
      tools: labeebDeviceTools(const NexaClientToolOptions(), theme: theme),
    );
    await all.refreshCatalogue();
    expect(await all.declaredTools(), [
      'device.location.get_current',
      'device.microphone.record_sample',
    ]);
  });

  testWidgets('approval → awaiting_client → location result, answered once', (
    tester,
  ) async {
    const path = '/v1/sdk/sessions/ses_1/tool-calls/tc_1';
    gw.routes['POST $path/approval'] = (r) =>
        (200, _call('tc_1', 'device.location.get_current', 'awaiting_client'));
    gw.routes['POST $path/result'] = (r) => (
      200,
      _call(
        'tc_1',
        'device.location.get_current',
        'succeeded',
        result: (r.body! as Map)['result'] as Map<String, Object?>,
      ),
    );
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_1', controller: c));
    c.ingest(
      _event(
        'tool_call_requested',
        _call('tc_1', 'device.location.get_current', 'awaiting_approval'),
        5,
      ),
    );
    await tester.pump();
    expect(media.items.whereType<NexaToolCallItem>(), hasLength(1));
    expect(find.text('Waiting for your approval'), findsOneWidget);
    expect(gw.requests, isEmpty, reason: 'nothing runs before consent');

    await tester.tap(find.byKey(const Key('labeeb_tc_allow_tc_1')));
    await settle(tester);
    await tester.pump();
    expect(gw.requests.map((r) => '${r.method} ${r.path}'), [
      'POST $path/approval',
      'POST $path/result',
    ]);
    expect(gw.requests.first.body, {'granted': true});
    expect(gw.requests.last.body, {
      'result': {
        'latitude': 33.3,
        'longitude': 44.4,
        'accuracy_m': 12.0,
        'timestamp': '2026-10-28T10:00:00.000Z',
      },
    });
    expect(c.activity('tc_1')!.call.status, NexaToolCallStatus.succeeded);
    expect(find.text('Done'), findsOneWidget);

    // A replayed awaiting_client event never answers twice.
    c.ingest(
      _event(
        'tool_call_updated',
        _call('tc_1', 'device.location.get_current', 'awaiting_client'),
        6,
      ),
    );
    await tester.pump();
    expect(gw.requests, hasLength(2));
  });

  testWidgets('Not now sends granted:false; nothing runs', (tester) async {
    const path = '/v1/sdk/sessions/ses_1/tool-calls/tc_2';
    gw.routes['POST $path/approval'] = (r) =>
        (200, _call('tc_2', 'device.location.get_current', 'denied'));
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_2', controller: c));
    c.ingest(
      _event(
        'tool_call_requested',
        _call('tc_2', 'device.location.get_current', 'awaiting_approval'),
        1,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('labeeb_tc_deny_tc_2')));
    await settle(tester);
    await tester.pump();
    expect(gw.requests.single.body, {'granted': false});
    expect(find.text('You said no'), findsOneWidget);
  });

  testWidgets('a closed call (409 tool_call_closed) is shown, not retried', (
    tester,
  ) async {
    const path = '/v1/sdk/sessions/ses_1/tool-calls/tc_3';
    gw.routes['POST $path/approval'] = (r) => (
      409,
      {
        'error': {'code': 'tool_call_closed', 'retryable': false},
      },
    );
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_3', controller: c));
    c.ingest(
      _event(
        'tool_call_requested',
        _call('tc_3', 'device.location.get_current', 'awaiting_approval'),
        1,
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('labeeb_tc_allow_tc_3')));
    await settle(tester);
    await tester.pump();
    expect(c.activity('tc_3')!.phase, LabeebLocalPhase.failed);
    expect(c.activity('tc_3')!.localError, 'tool_call_closed');
    expect(find.text('This request is no longer open.'), findsOneWidget);
    expect(find.byKey(const Key('labeeb_tc_allow_tc_3')), findsNothing);
  });

  test('an undeclared client tool is refused, never run', () async {
    gw.routes['POST /v1/sdk/sessions/ses_1/tool-calls/tc_4/approval'] = (r) =>
        (200, _call('tc_4', 'device.contacts.read', 'denied'));
    c.ingest(
      _event(
        'tool_call_requested',
        _call('tc_4', 'device.contacts.read', 'awaiting_approval'),
        1,
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(gw.requests.single.body, {'granted': false});
  });

  testWidgets('browser.open_url opens only the validated https url', (
    tester,
  ) async {
    const path = '/v1/sdk/sessions/ses_1/tool-calls/tc_5';
    gw.routes['POST $path/result'] = (r) =>
        (200, _call('tc_5', 'browser.open_url', 'succeeded'));
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_5', controller: c));
    c.ingest(
      _event(
        'tool_call_updated',
        _call(
          'tc_5',
          'browser.open_url',
          'awaiting_client',
          arguments: {'result_id': 'r_2', 'url': 'http://insecure.test/x'},
        ),
        1,
      ),
    );
    await settle(tester);
    expect(opener.opened, isEmpty);
    expect(gw.requests.single.body, {
      'error': {
        'code': 'invalid_arguments',
        'message': 'no validated url',
        'retryable': false,
      },
    });
  });

  testWidgets('maps.open_directions uses the gateway-resolved place', (
    tester,
  ) async {
    const path = '/v1/sdk/sessions/ses_1/tool-calls/tc_6';
    gw.routes['POST $path/result'] = (r) =>
        (200, _call('tc_6', 'maps.open_directions', 'succeeded'));
    await host(tester, const SizedBox());
    c.ingest(
      _event(
        'tool_call_updated',
        _call(
          'tc_6',
          'maps.open_directions',
          'awaiting_client',
          arguments: {
            'destination': {
              'place_id': 'pl_2',
              'latitude': 33.31,
              'longitude': 44.37,
              'name': 'Second Café',
            },
            'mode': 'walking',
          },
        ),
        1,
      ),
    );
    await settle(tester);
    expect(opener.opened.single.toString(), contains('destination'));
    expect(gw.requests.single.body, {
      'result': {'opened': true},
    });
  });

  testWidgets('theme: approval previews; Apply applies and reports', (
    tester,
  ) async {
    const path = '/v1/sdk/sessions/ses_1/tool-calls/tc_7';
    final args = {
      'palette_id': 'blue',
      'mode': 'dark',
      'colors': {'primary': '#1565C0', 'on_primary': '#FFFFFF'},
    };
    gw.routes['POST $path/approval'] = (r) => (
      200,
      _call('tc_7', 'app.theme.apply', 'awaiting_client', arguments: args),
    );
    gw.routes['POST $path/result'] = (r) =>
        (200, _call('tc_7', 'app.theme.apply', 'succeeded', arguments: args));
    gw.routes['GET /v1/sdk/me/preferences'] = (r) => (
      200,
      {
        'preferences': {'lang': 'ar'},
      },
    );
    gw.routes['PUT /v1/sdk/me/preferences'] = (r) =>
        (200, r.body! as Map<String, Object?>);
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_7', controller: c));
    c.ingest(
      _event(
        'tool_call_requested',
        _call('tc_7', 'app.theme.apply', 'awaiting_approval', arguments: args),
        1,
      ),
    );
    await tester.pump();
    expect(theme.previewed?.paletteId, 'blue');
    expect(theme.previewed?.colors['primary'], const Color(0xFF1565C0));
    expect(theme.applied, isNull, reason: 'preview is not apply');
    expect(find.text('Apply'), findsOneWidget);

    await tester.tap(find.byKey(const Key('labeeb_tc_allow_tc_7')));
    await settle(tester);
    expect(theme.applied?.paletteId, 'blue');
    expect(theme.applied?.appearance, NexaAppearance.dark);
    final result = gw.requests.firstWhere((r) => r.path.endsWith('/result'));
    expect(result.body, {
      'result': {'status': 'applied', 'palette_id': 'blue', 'mode': 'dark'},
    });
    final put = gw.requests.firstWhere((r) => r.method == 'PUT');
    expect(put.body, {
      'preferences': {
        'lang': 'ar',
        'theme.palette_id': 'blue',
        'theme.mode': 'dark',
      },
    });
  });

  test('theme denied: the preview is dropped', () async {
    gw.routes['POST /v1/sdk/sessions/ses_1/tool-calls/tc_8/approval'] = (r) =>
        (200, _call('tc_8', 'app.theme.apply', 'denied'));
    c.ingest(
      _event(
        'tool_call_requested',
        _call(
          'tc_8',
          'app.theme.apply',
          'awaiting_approval',
          arguments: {
            'palette_id': 'red',
            'colors': {'primary': '#C62828'},
          },
        ),
        1,
      ),
    );
    expect(theme.previewed?.paletteId, 'red');
    await c.decide('tc_8', allow: false);
    expect(theme.cancelled, isTrue);
    expect(theme.applied, isNull);
  });

  testWidgets('long job: running → progress → asset → completed; Stop', (
    tester,
  ) async {
    gw.routes['POST /v1/sdk/sessions/ses_1/tool-calls/tc_9/cancel'] = (r) =>
        (200, _call('tc_9', 'image.generate', 'cancelled', side: 'server'));
    gw.routes['GET /v1/sdk/assets/ast_1/content'] = (r) => (200, <int>[]);
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_9', controller: c));
    c.ingest(
      _event(
        'tool_call_requested',
        _call(
          'tc_9',
          'image.generate',
          'running',
          side: 'server',
          asynchronous: true,
        ),
        1,
      ),
    );
    await tester.pump();
    expect(find.text('Started. You can keep chatting.'), findsOneWidget);
    expect(c.runningJobs, hasLength(1));
    c.ingest(
      _event('tool_call_progress', {
        'tool_call_id': 'tc_9',
        'tool': 'image.generate',
        'state': 'running',
        'waited_s': 14,
      }, 2),
    );
    await tester.pump();
    expect(find.text('Waiting 14s'), findsOneWidget);
    expect(find.text('Done'), findsNothing, reason: 'never done before end');

    await tester.tap(find.byKey(const Key('labeeb_tc_cancel_tc_9')));
    await settle(tester);
    expect(gw.requests.last.path, endsWith('/tool-calls/tc_9/cancel'));

    c
      ..ingest(
        _event('asset_created', {
          'tool_call_id': 'tc_9',
          'message_id': 'msg_1',
          'asset': {
            'id': 'ast_1',
            'kind': 'image',
            'mime': 'image/png',
            'size_bytes': 0,
            'origin': 'generated',
          },
        }, 3),
      )
      ..ingest(
        _event(
          'tool_call_completed',
          _call(
            'tc_9',
            'image.generate',
            'succeeded',
            side: 'server',
            asynchronous: true,
            result: {'asset_id': 'ast_1'},
          ),
          4,
        ),
      );
    await tester.pump();
    expect(c.runningJobs, isEmpty);
    expect(c.activity('tc_9')!.assets.single.generated, isTrue);
    expect(find.text('Done'), findsOneWidget);
    await settle(tester); // the asset bytes request
  });

  testWidgets('provider blocked is said plainly', (tester) async {
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_10', controller: c));
    c.ingest(
      _event(
        'tool_call_failed',
        _call(
          'tc_10',
          'news.search',
          'failed',
          side: 'server',
          error: {'code': 'provider_rate_limited', 'retryable': true},
        ),
        1,
      ),
    );
    await tester.pump();
    expect(find.text('The source is busy. Try again later.'), findsOneWidget);
  });

  testWidgets('web results in encyclopedia mode are labelled', (tester) async {
    await host(tester, LabeebToolCallCard(toolCallId: 'tc_11', controller: c));
    c.ingest(
      _event(
        'tool_call_completed',
        _call(
          'tc_11',
          'web.search',
          'succeeded',
          side: 'server',
          result: {
            'coverage': 'encyclopedia_only',
            'results': [
              {
                'title': 'Baghdad',
                'url': 'https://en.wikipedia.org/wiki/Baghdad',
                'source': 'Wikipedia',
              },
            ],
          },
        ),
        1,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('labeeb_results_encyclopedia')),
      findsOneWidget,
    );
    expect(find.text('Baghdad'), findsOneWidget);
    expect(find.text('Wikipedia'), findsOneWidget);
  });

  testWidgets('nexa.ui/1: select sends ui_event with stable option ids', (
    tester,
  ) async {
    final events = <NexaUiEvent>[];
    c.uiEventSink = (e) async {
      events.add(e);
      return null;
    };
    c.ingest(
      _event('ui_presented', {
        'tool_call_id': 'tc_12',
        'ui': {
          'schema': 'nexa.ui/1',
          'id': 'ui_places_1',
          'category': 'places_maps',
          'presentation': 'inline_card',
          'title': {'en': 'Nearby cafés', 'ar': 'مقاهٍ قريبة'},
          'root': {
            'id': 'list',
            'type': 'choice',
            'options': [
              {'id': 'pl_1', 'label': 'First Café', 'ordinal': 1},
              {'id': 'pl_2', 'label': 'Second Café', 'ordinal': 2},
            ],
            'on_select': {'type': 'send_ui_event', 'event': 'select'},
          },
        },
      }, 1),
    );
    expect(media.items.whereType<NexaUiDocumentItem>(), hasLength(1));
    await host(tester, NexaUiDocumentCard(uiId: 'ui_places_1', controller: c));
    expect(find.text('Nearby cafés'), findsOneWidget);
    await tester.tap(find.text('Second Café'));
    await tester.pump();
    expect(events.single.toJson(), {
      'ui_id': 'ui_places_1',
      'component_id': 'list',
      'event': 'select',
      'option_ids': ['pl_2'],
    });
  });

  testWidgets('nexa.ui/1: a host renderer draws an extension type', (
    tester,
  ) async {
    final events = <NexaUiEvent>[];
    Map<String, Object?> doc(String id) => {
      'schema': 'nexa.ui/1',
      'id': id,
      'category': 'tasks_progress',
      'presentation': 'inline_card',
      'root': {
        'id': 'col',
        'type': 'column',
        'children': [
          {'id': 'title', 'type': 'text', 'text': 'Sprint 12'},
          {
            'id': 'board',
            'type': 'acme_kanban',
            'columns': ['To do', 'Done'],
            'action': {'type': 'send_ui_event', 'event': 'select'},
          },
        ],
      },
    };
    // Without a renderer the unknown type is skipped, never fatal.
    c.onUi(doc('ui_plain'));
    expect(c.document('ui_plain')!.node('board'), isNull);

    final hosted =
        LabeebToolCallController(
            api: c.api,
            media: media,
            tools: const [],
            host: NexaHostCapabilities(
              uiComponents: {
                'acme_kanban': (context, k) => TextButton(
                  key: const Key('acme_board'),
                  onPressed: () => k.send(optionIds: ['col_done']),
                  child: Text((k.node.props['columns']! as List).join(' | ')),
                ),
              },
            ),
          )
          ..uiEventSink = (e) async {
            events.add(e);
            return null;
          }
          ..onUi(doc('ui_ext'));
    await host(tester, NexaUiDocumentCard(uiId: 'ui_ext', controller: hosted));
    expect(find.text('Sprint 12'), findsOneWidget);
    expect(find.text('To do | Done'), findsOneWidget);
    await tester.tap(find.byKey(const Key('acme_board')));
    await tester.pump();
    expect(events.single.toJson(), {
      'ui_id': 'ui_ext',
      'component_id': 'board',
      'event': 'select',
      'option_ids': ['col_done'],
    });
  });

  testWidgets('nexa.ui/1: a stale document is reported, not hidden', (
    tester,
  ) async {
    c
      ..uiEventSink = ((e) async => 'unknown_ui_component')
      ..onUi({
        'schema': 'nexa.ui/1',
        'id': 'ui_old',
        'category': 'choices_forms',
        'presentation': 'inline_card',
        'root': {
          'id': 'ok',
          'type': 'confirm',
          'text': 'Continue?',
          'on_confirm': {'type': 'send_ui_event', 'event': 'confirm'},
        },
      });
    await host(tester, NexaUiDocumentCard(uiId: 'ui_old', controller: c));
    await tester.tap(find.byKey(const Key('nexa_ui_confirm_ok')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('nexa_ui_refused')), findsOneWidget);
  });

  testWidgets('nexa.ui/1 renders in Arabic RTL with ordinals', (tester) async {
    c.onUi({
      'schema': 'nexa.ui/1',
      'id': 'ui_ar',
      'category': 'themes_appearance',
      'presentation': 'inline_card',
      'title': {'en': 'Theme', 'ar': 'المظهر'},
      'root': {
        'id': 'pal',
        'type': 'palette',
        'options': [
          {
            'id': 'red',
            'label': {'en': 'Red', 'ar': 'أحمر'},
            'ordinal': 1,
            'colors': {'primary': '#C62828'},
          },
        ],
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: NexaLocale.supported,
        localizationsDelegates: NexaLocale.delegates,
        home: Scaffold(
          body: NexaUiDocumentCard(uiId: 'ui_ar', controller: c),
        ),
      ),
    );
    expect(find.text('المظهر'), findsOneWidget);
    expect(find.text('أحمر'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('أحمر'))),
      TextDirection.rtl,
    );
  });

  group('history resume', () {
    LabeebMessage msg(
      String id,
      String role,
      List<Map<String, Object?>> parts, {
      int minute = 0,
    }) => LabeebMessage.fromJson({
      'id': id,
      'role': role,
      'text': '',
      'session_id': 'ses_old',
      'created_at': '2026-10-28T10:${'$minute'.padLeft(2, '0')}:00Z',
      'parts': parts,
    });

    test('restores attachments, deleted files, results and documents; '
        'never runs or asks again', () async {
      c.restore([
        msg('m1', 'user', [
          {'type': 'text', 'text': 'what is this'},
          {'type': 'image', 'asset_id': 'ast_u', 'mime': 'image/png'},
          {'type': 'deleted_asset'},
        ]),
        msg('m2', 'assistant', [
          {
            'type': 'tool_request',
            'tool_call_id': 'tc_loc',
            'name': 'device.location.get_current',
            'arguments': {'purpose': 'nearby'},
          },
          {
            'type': 'tool_result',
            'tool_call_id': 'tc_loc',
            'name': 'device.location.get_current',
            'status': 'succeeded',
            'result': {'latitude': 1},
          },
          {
            'type': 'tool_error',
            'tool_call_id': 'tc_news',
            'name': 'news.search',
            'error': {'code': 'provider_rate_limited'},
          },
          {
            'type': 'tool_result',
            'tool_call_id': 'tc_pal',
            'name': 'app.theme.list_palettes',
            'status': 'succeeded',
            'result': {
              'ui': {
                'schema': 'nexa.ui/1',
                'id': 'ui_pal',
                'category': 'themes_appearance',
                'root': {'id': 'r', 'type': 'text', 'text': 'x'},
              },
            },
          },
          {
            'type': 'image',
            'asset_id': 'ast_g',
            'mime': 'image/png',
            'generated': true,
          },
        ], minute: 1),
      ]);
      final assets = media.items.whereType<NexaAssetItem>().toList();
      expect(assets.map((a) => a.asset.id), ['ast_u', 'm1:2', 'ast_g']);
      expect(assets[1].asset.deleted, isTrue);
      expect(assets[2].asset.generated, isTrue);
      expect(assets.first.createdAt, DateTime.utc(2026, 10, 28, 10));
      final loc = c.activity('tc_loc')!;
      expect(loc.call.status, NexaToolCallStatus.succeeded);
      expect(loc.call.arguments['purpose'], 'nearby');
      expect(loc.phase, LabeebLocalPhase.idle);
      expect(c.activity('tc_news')!.call.error!.code, 'provider_rate_limited');
      expect(c.document('ui_pal'), isNotNull);
      // Nothing was sent to the gateway: history is display only.
      expect(gw.requests, isEmpty);
    });

    testWidgets('a job still running is followed until it ends', (
      tester,
    ) async {
      var reads = 0;
      gw.routes['GET /v1/sdk/sessions/ses_old/tool-calls/tc_job'] = (r) {
        reads++;
        return (
          200,
          _call(
            'tc_job',
            'image.generate',
            reads < 2 ? 'running' : 'succeeded',
            side: 'server',
            asynchronous: true,
          ),
        );
      };
      gw.routes['GET /v1/sdk/conversations/conv_1/messages'] = (r) => (
        200,
        {
          'items': [
            {
              'id': 'm9',
              'role': 'assistant',
              'text': 'done',
              'created_at': '2026-10-28T10:05:00Z',
              'parts': [
                {
                  'type': 'image',
                  'asset_id': 'ast_new',
                  'mime': 'image/png',
                  'generated': true,
                },
              ],
            },
          ],
        },
      );
      c.restore([
        msg('m1', 'assistant', [
          {
            'type': 'tool_result',
            'tool_call_id': 'tc_job',
            'name': 'image.generate',
            'status': 'running',
          },
        ]),
      ]);
      await settle(tester);
      expect(reads, 1);
      expect(c.activity('tc_job')!.call.status, NexaToolCallStatus.running);
      await tester.pump(const Duration(seconds: 6));
      await settle(tester);
      expect(reads, 2);
      expect(c.activity('tc_job')!.call.status, NexaToolCallStatus.succeeded);
      expect(
        media.items.whereType<NexaAssetItem>().map((a) => a.asset.id),
        contains('ast_new'),
      );
      c.reset();
    });

    testWidgets('a request without a result shows only its real status; '
        'no scope stops asking', (tester) async {
      var reads = 0;
      gw.routes['GET /v1/sdk/sessions/ses_old/tool-calls/tc_x'] = (r) {
        reads++;
        return (
          403,
          {
            'error': {'code': 'forbidden', 'retryable': false},
          },
        );
      };
      c.restore([
        msg('m1', 'assistant', [
          {
            'type': 'tool_request',
            'tool_call_id': 'tc_x',
            'name': 'ocr.extract',
            'arguments': <String, Object?>{},
          },
        ]),
      ]);
      await settle(tester);
      await tester.pump(const Duration(seconds: 40));
      await settle(tester);
      expect(reads, 1);
      // Unknown outcome: no card is invented.
      expect(c.activity('tc_x'), isNull);
    });
  });

  group('assets', () {
    testWidgets('delete confirms, calls the gateway and leaves a placeholder', (
      tester,
    ) async {
      gw.routes['DELETE /v1/sdk/assets/ast_f'] = (r) =>
          (200, {'deleted': true});
      c.onAsset(
        const NexaAssetRef(
          id: 'ast_f',
          mime: 'application/pdf',
          filename: 'a.pdf',
        ),
      );
      await host(
        tester,
        ListenableBuilder(
          listenable: media,
          builder: (context, _) => Column(
            children: [
              for (final a in media.items.whereType<NexaAssetItem>())
                LabeebAssetView(
                  key: ValueKey(a.asset.deleted),
                  asset: a.asset,
                  bytes: c.assetBytes,
                  onDelete: c.deleteAsset,
                ),
            ],
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('labeeb_asset_menu_ast_f')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('labeeb_asset_delete_ast_f')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this file?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('labeeb_asset_delete_confirm')));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(
        gw.requests.where((r) => r.method == 'DELETE').single.path,
        '/v1/sdk/assets/ast_f',
      );
      expect(find.text('File deleted'), findsOneWidget);
    });

    testWidgets('GPU and operator codes read as plain language', (
      tester,
    ) async {
      late NexaLocalizations l10n;
      await host(
        tester,
        Builder(
          builder: (context) {
            l10n = NexaLocalizations.of(context);
            return const SizedBox();
          },
        ),
      );
      expect(labeebErrorText(l10n, 'gpu_capacity'), l10n.tcGpuBusy);
      expect(labeebErrorText(l10n, 'gpu_not_permitted'), l10n.tcNotEnabled);
      expect(labeebErrorText(l10n, 'job_not_found'), l10n.tcJobNotFound);
      expect(labeebErrorText(l10n, 'deadline_exceeded'), l10n.tcTryAgain);
      expect(
        labeebErrorText(l10n, 'jira_not_connected'),
        l10n.tcJiraNotConnected,
      );
      expect(
        labeebErrorText(l10n, 'jira_reconnect_required'),
        l10n.tcJiraReconnect,
      );
      expect(labeebErrorText(l10n, 'jira_forbidden'), l10n.tcJiraForbidden);
      expect(labeebErrorText(l10n, 'jira_not_found'), l10n.tcJiraNotFound);
      expect(labeebErrorText(l10n, 'jira_bad_request'), l10n.tcCouldNotRun);
      expect(
        labeebErrorText(l10n, 'unsupported_media_type'),
        l10n.tcUnsupportedMedia,
      );
    });
  });

  group('result assets and completions', () {
    testWidgets('a server result naming an unseen asset is shown (audio)', (
      tester,
    ) async {
      gw.routes['GET /v1/sdk/assets/ast_p'] = (r) => (
        200,
        {
          'id': 'ast_p',
          'kind': 'file',
          'mime': 'audio/wav',
          'origin': 'generated',
        },
      );
      final call = _call(
        'tc_p',
        'voice.profile.preview',
        'succeeded',
        side: 'server',
        result: {'asset_id': 'ast_p'},
      );
      await host(tester, LabeebToolCallCard(toolCallId: 'tc_p', controller: c));
      c.ingest(_event('tool_call_completed', call, 9));
      // A repeated terminal event must not adopt or announce twice.
      c.ingest(_event('tool_call_completed', call, 10));
      await settle(tester);
      await tester.pump();
      final assets = c.activity('tc_p')!.assets;
      expect(assets.single.id, 'ast_p');
      expect(assets.single.isAudio, isTrue);
      expect(
        gw.requests.where((r) => r.path == '/v1/sdk/assets/ast_p'),
        hasLength(1),
      );
      expect(
        find.byKey(const Key('labeeb_audio_toggle_ast_p')),
        findsOneWidget,
      );
    });

    test('completed announces each server success once', () async {
      final done = <String>[];
      final sub = c.completed.listen((call) => done.add(call.tool));
      final ok = _call(
        'tc_v',
        'voice.profile.activate',
        'succeeded',
        side: 'server',
        result: const {},
      );
      c
        ..ingest(
          _event(
            'tool_call_updated',
            _call('tc_v', 'voice.profile.activate', 'running', side: 'server'),
            1,
          ),
        )
        ..ingest(_event('tool_call_completed', ok, 2))
        ..ingest(_event('tool_call_completed', ok, 3));
      await Future<void>.delayed(Duration.zero);
      expect(done, ['voice.profile.activate']);
      await sub.cancel();
    });

    testWidgets('audio plays from a private temp file, pause and resume', (
      tester,
    ) async {
      final player = _FakePlayback();
      await host(
        tester,
        LabeebAudioAssetTile(
          asset: const NexaAssetRef(
            id: 'ast_a',
            kind: 'file',
            mime: 'audio/wav',
          ),
          bytes: (_) async => Uint8List.fromList([1, 2, 3]),
          playback: () => player,
        ),
      );
      final toggle = find.byKey(const Key('labeeb_audio_toggle_ast_a'));
      await tester.runAsync(() async {
        await tester.tap(toggle);
        for (var i = 0; i < 20 && player.played.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pump();
      expect(player.played.single, endsWith('labeeb_audio_ast_a.wav'));
      await tester.tap(toggle);
      await tester.pump();
      expect(player.calls, ['play', 'pause']);
      await tester.tap(toggle);
      await tester.pump();
      expect(player.calls, ['play', 'pause', 'resume']);
    });
  });

  group('ui document states (D-03)', () {
    Map<String, Object?> confirmDoc(String id) => {
      'schema': 'nexa.ui/1',
      'id': id,
      'category': 'choices_forms',
      'presentation': 'inline_card',
      'root': {
        'id': 'ok',
        'type': 'confirm',
        'text': 'Continue?',
        'on_confirm': {'type': 'send_ui_event', 'event': 'confirm'},
      },
    };

    testWidgets('an unknown root shows the document\'s fallback text', (
      tester,
    ) async {
      c.onUi({
        'schema': 'nexa.ui/1',
        'id': 'ui_fb',
        'category': 'choices_forms',
        'presentation': 'inline_card',
        'fallback_text': 'Three cafés nearby: Alpha, Beta, Gamma.',
        'root': {'id': 'x', 'type': 'hologram'},
      });
      await host(tester, NexaUiDocumentCard(uiId: 'ui_fb', controller: c));
      expect(
        find.text('Three cafés nearby: Alpha, Beta, Gamma.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nexa_ui_loading')), findsNothing);
    });

    testWidgets('a per-language fallback follows the locale', (tester) async {
      c.onUi({
        'schema': 'nexa.ui/1',
        'id': 'ui_fb2',
        'category': 'choices_forms',
        'presentation': 'inline_card',
        'fallback_text': {'en': 'English words', 'ar': 'كلمات'},
        'root': {'id': 'x', 'type': 'hologram'},
      });
      await host(tester, NexaUiDocumentCard(uiId: 'ui_fb2', controller: c));
      expect(find.text('English words'), findsOneWidget);
    });

    testWidgets('an unknown root without fallback says it cannot be shown', (
      tester,
    ) async {
      c.onUi({
        'schema': 'nexa.ui/1',
        'id': 'ui_none',
        'category': 'choices_forms',
        'presentation': 'inline_card',
        'root': {'id': 'x', 'type': 'hologram'},
      });
      await host(tester, NexaUiDocumentCard(uiId: 'ui_none', controller: c));
      expect(find.byKey(const Key('nexa_ui_unsupported')), findsOneWidget);
      expect(find.byKey(const Key('nexa_ui_loading')), findsNothing);
    });

    testWidgets('a truncated voice document still shows Loading', (
      tester,
    ) async {
      c.onUi({
        'schema': 'nexa.ui/1',
        'id': 'ui_big',
        'category': 'choices_forms',
        'truncated': true,
      });
      await host(tester, NexaUiDocumentCard(uiId: 'ui_big', controller: c));
      expect(find.byKey(const Key('nexa_ui_loading')), findsOneWidget);
    });

    testWidgets('a stale document is greyed out and stays disabled', (
      tester,
    ) async {
      var sent = 0;
      c
        ..uiEventSink = ((e) async {
          sent++;
          return 'unknown_ui_component';
        })
        ..onUi(confirmDoc('ui_old'));
      await host(tester, NexaUiDocumentCard(uiId: 'ui_old', controller: c));
      await tester.tap(find.byKey(const Key('nexa_ui_confirm_ok')));
      await tester.pump();
      await tester.pump();
      expect(c.isUiExpired('ui_old'), isTrue);
      expect(find.byKey(const Key('nexa_ui_expired')), findsOneWidget);
      expect(find.byKey(const Key('nexa_ui_refused')), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('nexa_ui_confirm_ok')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(sent, 1, reason: 'an expired document sends nothing more');

      // Another card of the same document is expired too.
      await host(tester, NexaUiDocumentCard(uiId: 'ui_old', controller: c));
      expect(find.byKey(const Key('nexa_ui_expired')), findsOneWidget);
    });

    testWidgets('a network failure offers Retry; success clears the error', (
      tester,
    ) async {
      var sent = 0;
      c
        ..uiEventSink = ((e) async => ++sent == 1 ? 'network_error' : null)
        ..onUi(confirmDoc('ui_net'));
      await host(tester, NexaUiDocumentCard(uiId: 'ui_net', controller: c));
      await tester.tap(find.byKey(const Key('nexa_ui_confirm_ok')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const Key('nexa_ui_refused')), findsOneWidget);
      expect(
        c.isUiExpired('ui_net'),
        isFalse,
        reason: 'not stale, just failed',
      );

      await tester.tap(find.byKey(const Key('nexa_ui_retry')));
      await tester.pump();
      await tester.pump();
      expect(sent, 2);
      expect(find.byKey(const Key('nexa_ui_refused')), findsNothing);
      expect(find.byKey(const Key('nexa_ui_retry')), findsNothing);
    });
  });

  group('ui_event in flight (D-02)', () {
    NexaUiEvent ev(String component) => NexaUiEvent(
      uiId: 'ui_1',
      componentId: component,
      event: 'select',
      optionIds: const ['a'],
    );

    test('a second tap on the same component sends nothing', () async {
      final gate = Completer<String?>();
      var sent = 0;
      c.uiEventSink = (e) {
        sent++;
        return gate.future;
      };
      final first = c.sendUiEvent(ev('list'));
      expect(c.isUiEventInFlight('ui_1', 'list'), isTrue);
      final second = await c.sendUiEvent(ev('list'));
      expect(second, LabeebToolCallController.uiEventInFlight);
      expect(sent, 1);

      gate.complete(null);
      expect(await first, isNull);
      expect(c.isUiEventInFlight('ui_1', 'list'), isFalse);

      // Once answered, the same component can send again.
      c.uiEventSink = (e) async {
        sent++;
        return null;
      };
      expect(await c.sendUiEvent(ev('list')), isNull);
      expect(sent, 2);
    });

    test('different components do not block each other', () async {
      final gate = Completer<String?>();
      var sent = 0;
      c.uiEventSink = (e) {
        sent++;
        return gate.future;
      };
      final a = c.sendUiEvent(ev('one'));
      final b = c.sendUiEvent(ev('two'));
      expect(sent, 2);
      gate.complete(null);
      await Future.wait([a, b]);
    });

    test('a failing sink frees the component', () async {
      c.uiEventSink = (e) async => throw StateError('boom');
      await expectLater(c.sendUiEvent(ev('list')), throwsStateError);
      expect(c.isUiEventInFlight('ui_1', 'list'), isFalse);
    });

    testWidgets('the card shows progress and sends once on a double tap', (
      tester,
    ) async {
      final gate = Completer<String?>();
      var sent = 0;
      c
        ..uiEventSink = (e) {
          sent++;
          return gate.future;
        }
        ..onUi({
          'schema': 'nexa.ui/1',
          'id': 'ui_c',
          'category': 'choices_forms',
          'presentation': 'inline_card',
          'root': {
            'id': 'ok',
            'type': 'confirm',
            'text': 'Continue?',
            'on_confirm': {'type': 'send_ui_event', 'event': 'confirm'},
          },
        });
      await host(tester, NexaUiDocumentCard(uiId: 'ui_c', controller: c));
      await tester.tap(find.byKey(const Key('nexa_ui_confirm_ok')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('nexa_ui_confirm_ok')));
      await tester.pump();
      expect(sent, 1);
      expect(c.isUiEventInFlight('ui_c', 'ok'), isTrue);

      gate.complete(null);
      await tester.pump();
      expect(c.isUiEventInFlight('ui_c', 'ok'), isFalse);
      // No refusal text for the ignored second tap.
      expect(find.byKey(const Key('nexa_ui_refused')), findsNothing);
    });
  });

  group('pending state across a restart (D-01)', () {
    const tool = 'device.location.get_current';
    const base = '/v1/sdk/sessions/ses_tools/tool-calls/tc_9';

    testWidgets('a voice-raised call is still answered in its own session', (
      tester,
    ) async {
      final store = InMemoryPendingStore();
      c.pendingStore = store;
      c.ingestVoice(
        'tool_call_requested',
        _call('tc_9', tool, 'awaiting_approval'),
        toolsSessionId: 'ses_tools',
      );
      await c.flushPending();

      // The process restarts: a fresh controller over the same store.
      final c2 = restarted(store);
      await c2.importPending('conv_1');
      gw.routes['GET $base'] = (r) =>
          (200, _call('tc_9', tool, 'awaiting_approval'));
      gw.routes['POST $base/approval'] = (r) =>
          (200, _call('tc_9', tool, 'awaiting_client'));
      c2.restore([
        LabeebMessage(
          id: 'm1',
          role: 'assistant',
          text: '',
          createdAt: DateTime.utc(2026, 11, 3),
          parts: const [
            {'type': 'tool_request', 'tool_call_id': 'tc_9', 'tool': tool},
          ],
        ),
      ]);
      await settle(tester);
      expect(
        c2.activities.single.phase,
        LabeebLocalPhase.awaitingUser,
        reason: 'the user can approve or deny again; nothing runs by itself',
      );

      unawaited(c2.decide('tc_9', allow: true));
      await settle(tester);
      final approvals = gw.requests.where((r) => r.path.endsWith('/approval'));
      expect(approvals.single.path, '$base/approval');
      c2.dispose();
    });

    testWidgets('finished calls are not kept', (tester) async {
      final store = InMemoryPendingStore();
      c.pendingStore = store;
      c.ingestVoice(
        'tool_call_requested',
        _call('tc_9', tool, 'awaiting_approval'),
        toolsSessionId: 'ses_tools',
      );
      await c.flushPending();
      expect((await store.load('conv_1')).calls, hasLength(1));

      c.ingestVoice(
        'tool_call_completed',
        _call('tc_9', tool, 'succeeded', side: 'server'),
        toolsSessionId: 'ses_tools',
      );
      await c.flushPending();
      expect((await store.load('conv_1')).calls, isEmpty);
    });

    testWidgets('a half-filled form survives', (tester) async {
      final store = InMemoryPendingStore();
      c.pendingStore = store;
      c.setUiValue('ui_1', 'city', 'Basra');
      await c.flushPending();

      final c2 = restarted(store);
      await c2.importPending('conv_1');
      expect(c2.uiValue('ui_1', 'city'), 'Basra');
      c2.dispose();
    });

    testWidgets('without a conversation nothing is written', (tester) async {
      final store = InMemoryPendingStore();
      c
        ..pendingStore = store
        ..conversation = (() => null);
      c.setUiValue('ui_1', 'city', 'Basra');
      await c.flushPending();
      expect((await store.load('conv_1')).isEmpty, isTrue);
    });

    testWidgets('only JSON-safe form values are kept', (tester) async {
      final store = InMemoryPendingStore();
      c.pendingStore = store;
      c
        ..setUiValue('ui_1', 'ok', 'text')
        ..setUiValue('ui_1', 'bad', Object());
      await c.flushPending();
      final saved = (await store.load('conv_1')).uiValues['ui_1']!;
      expect(saved, {'ok': 'text'});
    });
  });
}

final class _FakePlayback implements NexaAudioPlayback {
  final played = <String>[];
  final calls = <String>[];
  final _done = StreamController<void>.broadcast();

  @override
  Future<void> play(String path) async {
    played.add(path);
    calls.add('play');
  }

  @override
  Future<void> pause() async => calls.add('pause');

  @override
  Future<void> resume() async => calls.add('resume');

  @override
  Stream<void> get completed => _done.stream;

  @override
  Future<void> dispose() => _done.close();
}
