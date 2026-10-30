// `device.microphone.record_sample`: consent-first recording sheet and the
// `{asset_id, duration_s}` answer, with a fake recorder (no microphone).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_device_tools.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_record_sample.dart';
import 'package:nexa_ui/nexa_ui.dart';

final class _MemFile implements File {
  _MemFile(this.bytes);
  final Uint8List bytes;
  bool deleted = false;

  @override
  Future<Uint8List> readAsBytes() async => bytes;

  @override
  bool existsSync() => !deleted;

  @override
  void deleteSync({bool recursive = false}) => deleted = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeRecorder implements NexaMicrophoneRecorder {
  bool grant = true;
  int starts = 0;
  int cancels = 0;
  final file = _MemFile(Uint8List.fromList(List.filled(64, 7)));
  final _levels = StreamController<double>.broadcast();

  @override
  Future<bool> requestPermission() async => grant;

  @override
  Future<void> start() async => starts++;

  @override
  Stream<double> get level => _levels.stream;

  @override
  Future<File?> stop() async => file;

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> dispose() => _levels.close();
}

NexaToolCall _call(Map<String, Object?> args) => NexaToolCall.fromJson({
  'tool_call_id': 'tc_rec',
  'tool': LabeebTools.recordSample,
  'side': 'client',
  'arguments': {'purpose': 'Create your voice', ...args},
  'status': 'awaiting_client',
  'approval_required': true,
  'asynchronous': false,
})!;

void main() {
  late _FakeRecorder recorder;
  late List<(int, String, String?)> uploads;
  BuildContext? ctx;

  setUp(() {
    recorder = _FakeRecorder();
    uploads = [];
  });

  Future<Future<NexaToolCallAnswer>> open(
    WidgetTester tester,
    Map<String, Object?> args,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: NexaLocale.supported,
        localizationsDelegates: NexaLocale.delegates,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    final tool = LabeebRecordSampleTool(recorder: () => recorder);
    final answer = tool.run(
      LabeebToolRunContext(
        context: ctx,
        upload: (bytes, mime, name) async {
          uploads.add((bytes.length, mime, name));
          return 'ast_voice';
        },
        download: (_) async => Uint8List(0),
      ),
      _call(args),
    );
    await tester.pumpAndSettle();
    return answer;
  }

  VoidCallback? onPressed(WidgetTester tester, String key) =>
      tester.widget<ButtonStyleButton>(find.byKey(Key(key))).onPressed;

  testWidgets('nothing records before Start; Finish after the minimum', (
    tester,
  ) async {
    final answer = await open(tester, {'min_seconds': 5, 'max_seconds': 30});
    expect(find.byKey(const Key('labeeb_rec_sheet')), findsOneWidget);
    expect(find.text('Create your voice'), findsOneWidget);
    expect(recorder.starts, 0, reason: 'consent first: user starts it');

    await tester.tap(find.byKey(const Key('labeeb_rec_start')));
    await tester.pump();
    expect(recorder.starts, 1);
    expect(find.byKey(const Key('labeeb_rec_live')), findsOneWidget);
    expect(onPressed(tester, 'labeeb_rec_finish'), isNull);
    expect(find.byKey(const Key('labeeb_rec_more')), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    expect(onPressed(tester, 'labeeb_rec_finish'), isNotNull);
    await tester.tap(find.byKey(const Key('labeeb_rec_finish')));
    await tester.pumpAndSettle();

    final a = await answer;
    expect(a.toJson()['result'], {'asset_id': 'ast_voice', 'duration_s': 6.0});
    expect(uploads.single, (64, 'audio/wav', 'voice-sample.wav'));
    expect(recorder.file.deleted, isTrue, reason: 'no audio kept on device');
  });

  testWidgets('stops itself at the maximum', (tester) async {
    final answer = await open(tester, {'min_seconds': 5, 'max_seconds': 10});
    await tester.tap(find.byKey(const Key('labeeb_rec_start')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();
    final result = (await answer).toJson()['result']! as Map;
    expect(result['duration_s'], lessThanOrEqualTo(10.4));
    expect(result['duration_s'], greaterThanOrEqualTo(10.0));
  });

  testWidgets('microphone denied: settings guidance, permission_denied', (
    tester,
  ) async {
    recorder.grant = false;
    final answer = await open(tester, const {});
    await tester.tap(find.byKey(const Key('labeeb_rec_start')));
    await tester.pump();
    expect(find.byKey(const Key('labeeb_rec_denied')), findsOneWidget);
    expect(find.byKey(const Key('labeeb_rec_settings')), findsOneWidget);
    expect(recorder.starts, 0);
    await tester.tap(find.byKey(const Key('labeeb_rec_cancel')));
    await tester.pumpAndSettle();
    expect(
      (await answer).toJson()['error'],
      containsPair('code', 'permission_denied'),
    );
    expect(uploads, isEmpty);
  });

  testWidgets('cancel while recording discards it', (tester) async {
    final answer = await open(tester, const {});
    await tester.tap(find.byKey(const Key('labeeb_rec_start')));
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const Key('labeeb_rec_cancel')));
    await tester.pumpAndSettle();
    expect(recorder.cancels, 1);
    expect((await answer).toJson()['error'], containsPair('code', 'cancelled'));
    expect(uploads, isEmpty);
  });

  test('argument bounds follow the contract', () {
    expect(LabeebRecordSampleTool.bounds(const {}), (5, 30));
    expect(
      LabeebRecordSampleTool.bounds(const {
        'min_seconds': 2,
        'max_seconds': 90,
      }),
      (5, 60),
    );
    expect(
      LabeebRecordSampleTool.bounds(const {
        'min_seconds': 25,
        'max_seconds': 10,
      }),
      (25, 25),
    );
  });
}
