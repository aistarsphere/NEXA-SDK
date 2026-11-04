// The setup wizard: states come from Android on every resume, the role is
// requested with the official API and re-read afterwards, missing settings
// screens are reported instead of launched blind.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/setup/assistant_setup_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('nexa_assistant/methods');
  const events = EventChannel('nexa_assistant/events');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late Map<String, Object?> caps;
  late Object? Function(MethodCall) onCall;

  Map<String, Object?> base() => {
    'sdkInt': 33,
    'manufacturer': 'nubia',
    'model': 'NX679J',
    'roleApi': true,
    'roleAvailable': true,
    'roleHeld': false,
    'roleRequestable': true,
    'serviceDeclared': true,
    'serviceBound': false,
    'settingsDefaultApps': true,
    'settingsVoiceInput': true,
    'microphonePermission': true,
    'postNotificationsRuntime': true,
    'notificationsEnabled': true,
    'batterySettingsResolvable': true,
    'keyguardSupportDeclared': true,
    'deviceSecure': true,
    'listenerState': 'stopped',
  };

  setUp(() {
    calls = [];
    caps = base();
    onCall = (c) => null;
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'capabilities':
          return Map<String, Object?>.of(caps);
        case 'status':
          return {
            'platformSupported': true,
            'wakePhrases': [
              {'id': 'yaameer', 'label': 'يا أمير', 'installed': true},
            ],
          };
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
    tester.view.physicalSize = const Size(1080, 7000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: AssistantSetupPage(plugin: NexaAssistant(supported: true)),
      ),
    );
    await tester.pumpAndSettle();
  }

  String state(WidgetTester tester, String id) =>
      tester.widget<Text>(find.byKey(Key('assistant_step_state_$id'))).data!;

  testWidgets('shows the real device and a checklist from its facts', (
    tester,
  ) async {
    await open(tester);
    expect(find.textContaining('nubia NX679J'), findsOneWidget);
    expect(find.textContaining('Android 13'), findsOneWidget);
    expect(state(tester, 'microphone'), 'Verified');
    expect(state(tester, 'defaultAssistant'), 'To do');
    // Nothing is claimed as verified without evidence.
    expect(state(tester, 'lockScreen'), isNot('Verified'));
  });

  testWidgets('coming back from Android Settings re-reads the system, it does '
      'not assume', (tester) async {
    await open(tester);
    expect(state(tester, 'defaultAssistant'), 'To do');
    final before = calls.where((c) => c.method == 'capabilities').length;

    // The person changed it in Settings; only the system knows.
    caps = {...base(), 'roleHeld': true, 'serviceBound': true};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(
      calls.where((c) => c.method == 'capabilities').length,
      greaterThan(before),
    );
    expect(
      state(tester, 'defaultAssistant'),
      'Set, not tested',
      reason: 'held and bound, but no invocation was observed yet',
    );

    caps = {...caps, 'evidenceAssistAt': 1730000000000};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(state(tester, 'defaultAssistant'), 'Verified');

    // Another assistant is chosen later: back to a to-do.
    caps = {...base(), 'roleHeld': false};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(state(tester, 'defaultAssistant'), 'To do');
  });

  testWidgets('a revoked permission shows up on return', (tester) async {
    await open(tester);
    expect(state(tester, 'microphone'), 'Verified');
    caps = {...base(), 'microphonePermission': false};
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(state(tester, 'microphone'), 'To do');
  });

  testWidgets('the assistant picker is opened, and the answer is read from '
      'Android when the person comes back (never assumed)', (tester) async {
    onCall = (c) {
      if (c.method == 'openSetting') {
        // The person picks AMEER in Android's own screen while we are away.
        caps = {...base(), 'roleHeld': true, 'serviceBound': true};
        return 'opened';
      }
      return null;
    };
    await open(tester);
    expect(find.text('Choose assistant app'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('assistant_step_action_defaultAssistant')),
    );
    await tester.pumpAndSettle();
    final open_ = calls.firstWhere((c) => c.method == 'openSetting');
    expect(open_.arguments, {'id': 'voice_input'});
    expect(calls.map((c) => c.method), isNot(contains('requestAssistantRole')));
    expect(state(tester, 'defaultAssistant'), 'Set, not tested');
  });

  testWidgets('a screen the phone cannot open is reported, with the fallback '
      'still available', (tester) async {
    onCall = (c) => c.method == 'openSetting' ? 'not_resolvable' : null;
    await open(tester);
    await tester.tap(
      find.byKey(const Key('assistant_step_action_defaultAssistant')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot open that screen'), findsWidgets);
    expect(
      find.byKey(const Key('assistant_step_fallback_defaultAssistant')),
      findsOneWidget,
    );
  });

  testWidgets('no settings destination: no fake button, only the explanation', (
    tester,
  ) async {
    caps = {
      ...base(),
      'settingsVoiceInput': false,
      'settingsDefaultApps': false,
    };
    await open(tester);
    expect(state(tester, 'defaultAssistant'), 'Blocked');
    expect(
      find.byKey(const Key('assistant_step_action_defaultAssistant')),
      findsNothing,
    );
    expect(find.textContaining('by hand'), findsOneWidget);
  });

  testWidgets(
    'Android 14 explains that listening restarts only with AMEER open',
    (tester) async {
      caps = {
        ...base(),
        'sdkInt': 34,
        'microphoneFgsStart': 'foreground_only_strict',
        'roleHeld': true,
      };
      await open(tester);
      expect(find.textContaining('Android 14+'), findsOneWidget);
    },
  );

  testWidgets('a phone-maker screen is offered only when the device has it', (
    tester,
  ) async {
    await open(tester);
    // Nubia: no resolvable vendor screen -> manual instructions, no launch button.
    expect(
      find.byKey(const Key('assistant_step_note_oemBackground')),
      findsOneWidget,
    );
    expect(
      find.text('Open phone-maker screen'),
      findsNothing,
      reason: 'no vendor screen to open',
    );
    expect(find.text('Open app settings'), findsWidgets);
    caps = {
      ...base(),
      'manufacturer': 'Xiaomi',
      'oemBackgroundSettings': 'oem_xiaomi',
    };
    await tester.tap(find.byKey(const Key('assistant_setup_refresh')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('assistant_step_action_oemBackground')),
      findsOneWidget,
    );
  });
}
