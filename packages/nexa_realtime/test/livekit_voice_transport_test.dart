// The LiveKit engine needs a platform WebRTC implementation, so a real room
// join is exercised on a simulator (apps/nexa_example/integration_test).
// These tests cover the transport's guards that run before the engine.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_realtime/nexa_realtime.dart';

VoiceGrant grant({Duration ttl = const Duration(minutes: 5)}) => VoiceGrant(
  voiceSessionId: 'vs',
  liveKitUrl: Uri.parse('ws://127.0.0.1:1'),
  participantToken: 't',
  roomName: 'r',
  participantIdentity: 'u',
  expiresAt: DateTime.now().add(ttl),
);

void main() {
  group('LiveKitVoiceTransport guards', () {
    test('refuses an expired grant before touching the engine', () async {
      var roomsCreated = 0;
      final t = LiveKitVoiceTransport(
        logger: const NoopNexaLogger(),
        roomFactory: () {
          roomsCreated++;
          throw StateError('must not be called');
        },
      );
      await expectLater(
        t.connect(grant(ttl: -const Duration(seconds: 1))),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(roomsCreated, 0);
      expect(t.isMicrophoneEnabled, isFalse);
      await t.dispose();
    });

    test('microphone toggle without a room is a transport error', () async {
      final t = LiveKitVoiceTransport(logger: const NoopNexaLogger());
      await expectLater(
        t.setMicrophoneEnabled(enabled: true),
        throwsA(isA<TransportException>()),
      );
      await t.disconnect(); // no-op when not connected
      await t.dispose();
      await t.dispose(); // idempotent
      expect(() => t.interrupt(), throwsA(isA<NotInitializedException>()));
    });

    test('audio setup is voice-only (no video, speech capture options)', () {
      final options = LiveKitAudioSetup.roomOptions();
      expect(options.adaptiveStream, isFalse);
      expect(options.dynacast, isFalse);
      expect(options.defaultAudioCaptureOptions.echoCancellation, isTrue);
      expect(options.defaultAudioCaptureOptions.noiseSuppression, isTrue);
      expect(options.defaultAudioOutputOptions.speakerOn, isTrue);
    });
  });
}
