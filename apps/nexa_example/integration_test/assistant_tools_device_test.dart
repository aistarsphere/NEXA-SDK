// On-device acceptance fixtures for the assistant's tool / UI path.
//
// Runs on a real phone (`flutter test integration_test/... -d <id>`) with
// the app's REAL theme controller, the real tool card and compact panel
// widgets. Only the HTTP layer is replaced by a fake gateway that answers
// with documented labeeb.sdk/1 shapes, so the test proves:
// event → controller → rendered card / panel buttons → user tap → the
// local theme actually changes → one structured result per tool call.
// It does NOT prove that the live agent emits the tool call (that needs
// the backend; see docs/qa/android-voice-acceptance.md).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:nexa_core/testing.dart';
import 'package:nexa_example/brand/labeeb_theme_controller.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

typedef _Req = ({String method, String path, Object? body});

final class _Gateway implements HttpClientAdapter {
  final List<_Req> requests = [];
  final Map<String, (int, Object?) Function(_Req)> routes = {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) async {
    Object? body = o.data;
    if (stream != null) {
      final bytes = await stream.expand((c) => c).toList();
      body = jsonDecode(utf8.decode(bytes));
    }
    final req = (method: o.method, path: o.path, body: body);
    requests.add(req);
    final h = routes['${o.method} ${o.path}'];
    final (status, json) = h == null
        ? (
            404,
            {
              'error': {'code': 'not_found'},
            },
          )
        : h(req);
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
  String status,
  Map<String, Object?> args,
) => {
  'tool_call_id': id,
  'tool': 'app.theme.apply',
  'side': 'client',
  'arguments': args,
  'status': status,
  'approval_required': true,
  'deadline_at': '2030-01-01T00:00:00Z',
  'asynchronous': false,
};

final class _AllowAll implements NexaPermissionHandler {
  const _AllowAll();
  @override
  Future<bool> request(NexaPermission permission) async => true;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _Gateway gw;
  late LabeebThemeController theme;
  late LabeebToolCallController tools;
  late Directory tmp;
  BuildContext? ctx;

  const args = {'palette_id': 'pal_ocean', 'mode': 'dark'};

  void routes(String id) {
    final path = '/v1/sdk/sessions/ses_1/tool-calls/$id';
    gw.routes['POST $path/approval'] = (r) =>
        (200, _call(id, 'awaiting_client', args));
    gw.routes['POST $path/result'] = (r) => (200, _call(id, 'succeeded', args));
    gw.routes['GET /v1/sdk/me/preferences'] = (r) =>
        (200, {'preferences': <String, Object?>{}});
    gw.routes['PUT /v1/sdk/me/preferences'] = (r) =>
        (200, r.body! as Map<String, Object?>);
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('labeeb_qa');
    theme = await LabeebThemeController.load(File('${tmp.path}/theme.json'));
    gw = _Gateway();
    final dio = Dio(BaseOptions(baseUrl: 'https://gw.test/nexa/api'))
      ..httpClientAdapter = gw;
    tools =
        LabeebToolCallController(
            api: LabeebSdkClient(dio),
            media: NexaConversationMedia(),
            host: NexaHostCapabilities(theme: theme),
            tools: [const LabeebThemeApplyTool()],
          )
          ..chatSession = (() => 'ses_1')
          ..conversation = (() => 'conv_1')
          ..presenter = (() => ctx);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: NexaLocale.supported,
    localizationsDelegates: NexaLocale.delegates,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          ctx = context;
          return Align(alignment: Alignment.bottomCenter, child: child);
        },
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 25));
    }
  }

  int results(String id) => gw.requests
      .where((r) => r.path.endsWith('/tool-calls/$id/result'))
      .length;

  testWidgets('full view: voice theme call → card → Allow → theme applied '
      '→ one result', (tester) async {
    routes('tc_qa1');
    expect(theme.appliedPaletteId, isNot('pal_ocean'));
    await tester.pumpWidget(
      host(
        SingleChildScrollView(
          child: LabeebToolCallCard(toolCallId: 'tc_qa1', controller: tools),
        ),
      ),
    );
    tools.ingestVoice(
      'tool_call_requested',
      _call('tc_qa1', 'awaiting_approval', args),
      toolsSessionId: 'ses_1',
    );
    await settle(tester);
    final allow = find.byKey(const Key('labeeb_tc_allow_tc_qa1'));
    expect(allow, findsOneWidget, reason: 'TOOL_NOT_RENDERED');
    await tester.tap(allow);
    await settle(tester);
    expect(theme.appliedPaletteId, 'pal_ocean', reason: 'ACTION_NOT_EXECUTED');
    expect(results('tc_qa1'), 1, reason: 'RESULT_NOT_ACKNOWLEDGED once');
    final result = gw.requests.firstWhere(
      (r) => r.path.endsWith('/tc_qa1/result'),
    );
    expect((result.body! as Map)['result'], containsPair('status', 'applied'));
  });

  testWidgets('compact panel: approval shown in the panel, Allow applies', (
    tester,
  ) async {
    routes('tc_qa2');
    final client = await Nexa.initialize(
      config: NexaConfig(
        applicationId: 'app_qa',
        gatewayBaseUri: Uri.parse('http://localhost'),
        environment: NexaEnvironment.development,
        requestedCapabilities: const {
          NexaCapability.textChat,
          NexaCapability.liveVoice,
        },
      ),
      auth: MockAuthProvider(),
      overrides: NexaOverrides(
        chatTransport: MockChatTransport(
          tokenDelay: Duration.zero,
          thinkDelay: Duration.zero,
        ),
        voiceTransport: MockRealtimeVoiceTransport(),
        voiceProvisioner: MockVoiceProvisioner(),
        permissionHandler: const _AllowAll(),
      ),
    );
    addTearDown(client.dispose);
    await tester.pumpWidget(
      host(
        SizedBox(
          height: 176,
          child: NexaCompactVoicePanel(
            voice: client.voice,
            tools: tools,
            title: 'لبيب',
            onClosed: (_) {},
            onExpand: () {},
          ),
        ),
      ),
    );
    await settle(tester);
    tools.ingestVoice(
      'tool_call_requested',
      _call('tc_qa2', 'awaiting_approval', args),
      toolsSessionId: 'ses_1',
    );
    await settle(tester);
    final allow = find.byKey(const Key('nexa_panel_allow'));
    expect(allow, findsOneWidget, reason: 'TOOL_NOT_RENDERED in the panel');
    await tester.tap(allow);
    await settle(tester);
    expect(theme.appliedPaletteId, 'pal_ocean', reason: 'ACTION_NOT_EXECUTED');
    expect(results('tc_qa2'), 1);
    await client.voice.end();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('malformed tool payload: no card, no crash, no result', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(LabeebToolCallCard(toolCallId: 'tc_bad', controller: tools)),
    );
    tools.ingestVoice('tool_call_requested', {
      'tool': 42,
      'status': 'nonsense',
    }, toolsSessionId: 'ses_1');
    await settle(tester);
    expect(tools.activity('tc_bad'), isNull);
    expect(gw.requests.where((r) => r.path.contains('tc_bad')), isEmpty);
  });
}
