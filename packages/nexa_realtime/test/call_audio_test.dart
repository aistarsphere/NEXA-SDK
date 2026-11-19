import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_realtime/nexa_realtime.dart';

final class _FakePlatform implements NexaCallAudioPlatform {
  Map<String, Object?> facts = {
    'platform': 'android',
    'osVersion': 'Android 13 (API 33)',
    'model': 'Test Phone',
    'mode': 'in_communication',
    'route': 'speaker',
    'phoneCall': false,
    'bluetoothPresent': false,
    'bluetoothPermissionNeeded': false,
  };
  int reasserts = 0;

  @override
  Future<Map<String, Object?>?> state() async => Map.of(facts);

  @override
  Future<String?> reassertCommunicationMode() async {
    reasserts++;
    facts['mode'] = 'in_communication';
    return 'in_communication';
  }
}

void main() {
  late _FakePlatform platform;
  late List<bool> speaker;
  late NexaCallAudio audio;

  setUp(() {
    platform = _FakePlatform();
    speaker = [];
    audio = NexaCallAudio(
      platform: platform,
      setSpeaker: (on) async => speaker.add(on),
      readProcessing: () async => {'aec': 'platform'},
      pollInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => audio.dispose());

  test('a call starts on the loudspeaker and reads the real state', () async {
    await audio.beginCall();
    await audio.afterConnect();
    final s = audio.state.value;
    expect(speaker.first, isTrue);
    expect(s.active, isTrue);
    expect(s.route, NexaAudioRoute.speaker);
    expect(s.mode, 'in_communication');
    expect(s.model, 'Test Phone');
    expect(s.processing['aec'], 'platform');
  });

  test(
    'the earpiece choice survives a reconnect and resets per call',
    () async {
      await audio.beginCall();
      await audio.setSpeakerPreferred(false);
      await audio.afterConnect(); // rejoin: a new room
      expect(speaker.last, isFalse);
      expect(audio.state.value.speakerPreferred, isFalse);
      await audio.endCall();
      await audio.beginCall();
      expect(audio.state.value.speakerPreferred, isTrue);
      expect(speaker.last, isTrue);
    },
  );

  test('iOS reports the mode requested for the choice', () async {
    final ios = NexaCallAudio(
      platform: platform,
      setSpeaker: (_) async {},
      readProcessing: () async => const {},
      pollInterval: const Duration(hours: 1),
      targetPlatform: TargetPlatform.iOS,
    );
    await ios.beginCall();
    expect(ios.state.value.requestedMode, 'videoChat');
    await ios.setSpeakerPreferred(false);
    expect(ios.state.value.requestedMode, 'voiceChat');
    await ios.dispose();
  });

  test('phone call start and end are reported once each; recovery '
      'reasserts the communication mode and the choice', () async {
    final calls = <bool>[];
    final sub = audio.phoneCallChanges.listen(calls.add);
    await audio.beginCall();
    await audio.setSpeakerPreferred(false);
    platform.facts
      ..['phoneCall'] = true
      ..['mode'] = 'in_call';
    await audio.refresh();
    await audio.refresh();
    platform.facts
      ..['phoneCall'] = false
      ..['mode'] = 'normal';
    await audio.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(calls, [true, false]);
    await audio.recoverAfterPhoneCall();
    expect(platform.reasserts, 1);
    expect(audio.state.value.mode, 'in_communication');
    expect(speaker.last, isFalse);
    await sub.cancel();
  });

  test('a headset connecting is shown as the route', () async {
    await audio.beginCall();
    final changes = <void>[];
    final sub = audio.changes.listen(changes.add);
    platform.facts['route'] = 'bluetooth';
    await audio.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(audio.state.value.route, NexaAudioRoute.bluetooth);
    expect(audio.state.value.headset, isTrue);
    expect(changes, hasLength(1));
    await sub.cancel();
  });

  test('without the native plugin nothing throws', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final real = NexaCallAudio(
      setSpeaker: (_) async {},
      readProcessing: () async => const {},
      pollInterval: const Duration(hours: 1),
    );
    await real.beginCall();
    await real.afterConnect();
    await real.recoverAfterPhoneCall();
    expect(real.state.value.route, NexaAudioRoute.unknown);
    await real.endCall();
    await real.dispose();
  });
}
