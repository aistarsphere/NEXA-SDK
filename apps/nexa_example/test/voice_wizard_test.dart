// "Set up my voice": consent first, ONE natural sentence, a DIFFERENT sentence
// to check it, an extra sentence only when the plugin says the check was not
// conclusive, a wake-phrase try-out, restoration after a restart. The plugin
// channel is mocked; the decision rule itself is tested in Kotlin.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/voice/voice_status_card.dart';
import 'package:nexa_example/assistant/voice/voice_wizard_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('nexa_assistant/methods');
  const events = EventChannel('nexa_assistant/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object?> status;
  late Object? Function(MethodCall) onCall;
  late void Function(Map<String, Object?>) push;

  setUp(() {
    calls = [];
    status = {'consented': false, 'state': 'none', 'takes': 0};
    onCall = (c) => null;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'enrollStatus':
          return Map<String, Object?>.of(status);
        case 'voiceSetupConsent':
          status = {...status, 'consented': true};
          return {'consented': true};
        case 'status':
          return {
            'platformSupported': true,
            'wakePhraseId': 'yaameer',
            'requireOwnerVoice': false,
            'wakePhrases': [
              {'id': 'yaameer', 'label': 'يا أمير', 'installed': true},
            ],
          };
        case 'capabilities':
          return {'roleHeld': true};
        case 'voiceSetupDelete':
          status = {'consented': false, 'state': 'none', 'takes': 0};
          return {'consented': false};
      }
      return onCall(call);
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          push = sink.success;
        },
      ),
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  List<String> called() => calls.map((c) => c.method).toList();

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceWizardPage(plugin: NexaAssistant(supported: true)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// A recording that the plugin answers with [reply] and moves the saved state to [next].
  void plugin(Map<String, Object?> reply, Map<String, Object?> next) {
    onCall = (c) {
      if (c.method == 'enrollRecord') {
        status = {...status, ...next};
        return reply;
      }
      return null;
    };
  }

  testWidgets('first time: only a short consent is shown, nothing records', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(const Key('voice_wizard_consent')), findsOneWidget);
    expect(find.byKey(const Key('voice_wizard_record')), findsNothing);
    expect(called(), isNot(contains('enrollRecord')));
    expect(
      called(),
      isNot(contains('voiceSetupBegin')),
      reason: 'microphone untouched',
    );
    FilledButton accept() => tester.widget<FilledButton>(
      find.byKey(const Key('voice_wizard_consent_accept')),
    );
    expect(accept().onPressed, isNull);
    await tester.tap(find.byKey(const Key('voice_wizard_consent_check')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('voice_wizard_consent_accept')));
    await tester.pumpAndSettle();
    final consent = calls.firstWhere((c) => c.method == 'voiceSetupConsent');
    expect(consent.arguments, {
      'accepted': true,
      'keepClips': false,
    }, reason: 'no raw audio kept by default');
    expect(find.byKey(const Key('voice_wizard_enroll')), findsOneWidget);
  });

  testWidgets('one sentence, then a DIFFERENT one, then the wake try-out; '
      'no counts, no scores', (tester) async {
    status = {'consented': true, 'state': 'none', 'takes': 0};
    await open(tester);
    final first = tester
        .widget<Text>(find.byKey(const Key('voice_wizard_sentence')))
        .data;
    expect(find.text('Read this sentence naturally'), findsOneWidget);
    expect(
      first,
      isNot(contains('يا أمير')),
      reason: 'identity is not tied to the wake phrase',
    );

    plugin(
      {'ok': true, 'state': 'enrolled', 'takes': 1},
      {'state': 'enrolled', 'takes': 1},
    );
    await tester.tap(find.byKey(const Key('voice_wizard_record')));
    await settle(tester);
    expect(calls.firstWhere((c) => c.method == 'enrollRecord').arguments, {
      'role': 'enroll',
    });
    expect(find.byKey(const Key('voice_wizard_verify')), findsOneWidget);
    final second = tester
        .widget<Text>(find.byKey(const Key('voice_wizard_sentence')))
        .data;
    expect(
      second,
      isNot(first),
      reason: 'verification uses a different sentence',
    );

    plugin(
      {'ok': true, 'state': 'ready', 'takes': 2},
      {'state': 'ready', 'takes': 2},
    );
    await tester.tap(find.byKey(const Key('voice_wizard_record')));
    await settle(tester);
    expect(calls.where((c) => c.method == 'enrollRecord').last.arguments, {
      'role': 'verify',
    });
    expect(find.byKey(const Key('voice_wizard_try')), findsOneWidget);
    expect(find.textContaining('0.'), findsNothing, reason: 'no scores shown');
    expect(find.byKey(const Key('voice_wizard_finish')), findsOneWidget);
  });

  testWidgets(
    'an inconclusive check asks for ONE more sentence, with the reason',
    (tester) async {
      status = {'consented': true, 'state': 'enrolled', 'takes': 1};
      await open(tester);
      expect(find.byKey(const Key('voice_wizard_verify')), findsOneWidget);
      plugin(
        {'ok': true, 'state': 'more', 'reason': 'not_sure', 'takes': 2},
        {'state': 'more', 'takes': 2, 'reason': 'not_sure'},
      );
      await tester.tap(find.byKey(const Key('voice_wizard_record')));
      await settle(tester);
      expect(find.byKey(const Key('voice_wizard_extra')), findsOneWidget);
      expect(find.textContaining('Not sure yet'), findsOneWidget);

      plugin(
        {'ok': true, 'state': 'ready', 'takes': 3},
        {'state': 'ready', 'takes': 3},
      );
      await tester.tap(find.byKey(const Key('voice_wizard_record')));
      await settle(tester);
      expect(calls.where((c) => c.method == 'enrollRecord').last.arguments, {
        'role': 'extra',
      });
      expect(find.byKey(const Key('voice_wizard_try')), findsOneWidget);
    },
  );

  testWidgets('a different-sounding voice is told so, never accepted', (
    tester,
  ) async {
    status = {'consented': true, 'state': 'enrolled', 'takes': 1};
    await open(tester);
    plugin(
      {'ok': true, 'state': 'more', 'reason': 'different_voice', 'takes': 2},
      {'state': 'more', 'takes': 2, 'reason': 'different_voice'},
    );
    await tester.tap(find.byKey(const Key('voice_wizard_record')));
    await settle(tester);
    expect(find.textContaining('did not sound like the first'), findsOneWidget);
    expect(find.byKey(const Key('voice_wizard_try')), findsNothing);
  });

  testWidgets(
    'silence, noise and short speech get a precise message and a retry, '
    'and the saved state is unchanged',
    (tester) async {
      status = {'consented': true, 'state': 'none', 'takes': 0};
      await open(tester);
      for (final (reason, text) in [
        ('no_speech', 'No speech detected'),
        ('too_noisy', 'Too much background noise'),
        ('too_short', 'speak a little longer'),
        ('interrupted', 'interrupted'),
      ]) {
        onCall = (c) => c.method == 'enrollRecord'
            ? {'ok': false, 'reason': reason, 'state': 'none'}
            : null;
        await tester.tap(find.byKey(const Key('voice_wizard_record')));
        await settle(tester);
        expect(
          find.byKey(const Key('voice_wizard_problem')),
          findsOneWidget,
          reason: reason,
        );
        expect(find.textContaining(text), findsOneWidget, reason: reason);
        expect(find.textContaining('too long'), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
      }
      expect(status['state'], 'none');
    },
  );

  testWidgets(
    'live states: preparing, speak now, listening, checking; stop cancels',
    (tester) async {
      status = {'consented': true, 'state': 'none', 'takes': 0};
      await open(tester);
      final gate = Completer<Object?>();
      onCall = (c) {
        if (c.method == 'enrollRecord') return gate.future;
        if (c.method == 'voiceSetupCancel' && !gate.isCompleted) {
          gate.complete({
            'ok': false,
            'reason': 'interrupted',
            'state': 'none',
          });
        }
        return null;
      };
      await tester.tap(find.byKey(const Key('voice_wizard_record')));
      await tester.pump();
      expect(find.text('Preparing the microphone…'), findsOneWidget);
      push({'type': 'setup', 'stage': 'ready'});
      await settle(tester);
      expect(find.text('Speak now'), findsOneWidget);
      push({'type': 'setup', 'stage': 'speech'});
      await settle(tester);
      expect(find.text('Listening…'), findsOneWidget);
      push({'type': 'setup', 'stage': 'processing'});
      await settle(tester);
      expect(find.text('Checking the recording…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice_wizard_stop')));
      await settle(tester);
      expect(called(), contains('voiceSetupCancel'));
      expect(find.byKey(const Key('voice_wizard_problem')), findsOneWidget);
    },
  );

  testWidgets('restored after a restart: the wizard resumes where it was', (
    tester,
  ) async {
    status = {'consented': true, 'state': 'enrolled', 'takes': 1};
    await open(tester);
    expect(find.byKey(const Key('voice_wizard_verify')), findsOneWidget);
    expect(find.byKey(const Key('voice_wizard_consent')), findsNothing);
  });

  testWidgets('step 3 tests the phrase and the voice as two separate results', (
    tester,
  ) async {
    status = {
      'consented': true,
      'state': 'ready',
      'takes': 2,
      'hasProfile': true,
    };
    onCall = (c) => c.method == 'wakeTest'
        ? {
            'ok': true,
            'detections': 1,
            'maxScore': 0.97,
            'threshold': 0.9,
            'owner': 'uncertain',
          }
        : null;
    await open(tester);
    await tester.tap(find.byKey(const Key('voice_wizard_wake_test')));
    await settle(tester);
    final test = calls.firstWhere((c) => c.method == 'wakeTest');
    expect(test.arguments, containsPair('checkOwner', true));
    expect(find.text('Phrase heard'), findsOneWidget);
    expect(find.textContaining('not sure'), findsOneWidget);
    // The Android assistant is reported from the system, not assumed.
    expect(find.text('Android assistant: set up'), findsOneWidget);
  });

  testWidgets(
    'could not be made consistent: manual tap-to-talk stays, start over offered',
    (tester) async {
      status = {
        'consented': true,
        'state': 'improve',
        'takes': 4,
        'reason': 'not_consistent',
      };
      await open(tester);
      expect(find.byKey(const Key('voice_wizard_improve')), findsOneWidget);
      expect(find.textContaining('tap to talk'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice_wizard_again')));
      await settle(tester);
      expect(called(), containsAll(['voiceSetupDelete', 'voiceSetupConsent']));
    },
  );

  group('the single entry in settings', () {
    Future<void> card(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VoiceStatusCard(plugin: NexaAssistant(supported: true)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('not configured: one prominent button and nothing technical', (
      tester,
    ) async {
      await card(tester);
      expect(find.text('Not configured'), findsOneWidget);
      expect(find.byKey(const Key('voice_card_setup')), findsOneWidget);
      expect(find.byKey(const Key('voice_card_test')), findsNothing);
      expect(find.textContaining('threshold'), findsNothing);
      expect(find.textContaining('sample'), findsNothing);
    });

    testWidgets('ready: status, test, set up again, delete (confirmed)', (
      tester,
    ) async {
      status = {
        'consented': true,
        'state': 'ready',
        'takes': 2,
        'hasProfile': true,
      };
      onCall = (c) =>
          c.method == 'voiceTest' ? {'ok': true, 'result': 'match'} : null;
      await card(tester);
      expect(find.text('Ready'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice_card_test')));
      await settle(tester);
      expect(find.text('Voice: matches you'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice_card_delete')));
      await tester.pumpAndSettle();
      expect(
        called(),
        isNot(contains('voiceSetupDelete')),
        reason: 'asks first',
      );
      await tester.tap(find.byKey(const Key('voice_card_delete_confirm')));
      await tester.pumpAndSettle();
      expect(called(), contains('voiceSetupDelete'));
      expect(find.text('Not configured'), findsOneWidget);
    });

    testWidgets('needs improvement is shown as such, with the manual path', (
      tester,
    ) async {
      status = {'consented': true, 'state': 'improve', 'takes': 4};
      await card(tester);
      expect(find.text('Needs improvement'), findsOneWidget);
      expect(find.byKey(const Key('voice_card_test')), findsNothing);
      expect(find.textContaining('tap to talk'), findsOneWidget);
    });
  });
}
