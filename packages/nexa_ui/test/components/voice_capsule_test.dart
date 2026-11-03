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
    bool interruptConfirmed = false,
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
        interruptConfirmed: interruptConfirmed,
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

  group('error banners say what happened', () {
    testWidgets('a rate limit is named, not "something went wrong"', (
      tester,
    ) async {
      await tester.pumpWidget(
        capsule(
          state: VoiceState.disconnected,
          error: const RateLimitedException(),
          onRetry: () {},
        ),
      );
      expect(
        find.text('Too many requests. Please wait a moment.'),
        findsOneWidget,
      );
      expect(
        find.text('Something went wrong. Please try again.'),
        findsNothing,
      );
    });

    testWidgets('the same in Arabic', (tester) async {
      await tester.pumpWidget(
        capsule(
          state: VoiceState.disconnected,
          error: const RateLimitedException(),
          locale: const Locale('ar'),
          onRetry: () {},
        ),
      );
      expect(find.text('something went wrong'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('nexa_voice_error_banner')),
          matching: find.textContaining('طلبات'),
        ),
        findsOneWidget,
      );
    });
  });

  group('connection trouble uses one banner', () {
    testWidgets('weak network and reconnecting both show it', (tester) async {
      await tester.pumpWidget(capsule(state: VoiceState.weakNetwork));
      expect(
        find.byKey(const Key('nexa_voice_connection_banner')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('nexa_voice_connection_banner')),
          matching: find.text('Audio may be delayed. Captions stay on.'),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(capsule(state: VoiceState.reconnecting));
      expect(
        find.byKey(const Key('nexa_voice_connection_banner')),
        findsOneWidget,
      );
      expect(find.text('Nothing is lost while we reconnect'), findsWidgets);
    });

    testWidgets('a healthy call shows none', (tester) async {
      await tester.pumpWidget(capsule(state: VoiceState.listening));
      expect(
        find.byKey(const Key('nexa_voice_connection_banner')),
        findsNothing,
      );
    });
  });

  group('barge-in labels are honest', () {
    testWidgets('before the agent confirms: "Listening to you", never '
        '"Interrupting"', (tester) async {
      await tester.pumpWidget(capsule(state: VoiceState.bargeIn));
      expect(find.text('Listening to you…'), findsOneWidget);
      expect(find.text('Interrupting…'), findsNothing);
    });

    testWidgets('after the agent confirmed the interruption', (tester) async {
      await tester.pumpWidget(
        capsule(state: VoiceState.userSpeaking, interruptConfirmed: true),
      );
      expect(find.text('Interrupted'), findsOneWidget);
    });

    testWidgets('the user speaking without an interruption is unchanged', (
      tester,
    ) async {
      await tester.pumpWidget(capsule(state: VoiceState.userSpeaking));
      expect(find.text('Interrupted'), findsNothing);
    });

    testWidgets('Arabic labels', (tester) async {
      await tester.pumpWidget(
        capsule(state: VoiceState.bargeIn, locale: const Locale('ar')),
      );
      expect(find.text('أستمع إليك…'), findsOneWidget);
    });
  });

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

    testWidgets(
      'capsule bars move while speaking, still under reduced motion',
      (tester) async {
        double barHeight() => tester
            .getSize(
              find
                  .descendant(
                    of: find.byKey(const Key('nexa_voice_pill')),
                    matching: find.byType(AnimatedContainer),
                  )
                  .at(2),
            )
            .height;

        await tester.pumpWidget(capsule(state: VoiceState.aiSpeaking));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 130));
        final a = barHeight();
        await tester.pump(const Duration(milliseconds: 170));
        final b = barHeight();
        expect(a, isNot(equals(b)), reason: 'animating');

        await tester.pumpWidget(
          capsule(state: VoiceState.aiSpeaking, reducedMotion: true),
        );
        await tester.pump(const Duration(milliseconds: 600));
        final s1 = barHeight();
        await tester.pump(const Duration(milliseconds: 170));
        expect(barHeight(), s1);
      },
    );

    testWidgets('capsule width follows the state', (tester) async {
      double width() =>
          tester.getSize(find.byKey(const Key('nexa_voice_pill'))).width;
      await tester.pumpWidget(capsule(state: VoiceState.listening));
      await tester.pumpAndSettle();
      final listening = width();
      await tester.pumpWidget(capsule(state: VoiceState.userSpeaking));
      await tester.pump(const Duration(seconds: 1));
      expect(width(), greaterThan(listening));
    });

    testWidgets('captions can be hidden and shown', (tester) async {
      await tester.pumpWidget(
        capsule(
          state: VoiceState.listening,
          transcript: [line(VoiceSpeaker.user, 'hello')],
        ),
      );
      expect(find.text('hello'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nexa_voice_captions')));
      await tester.pump();
      expect(find.text('hello'), findsNothing);
      expect(find.text('Captions are hidden'), findsOneWidget);
    });

    testWidgets('English caption keeps LTR inside the Arabic UI', (
      tester,
    ) async {
      await tester.pumpWidget(
        capsule(
          state: VoiceState.listening,
          transcript: [line(VoiceSpeaker.assistant, 'Hello there.')],
          locale: const Locale('ar'),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Hello there.')).textDirection,
        TextDirection.ltr,
      );
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
    testWidgets(
      'voice unavailable (503 / agent_lost) shows try-again, en + ar',
      (tester) async {
        for (final code in ['voice_unavailable', 'agent_lost']) {
          var retried = 0;
          await tester.pumpWidget(
            capsule(
              state: VoiceState.disconnected,
              error: ServerException(
                statusCode: 503,
                serverCode: code,
                message: 'x',
                retryable: true,
              ),
              onRetry: () => retried++,
            ),
          );
          expect(
            find.text(
              "Voice isn't available right now. Try again in a moment.",
            ),
            findsOneWidget,
            reason: code,
          );
          await tester.tap(find.text('Try again'));
          expect(retried, 1);
        }
        await tester.pumpWidget(
          capsule(
            state: VoiceState.disconnected,
            error: const ServerException(
              statusCode: 0,
              serverCode: 'agent_lost',
              message: 'x',
            ),
            locale: const Locale('ar'),
          ),
        );
        expect(find.text('الصوت مو متوفر هسه. جرّب بعد شوية.'), findsOneWidget);
      },
    );

    testWidgets('other server errors keep the generic message', (tester) async {
      await tester.pumpWidget(
        capsule(
          state: VoiceState.disconnected,
          error: const ServerException(
            statusCode: 409,
            serverCode: 'voice_session_active',
            message: 'x',
          ),
        ),
      );
      expect(find.textContaining('Something went wrong'), findsOneWidget);
    });
  });
}
