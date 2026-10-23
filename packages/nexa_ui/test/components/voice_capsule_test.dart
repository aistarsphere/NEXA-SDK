import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

import '../helpers.dart';

VoiceTranscriptEntry line(VoiceSpeaker s, String t, {bool isFinal = true}) =>
    VoiceTranscriptEntry(
      speaker: s,
      text: t,
      isFinal: isFinal,
      at: DateTime(2026),
    );

void main() {
  Widget capsule({
    VoiceState state = VoiceState.idle,
    bool muted = false,
    bool agentPresent = true,
    bool eventsVerified = true,
    NexaException? error,
    List<VoiceTranscriptEntry> transcript = const [],
    VoidCallback? onStart,
    VoidCallback? onEnd,
    VoidCallback? onToggleMute,
    VoidCallback? onRetry,
    VoidCallback? onOpenSettings,
    Locale locale = const Locale('en'),
    bool reducedMotion = false,
  }) => harness(
    SizedBox(
      width: 360,
      height: 640,
      child: NexaVoiceCapsule(
        state: state,
        transcript: transcript,
        muted: muted,
        agentPresent: agentPresent,
        eventsVerified: eventsVerified,
        error: error,
        onStart: onStart,
        onEnd: onEnd,
        onToggleMute: onToggleMute,
        onRetry: onRetry,
        onOpenSettings: onOpenSettings,
      ),
    ),
    locale: locale,
    reducedMotion: reducedMotion,
  );

  group('NexaVoiceCapsule', () {
    testWidgets('idle shows Start; in-call shows mute + end', (tester) async {
      var started = 0;
      await tester.pumpWidget(capsule(onStart: () => started++));
      await tester.tap(find.byKey(const Key('nexa_voice_start')));
      expect(started, 1);
      expect(find.byKey(const Key('nexa_voice_mute')), findsNothing);

      var ended = 0;
      var muted = 0;
      await tester.pumpWidget(
        capsule(
          state: VoiceState.listening,
          onEnd: () => ended++,
          onToggleMute: () => muted++,
        ),
      );
      await tester.tap(find.byKey(const Key('nexa_voice_mute')));
      await tester.tap(find.byKey(const Key('nexa_voice_end')));
      expect((muted, ended), (1, 1));
      expect(find.byKey(const Key('nexa_voice_start')), findsNothing);
    });

    testWidgets('every state has a localised label in en and ar', (
      tester,
    ) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        for (final state in VoiceState.values) {
          await tester.pumpWidget(capsule(state: state, locale: locale));
          final label = tester.widget<Text>(
            find.byKey(const Key('nexa_voice_state_label')),
          );
          expect(label.data, isNotEmpty, reason: '$locale $state');
          expect(tester.takeException(), isNull);
        }
      }
    });

    testWidgets('mute is disabled while connecting/reconnecting', (
      tester,
    ) async {
      await tester.pumpWidget(
        capsule(state: VoiceState.connecting, onToggleMute: () {}),
      );
      final btn = tester.widget<IconButton>(
        find.byKey(const Key('nexa_voice_mute')),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets(
      'microphone denied offers Open settings; other errors offer retry',
      (tester) async {
        var opened = 0;
        await tester.pumpWidget(
          capsule(
            state: VoiceState.microphoneDenied,
            error: const PermissionDeniedException('microphone'),
            onOpenSettings: () => opened++,
            onRetry: () {},
          ),
        );
        await tester.tap(find.text('Open settings'));
        expect(opened, 1);

        var retried = 0;
        await tester.pumpWidget(
          capsule(
            state: VoiceState.disconnected,
            error: const NetworkException(
              NexaErrorCode.networkUnreachable,
              'x',
            ),
            onRetry: () => retried++,
          ),
        );
        await tester.tap(find.text('Try again'));
        expect(retried, 1);
        expect(
          find.byKey(const Key('nexa_voice_error_banner')),
          findsOneWidget,
        );
      },
    );

    testWidgets('unverified banner only during an active call', (tester) async {
      await tester.pumpWidget(
        capsule(state: VoiceState.listening, eventsVerified: false),
      );
      expect(
        find.byKey(const Key('nexa_voice_unverified_banner')),
        findsOneWidget,
      );
      await tester.pumpWidget(
        capsule(state: VoiceState.idle, eventsVerified: false),
      );
      expect(
        find.byKey(const Key('nexa_voice_unverified_banner')),
        findsNothing,
      );
    });

    testWidgets(
      'waiting-for-agent hint and transcript bubbles, RTL in Arabic',
      (tester) async {
        await tester.pumpWidget(
          capsule(
            state: VoiceState.listening,
            agentPresent: false,
            transcript: [
              line(VoiceSpeaker.user, 'مرحبا'),
              line(VoiceSpeaker.assistant, 'أهلاً', isFinal: false),
            ],
            locale: const Locale('ar'),
          ),
        );
        expect(
          find.byKey(const Key('nexa_voice_agent_waiting')),
          findsOneWidget,
        );
        expect(find.text('مرحبا'), findsOneWidget);
        expect(
          Directionality.of(
            tester.element(find.byKey(const Key('nexa_voice_transcript'))),
          ),
          TextDirection.rtl,
        );
        final partial = tester.widget<Text>(find.text('أهلاً'));
        expect(partial.style?.fontStyle, FontStyle.italic);
      },
    );

    testWidgets('orb pulses while speaking, static under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(capsule(state: VoiceState.aiSpeaking));
      await tester.pump(const Duration(milliseconds: 500));
      final ring = find.byType(Transform).first;
      final scaleA = tester.widget<Transform>(ring).transform.storage[0];
      await tester.pump(const Duration(milliseconds: 500));
      final scaleB = tester.widget<Transform>(ring).transform.storage[0];
      expect(scaleA, isNot(equals(scaleB)), reason: 'animating');

      await tester.pumpWidget(
        capsule(state: VoiceState.aiSpeaking, reducedMotion: true),
      );
      await tester.pump(const Duration(milliseconds: 500));
      final s1 = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .storage[0];
      await tester.pump(const Duration(milliseconds: 500));
      final s2 = tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .storage[0];
      expect(s1, 1.0);
      expect(s2, 1.0);
    });

    testWidgets('semantics: orb label, mute/end labels, live state region', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        capsule(state: VoiceState.listening, onEnd: () {}, onToggleMute: () {}),
      );
      expect(
        find.bySemanticsLabel(RegExp('Voice status: Listening')),
        findsOneWidget,
      );
      expect(find.byTooltip('Mute microphone'), findsOneWidget);
      expect(find.byTooltip('End voice call'), findsOneWidget);
      final label = tester.getSemantics(
        find.byKey(const Key('nexa_voice_state_label')),
      );
      expect(label.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });
  });
}
