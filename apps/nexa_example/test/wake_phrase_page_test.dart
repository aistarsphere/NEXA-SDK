// The wake phrase screen: switching calls the plugin (which switches the real
// acoustic model), "try it" reports what the detector heard, and a custom
// phrase is validated but never pretended to work without a model.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/wake/wake_phrase_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('nexa_assistant/methods');
  const events = EventChannel('nexa_assistant/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late String active;
  late Object? Function(MethodCall) onCall;

  setUp(() {
    calls = [];
    active = 'yaameer';
    onCall = (c) => null;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      if (call.method == 'status') {
        return {
          'platformSupported': true,
          'wakePhraseId': active,
          'wakeDetector': 'neural',
          'wakePhrases': [
            {
              'id': 'yaameer',
              'label': 'يا أمير',
              'installed': true,
              'status': 'experimental',
            },
            {
              'id': 'amir',
              'label': 'أمير',
              'installed': true,
              'status': 'experimental',
            },
            {
              'id': 'abbas',
              'label': 'عباس',
              'installed': true,
              'status': 'experimental',
            },
            {
              'id': 'ghost',
              'label': 'شبح',
              'installed': false,
              'status': 'experimental',
            },
          ],
        };
      }
      if (call.method == 'setWakePhrase') {
        active = (call.arguments as Map)['id'] as String;
        return 'ok';
      }
      return onCall(call);
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (_, sink) {}),
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: WakePhrasePage(plugin: NexaAssistant(supported: true))),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists only installed models, each labelled experimental', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('wake_phrase_yaameer')), findsOneWidget);
    expect(find.byKey(const Key('wake_phrase_abbas')), findsOneWidget);
    expect(
      find.byKey(const Key('wake_phrase_ghost')),
      findsNothing,
      reason: 'no acoustic model installed: not offered',
    );
    expect(find.textContaining('synthetic speech'), findsNWidgets(3));
    expect(find.text('Validated on this phone'), findsNothing);
  });

  testWidgets('choosing a phrase asks the plugin to switch the real detector', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('wake_phrase_active_yaameer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('wake_phrase_use_abbas')));
    await tester.pumpAndSettle();
    final c = calls.firstWhere((c) => c.method == 'setWakePhrase');
    expect(c.arguments, {'id': 'abbas'});
    expect(find.byKey(const Key('wake_phrase_active_abbas')), findsOneWidget);
    expect(find.byKey(const Key('wake_phrase_active_yaameer')), findsNothing);
  });

  testWidgets('try it reports what the detector heard, and what it needed', (
    tester,
  ) async {
    onCall = (c) => c.method == 'wakeTest'
        ? {
            'ok': true,
            'id': 'abbas',
            'detections': 0,
            'maxScore': 0.41,
            'threshold': 0.9,
          }
        : null;
    await open(tester);
    await tester.tap(find.byKey(const Key('wake_phrase_try_abbas')));
    await tester.pumpAndSettle();
    expect(calls.firstWhere((c) => c.method == 'wakeTest').arguments, {
      'id': 'abbas',
      'seconds': 10,
      'checkOwner': false,
    });
    expect(
      tester
          .widget<Text>(find.byKey(const Key('wake_phrase_result_abbas')))
          .data,
      allOf(contains('Not heard'), contains('0.41'), contains('0.90')),
    );
    onCall = (c) => c.method == 'wakeTest'
        ? {
            'ok': true,
            'id': 'abbas',
            'detections': 2,
            'maxScore': 0.97,
            'threshold': 0.9,
          }
        : null;
    await tester.tap(find.byKey(const Key('wake_phrase_try_abbas')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const Key('wake_phrase_result_abbas')))
          .data,
      contains('Heard it 2 time'),
    );
  });

  testWidgets('a custom phrase is validated, and never claimed to work', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('wake_custom_status')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('wake_custom_field')), 'نم');
    await tester.pump();
    expect(
      find.byKey(const Key('wake_custom_issue_tooFewCharacters')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('wake_custom_field')), 'شكرا');
    await tester.pump();
    expect(
      find.byKey(const Key('wake_custom_issue_commonWord')),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('wake_custom_field')), 'عباس');
    await tester.pump();
    expect(
      find.byKey(const Key('wake_custom_issue_alreadyInstalled')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('wake_custom_field')),
      'يا سلمان',
    );
    await tester.pump();
    expect(find.byKey(const Key('wake_custom_text_ok')), findsOneWidget);
    // Even an acceptable phrase is not offered as usable: there is no model for it.
    expect(find.byKey(const Key('wake_phrase_use_سلمان')), findsNothing);
    expect(find.textContaining('Not available yet'), findsOneWidget);
  });
}
