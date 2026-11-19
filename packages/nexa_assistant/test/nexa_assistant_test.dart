import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('nexa_assistant/methods');
  const events = EventChannel('nexa_assistant/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object?> replies;

  setUp(() {
    calls = [];
    replies = {};
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return replies[call.method];
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  NexaAssistant android() => NexaAssistant(supported: true);

  test(
    'wake phrases: only installed acoustic models can be selected',
    () async {
      replies['status'] = {
        'platformSupported': true,
        'wakeDetector': 'neural',
        'wakePhraseId': 'yaameer',
        'wakePhrases': [
          {'id': 'yaameer', 'label': 'يا أمير', 'installed': true},
          {'id': 'custom', 'label': 'عبارة', 'installed': false},
        ],
      };
      final st = await android().status();
      expect(st.wakeDetector, 'neural');
      expect(st.wakePhraseLabel, 'يا أمير');
      expect(st.wakePhrases.map((p) => p.installed), [true, false]);

      replies['setWakePhrase'] = 'ok';
      expect(await android().setWakePhrase('yaameer'), 'ok');
      expect(calls.last.method, 'setWakePhrase');
      expect(calls.last.arguments, {'id': 'yaameer'});

      // A phrase without a model is refused by the plugin, never faked.
      replies['setWakePhrase'] = 'not_installed';
      expect(await android().setWakePhrase('custom'), 'not_installed');
    },
  );

  group('guided voice setup', () {
    test('consent gates recording; the plugin refuses without it', () async {
      replies['voiceSetupRecord'] = {'ok': false, 'reason': 'consent_required'};
      final take = await android().voiceSetupRecord(
        kind: 'wake',
        promptId: 'wake_normal_1',
        tags: ['normal'],
      );
      expect(take.ok, isFalse);
      expect(take.reason, 'consent_required');
      expect(calls.last.arguments, {
        'kind': 'wake',
        'promptId': 'wake_normal_1',
        'tags': ['normal'],
        'speaker': 'owner',
        'maxMs': 6000,
      });
    });

    test('consent, status and a measured take are parsed', () async {
      replies['voiceSetupConsent'] = {
        'consented': true,
        'keepClips': true,
        'clips': {'owner:wake': 3, 'owner:identity': 1},
      };
      final st = await android().voiceSetupConsent(
        accepted: true,
        keepClips: true,
      );
      expect(calls.last.arguments, {'accepted': true, 'keepClips': true});
      expect(st.consented, isTrue);
      expect(st.count('owner', 'wake'), 3);
      expect(st.count('guest_1', 'wake'), 0);

      replies['voiceSetupRecord'] = {
        'ok': true,
        'embedded': true,
        'saved': true,
        'metrics': {
          'durationMs': 2100,
          'speechMs': 800,
          'peakDb': -12.5,
          'speechRmsDb': -24.0,
          'noiseDb': -58.0,
          'snrDb': 34.0,
        },
      };
      final take = await android().voiceSetupRecord(
        kind: 'wake',
        promptId: 'p',
      );
      expect(take.ok, isTrue);
      expect(take.embedded, isTrue);
      expect(take.metrics!.snrDb, 34.0);
    });

    test('finish reports what is missing, or the calibration', () async {
      replies['voiceSetupFinish'] = {
        'ok': false,
        'reason': 'too_few_identity_sentences',
        'have': 3,
      };
      var r = await android().voiceSetupFinish();
      expect(r.ok, isFalse);
      expect(r.reason, 'too_few_identity_sentences');
      expect(r.have, 3);

      replies['voiceSetupFinish'] = {
        'ok': true,
        'mode': 'owner_only',
        'threshold': 0.52,
        'ownerP05': 0.64,
        'ownerMedian': 0.78,
        'separable': true,
        'ownerSamples': 40,
        'impostorSamples': 0,
      };
      r = await android().voiceSetupFinish();
      expect(r.ok, isTrue);
      expect(r.calibration!.measuredStrangers, isFalse);
      expect(r.calibration!.threshold, closeTo(0.52, 1e-9));
    });

    test('delete removes everything and reports the empty status', () async {
      replies['voiceSetupDelete'] = {
        'consented': false,
        'clips': <String, int>{},
        'profileExists': false,
      };
      final st = await android().voiceSetupDelete();
      expect(calls.last.method, 'voiceSetupDelete');
      expect(st.consented, isFalse);
      expect(st.profileExists, isFalse);
    });
  });

  test('status is parsed from the device', () async {
    replies['status'] = {
      'platformSupported': true,
      'sdkInt': 33,
      'release': '13',
      'manufacturer': 'nubia',
      'assistantRoleAvailable': true,
      'isDefaultAssistant': true,
      'hardwareHotword': 'requires_system_app',
      'microphonePermission': true,
      'wakeEnabled': true,
      'listenerState': 'running',
      'enrolled': true,
      'enrolledSamples': 5,
      'speakerEnrolled': true,
      'speakerModelAvailable': true,
      'requireOwnerVoice': true,
      'sensitivity': 'strict',
    };
    final s = await android().status();
    expect(s.platformSupported, isTrue);
    expect(s.sdkInt, 33);
    expect(s.isDefaultAssistant, isTrue);
    expect(s.listening, isTrue);
    expect(s.enrolledSamples, 5);
    expect(s.sensitivity, NexaWakeSensitivity.strict);
    expect(s.hardwareHotword, 'requires_system_app');
  });

  test('toggles report why they could not turn on', () async {
    final a = android();
    replies['setWakeEnabled'] = 'not_enrolled';
    expect(await a.setWakeEnabled(true), NexaAssistantToggle.notEnrolled);
    expect(calls.last.arguments, {'enabled': true});
    replies['setRequireOwnerVoice'] = 'model_unavailable';
    expect(
      await a.setRequireOwnerVoice(true),
      NexaAssistantToggle.modelUnavailable,
    );
    replies['setWakeEnabled'] = 'not_in_foreground';
    expect(await a.setWakeEnabled(true), NexaAssistantToggle.notInForeground);
  });

  test('enrolment and test results', () async {
    final a = android();
    replies['enrollmentRecord'] = {
      'ok': false,
      'reason': 'too_quiet',
      'count': 2,
    };
    final sample = await a.recordEnrollmentSample(
      timeout: const Duration(seconds: 4),
    );
    expect(sample.ok, isFalse);
    expect(sample.reason, 'too_quiet');
    expect(sample.count, 2);
    expect(calls.last.arguments, {'timeoutMs': 4000});

    replies['enrollmentFinish'] = {'ok': true, 'count': 5, 'speaker': true};
    final done = await a.finishEnrollment();
    expect(done.ok && done.speaker, isTrue);

    replies['testListen'] = {
      'ok': true,
      'type': 'test',
      'accepted': false,
      'reason': 'speaker_mismatch',
      'keywordDistance': 0.04,
      'keywordThreshold': 0.06,
      'speakerScore': 0.2,
      'speakerThreshold': 0.55,
    };
    final t = await a.testListen();
    expect(t.accepted, isFalse);
    expect(t.reason, 'speaker_mismatch');
    expect(t.speakerScore, 0.2);
  });

  test('activations and listener events arrive typed', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (args, sink) {
          sink
            ..success({
              'type': 'activation',
              'source': 'wake',
              'verified': true,
              'locked': true,
              'at': 1000,
            })
            ..success({
              'type': 'listener',
              'state': 'paused',
              'reason': 'activation',
            })
            ..success({'type': 'unknown'});
        },
      ),
    );
    final a = android();
    final seen = <NexaAssistantEvent>[];
    final sub = a.events.listen(seen.add);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, hasLength(2));
    final act = seen.first as NexaAssistantActivation;
    expect(act.source, 'wake');
    expect(act.locked, isTrue);
    expect(act.verified, isTrue);
    expect((seen.last as NexaWakeListenerChanged).reason, 'activation');
  });

  test('the wake listener gives the microphone to the conversation', () async {
    final a = android();
    final inUse = ValueNotifier(false);
    final stop = a.followMicrophoneUse(inUse);
    inUse.value = true;
    inUse.value = false;
    stop();
    inUse.value = true; // no longer followed
    await pumpEventQueue();
    expect(calls.map((c) => c.method), ['suspendListening', 'resumeListening']);
    expect(calls.first.arguments, {'reason': 'conversation'});
  });

  test('other platforms report unsupported and call nothing', () async {
    final a = NexaAssistant(supported: false);
    expect((await a.status()).platformSupported, isFalse);
    expect(await a.setWakeEnabled(true), NexaAssistantToggle.unsupported);
    expect(await a.openAssistantSettings(), isFalse);
    expect(await a.takePendingActivation(), isNull);
    await a.events.toList();
    expect(calls, isEmpty);
  });

  group('call foreground service', () {
    test(
      'callStarted forwards the notification text and reports the result',
      () async {
        replies['callStarted'] = {'ok': false, 'reason': 'not_foreground'};
        final r = await android().callStarted(
          title: 'LABEEB call',
          endLabel: 'End call',
          conversationId: 'conv_1',
        );
        expect(r.ok, isFalse);
        expect(r.reason, 'not_foreground');
        final call = calls.singleWhere((c) => c.method == 'callStarted');
        expect(call.arguments, {
          'title': 'LABEEB call',
          'endLabel': 'End call',
          'conversationId': 'conv_1',
        });
      },
    );

    test('callEnded reaches the platform', () async {
      await android().callEnded();
      expect(calls.map((c) => c.method), contains('callEnded'));
    });

    test('other platforms report the service as unavailable', () async {
      final r = await NexaAssistant(
        supported: false,
      ).callStarted(title: 't', endLabel: 'e');
      expect(r.ok, isFalse);
      expect(r.reason, 'unsupported');
      expect(calls, isEmpty);
    });

    test('the End call action arrives as an event', () {
      final e = NexaAssistantEvent.fromMap({
        'type': 'call',
        'event': 'end_requested',
        'reason': 'notification',
      });
      expect(e, isA<NexaCallEndRequested>());
      expect((e! as NexaCallEndRequested).reason, 'notification');
    });
  });
}
