// Guided voice setup: consent gate, protocol, quality feedback, guests,
// deletion. The plugin channel is mocked (no device).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/voice_setup/voice_setup_page.dart';
import 'package:nexa_example/assistant/voice_setup/voice_setup_protocol.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('nexa_assistant/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object?> replies;

  setUp(() {
    calls = [];
    replies = {
      'voiceSetupStatus': {'consented': false},
      'voiceSetupConsent': {'consented': true, 'keepClips': true},
      'voiceSetupBegin': null,
      'voiceSetupEnd': null,
    };
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return replies[call.method];
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: VoiceSetupPage(plugin: NexaAssistant(supported: true))),
    );
    await tester.pumpAndSettle();
  }

  List<String> called() => calls.map((c) => c.method).toList();

  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        300,
        scrollable: find.byType(Scrollable).first,
      );
    }
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  testWidgets('no recording before explicit consent', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('voice_setup_consent')), findsOneWidget);
    expect(find.byKey(const Key('voice_setup_record')), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('voice_setup_consent_accept')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    FilledButton accept() => tester.widget<FilledButton>(
      find.byKey(const Key('voice_setup_consent_accept')),
    );
    expect(accept().onPressed, isNull, reason: 'the box must be ticked');
    expect(called(), isNot(contains('voiceSetupRecord')));
    expect(
      called(),
      isNot(contains('voiceSetupBegin')),
      reason: 'mic untouched',
    );

    await tap(tester, 'voice_setup_consent_check');
    expect(accept().onPressed, isNotNull);
    await tap(tester, 'voice_setup_consent_accept');
    final consent = calls.firstWhere((c) => c.method == 'voiceSetupConsent');
    expect(consent.arguments, {'accepted': true, 'keepClips': true});
    expect(find.byKey(const Key('voice_setup_overview')), findsOneWidget);
  });

  testWidgets('keeping recordings is a separate, optional choice', (
    tester,
  ) async {
    await open(tester);
    await tap(tester, 'voice_setup_keep');
    await tap(tester, 'voice_setup_consent_check');
    await tap(tester, 'voice_setup_consent_accept');
    final consent = calls.firstWhere((c) => c.method == 'voiceSetupConsent');
    expect(consent.arguments, {'accepted': true, 'keepClips': false});
  });

  group('after consent', () {
    setUp(() => replies['voiceSetupStatus'] = {'consented': true});

    testWidgets('the protocol covers the required conditions and separate '
        'identity sentences', (tester) async {
      final tags = {
        for (final s in ownerProtocol)
          for (final p in s.prompts) ...p.tags,
      };
      expect(
        tags,
        containsAll([
          'normal',
          'quiet',
          'loud',
          'fast',
          'slow',
          'near',
          'far',
          'noise',
          'negative',
          'background',
        ]),
      );
      final identity = ownerProtocol
          .expand((s) => s.prompts)
          .where((p) => p.kind == 'identity');
      expect(identity.length, greaterThanOrEqualTo(20));
      expect(
        identity.any((p) => p.textAr.contains('يا أمير')),
        isFalse,
        reason: 'identity must not be tied to the wake phrase',
      );
      expect(
        ownerProtocol
            .expand((s) => s.prompts)
            .where((p) => p.kind == 'wake')
            .length,
        greaterThanOrEqualTo(55),
      );
    });

    testWidgets('a take is sent with its condition and shows the measured '
        'level; a problem asks for a retry', (tester) async {
      await open(tester);
      expect(called(), contains('voiceSetupBegin'));
      await tester.tap(find.byKey(const Key('voice_setup_stage_wake_quiet')));
      await tester.pumpAndSettle();
      replies['voiceSetupRecord'] = {'ok': false, 'reason': 'too_noisy'};
      await tester.tap(find.byKey(const Key('voice_setup_record')));
      await tester.pumpAndSettle();
      final rec = calls.lastWhere((c) => c.method == 'voiceSetupRecord');
      expect(rec.arguments, containsPair('kind', 'wake'));
      expect(rec.arguments, containsPair('tags', ['quiet']));
      expect(rec.arguments, containsPair('speaker', 'owner'));
      expect(find.byKey(const Key('voice_setup_take_problem')), findsOneWidget);
      expect(find.byKey(const Key('voice_setup_next')), findsNothing);

      replies['voiceSetupRecord'] = {
        'ok': true,
        'embedded': true,
        'metrics': {'peakDb': -31.0, 'snrDb': 22.0},
        'status': {
          'consented': true,
          'clips': {'owner:wake': 1},
        },
      };
      await tester.tap(find.byKey(const Key('voice_setup_record')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('voice_setup_take_ok')), findsOneWidget);
      expect(find.textContaining('-31'), findsOneWidget);
      await tester.tap(find.byKey(const Key('voice_setup_next')));
      await tester.pumpAndSettle();
      expect(find.textContaining('2 of 6'), findsOneWidget);
    });

    testWidgets('finish reports what is still missing', (tester) async {
      await open(tester);
      replies['voiceSetupFinish'] = {
        'ok': false,
        'reason': 'too_few_identity_sentences',
        'have': 3,
      };
      await tap(tester, 'voice_setup_finish');
      expect(
        tester
            .widget<Text>(find.byKey(const Key('voice_setup_finish_hint')))
            .data,
        contains('3 so far'),
      );
      expect(find.byKey(const Key('voice_setup_summary')), findsNothing);
    });

    testWidgets('a calibrated profile says what was and was not measured', (
      tester,
    ) async {
      await open(tester);
      replies['voiceSetupFinish'] = {
        'ok': true,
        'mode': 'owner_only',
        'threshold': 0.52,
        'ownerP05': 0.66,
        'ownerMedian': 0.8,
        'separable': true,
        'ownerSamples': 40,
        'identitySamples': 24,
        'impostorSamples': 0,
      };
      await tap(tester, 'voice_setup_finish');
      expect(find.byKey(const Key('voice_setup_summary')), findsOneWidget);
      expect(
        find.textContaining('Strangers were not measured'),
        findsOneWidget,
      );
      expect(find.textContaining('0.52'), findsOneWidget);
    });

    testWidgets('a guest is added only after the owner confirms they agree', (
      tester,
    ) async {
      await open(tester);
      await tap(tester, 'voice_setup_add_guest');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('voice_setup_stage_guest_wake')),
        findsNothing,
      );

      await tap(tester, 'voice_setup_add_guest');
      await tester.tap(find.byKey(const Key('voice_setup_guest_confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('voice_setup_stage_guest_wake')));
      await tester.pumpAndSettle();
      replies['voiceSetupRecord'] = {
        'ok': true,
        'metrics': <String, Object?>{},
        'status': <String, Object?>{},
      };
      await tester.tap(find.byKey(const Key('voice_setup_record')));
      await tester.pumpAndSettle();
      final rec = calls.lastWhere((c) => c.method == 'voiceSetupRecord');
      expect(rec.arguments, containsPair('speaker', 'guest_1'));
    });

    testWidgets('delete asks first, then removes everything and asks for '
        'consent again', (tester) async {
      await open(tester);
      replies['voiceSetupDelete'] = {'consented': false};
      await tester.tap(find.byKey(const Key('voice_setup_delete')));
      await tester.pumpAndSettle();
      expect(called(), isNot(contains('voiceSetupDelete')));
      await tester.tap(find.byKey(const Key('voice_setup_delete_confirm')));
      await tester.pumpAndSettle();
      expect(called(), contains('voiceSetupDelete'));
      expect(find.byKey(const Key('voice_setup_consent')), findsOneWidget);
    });
  });

  testWidgets('leaving the screen gives the microphone back', (tester) async {
    replies['voiceSetupStatus'] = {'consented': true};
    await open(tester);
    await tester.pumpWidget(const SizedBox());
    expect(called(), contains('voiceSetupEnd'));
  });
}
