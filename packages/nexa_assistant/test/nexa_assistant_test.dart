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
}
