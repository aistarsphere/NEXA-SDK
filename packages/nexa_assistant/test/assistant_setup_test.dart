import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

NexaAssistantCapabilities caps({
  int sdk = 33,
  String maker = 'nubia',
  bool roleApi = true,
  bool? roleAvailable = true,
  bool? roleHeld = false,
  bool requestable = true,
  bool bound = false,
  bool defaultApps = true,
  bool voiceInput = true,
  bool mic = true,
  bool notif = true,
  bool battery = false,
  bool batteryScreen = true,
  String? oem,
  bool saver = false,
  bool secure = true,
  bool wake = false,
  String listener = 'stopped',
  String? reason,
  int? evAssist,
  int? evWake,
  int? evWakeLocked,
  int? evAssistLocked,
}) => NexaAssistantCapabilities(
  sdkInt: sdk,
  manufacturer: maker,
  roleApi: roleApi,
  roleAvailable: roleAvailable,
  roleHeld: roleHeld,
  roleRequestable: requestable,
  serviceDeclared: true,
  serviceBound: bound,
  settingsDefaultApps: defaultApps,
  settingsVoiceInput: voiceInput,
  microphonePermission: mic,
  microphoneFgsStart: sdk >= 34
      ? 'foreground_only_strict'
      : (sdk >= 30 ? 'while_in_use' : 'allowed'),
  postNotificationsRuntime: sdk >= 33,
  notificationsEnabled: notif,
  ignoringBatteryOptimizations: battery,
  batterySettingsResolvable: batteryScreen,
  oemBackgroundSettings: oem,
  powerSaveMode: saver,
  keyguardSupportDeclared: true,
  deviceSecure: secure,
  wakeEnabled: wake,
  listenerState: listener,
  listenerReason: reason,
  evidenceAssistAt: evAssist,
  evidenceWakeAt: evWake,
  evidenceWakeLockedAt: evWakeLocked,
  evidenceAssistLockedAt: evAssistLocked,
);

NexaSetupStep step(List<NexaSetupStep> s, NexaStepId id) =>
    s.firstWhere((e) => e.id == id);

List<NexaSetupStep> list(NexaAssistantCapabilities c, {bool model = true}) =>
    buildAssistantChecklist(c, hasWakeModel: model);

void main() {
  group('microphone and notifications come from the system', () {
    test('a revoked microphone permission is a to-do again', () {
      var s = list(caps(mic: true));
      expect(step(s, NexaStepId.microphone).state, NexaStepState.verified);
      s = list(caps(mic: false));
      final m = step(s, NexaStepId.microphone);
      expect(m.state, NexaStepState.todo);
      expect(m.action, NexaStepAction.requestMicrophone);
      expect(m.fallback, NexaStepAction.openAppDetails);
    });

    test(
      'Android 13+ asks for the notification permission; older opens settings',
      () {
        final n13 = step(
          list(caps(sdk: 33, notif: false)),
          NexaStepId.notifications,
        );
        expect(n13.action, NexaStepAction.requestNotifications);
        final n12 = step(
          list(caps(sdk: 31, notif: false)),
          NexaStepId.notifications,
        );
        expect(n12.action, NexaStepAction.openNotifications);
      },
    );
  });

  group('default assistant', () {
    NexaSetupStep da(NexaAssistantCapabilities c) =>
        step(list(c), NexaStepId.defaultAssistant);

    test('not held: the assistant picker screen, never a role request', () {
      final s = da(caps());
      expect(s.state, NexaStepState.todo);
      expect(s.action, NexaStepAction.openVoiceInput);
      expect(s.fallback, NexaStepAction.openDefaultApps);
      expect(s.note, 'choose_digital_assistant');
      expect(da(caps(requestable: true)).action, NexaStepAction.openVoiceInput);
    });

    test('held and bound but never invoked: configured, offer the test', () {
      final s = da(caps(roleHeld: true, bound: true));
      expect(s.state, NexaStepState.configuredNotTested);
      expect(s.action, NexaStepAction.testAssist);
    });

    test('verified only after an invocation was observed', () {
      final s = da(caps(roleHeld: true, bound: true, evAssist: 1730000000000));
      expect(s.state, NexaStepState.verified);
    });

    test('losing the role (another assistant chosen) goes back to a to-do', () {
      expect(
        da(caps(roleHeld: true, bound: true, evAssist: 1)).state,
        NexaStepState.verified,
      );
      expect(
        da(caps(roleHeld: false, bound: false, evAssist: 1)).state,
        NexaStepState.todo,
      );
    });

    test(
      'no role on this build: unsupported, with the settings route only if it exists',
      () {
        final s = da(caps(roleAvailable: false));
        expect(s.state, NexaStepState.unsupported);
        expect(s.action, NexaStepAction.openDefaultApps);
        expect(
          da(caps(roleAvailable: false, defaultApps: false)).action,
          NexaStepAction.none,
        );
      },
    );

    test(
      'no voice-input screen on this phone: the default-apps list instead',
      () {
        final s = da(caps(voiceInput: false));
        expect(s.action, NexaStepAction.openDefaultApps);
        expect(s.fallback, NexaStepAction.none);
      },
    );

    test('nothing resolvable at all: blocked, never a fake button', () {
      final s = da(caps(voiceInput: false, defaultApps: false));
      expect(s.state, NexaStepState.blocked);
      expect(s.action, NexaStepAction.none);
    });

    test('Android 9 and older: no role to read, so it is never "done"', () {
      final s = da(
        caps(sdk: 28, roleApi: false, roleAvailable: null, roleHeld: null),
      );
      expect(s.state, NexaStepState.todo);
      expect(s.note, 'cannot_verify_role');
    });
  });

  group('wake listening', () {
    NexaSetupStep wk(NexaAssistantCapabilities c, {bool model = true}) =>
        step(list(c, model: model), NexaStepId.wakeListening);

    test(
      'without an installed acoustic model it is unsupported, not faked',
      () {
        expect(wk(caps(), model: false).state, NexaStepState.unsupported);
      },
    );

    test('needs microphone and notifications first', () {
      expect(wk(caps(mic: false)).state, NexaStepState.todo);
      expect(wk(caps(notif: false)).note, 'needs_microphone_and_notification');
    });

    test('running but never detected a phrase: configured, not tested', () {
      final s = wk(caps(wake: true, listener: 'running'));
      expect(s.state, NexaStepState.configuredNotTested);
    });

    test('verified after a real wake', () {
      expect(
        wk(caps(wake: true, listener: 'running', evWake: 5)).state,
        NexaStepState.verified,
      );
    });

    test('blocked when Android refuses the background start', () {
      final s = wk(
        caps(
          wake: true,
          listener: 'stopped',
          reason: 'background_start_blocked',
        ),
      );
      expect(s.state, NexaStepState.blocked);
    });

    test('enabled but not running after a restart says so', () {
      final s = wk(caps(wake: true, listener: 'stopped'));
      expect(s.state, NexaStepState.todo);
      expect(s.note, 'enabled_but_not_running');
    });
  });

  group('recommendations only where they can matter', () {
    test(
      'battery saver on is blocked; optimisation list opens only if resolvable',
      () {
        final s = list(caps(saver: true));
        expect(step(s, NexaStepId.battery).state, NexaStepState.blocked);
        final noScreen = list(caps(batteryScreen: false));
        expect(
          step(noScreen, NexaStepId.battery).action,
          NexaStepAction.openAppDetails,
        );
      },
    );

    test('a vendor screen is offered only when this device can open it', () {
      final withScreen = list(caps(maker: 'xiaomi', oem: 'oem_xiaomi'));
      expect(
        step(withScreen, NexaStepId.oemBackground).action,
        NexaStepAction.openOemBackground,
      );
      final manual = list(caps(maker: 'nubia'));
      final m = step(manual, NexaStepId.oemBackground);
      expect(m.note, 'oem_manual');
      expect(
        m.state,
        NexaStepState.configuredNotTested,
        reason: 'cannot be verified',
      );
      // A phone from a vendor without known restrictions shows no such step.
      expect(
        list(
          caps(maker: 'google'),
        ).any((e) => e.id == NexaStepId.oemBackground),
        isFalse,
      );
    });

    test('no required step is the battery or vendor screen', () {
      final s = list(caps(maker: 'xiaomi', oem: 'oem_xiaomi'));
      expect(step(s, NexaStepId.battery).required, isFalse);
      expect(step(s, NexaStepId.oemBackground).required, isFalse);
    });
  });

  group('lock screen', () {
    NexaSetupStep lk(NexaAssistantCapabilities c) =>
        step(list(c), NexaStepId.lockScreen);

    test('nothing set up: needs the assistant or listening first', () {
      expect(lk(caps()).state, NexaStepState.todo);
    });

    test('verified only by a wake that happened while locked', () {
      expect(lk(caps(roleHeld: true)).state, NexaStepState.configuredNotTested);
      expect(lk(caps(roleHeld: true)).action, NexaStepAction.testLock);
      expect(
        lk(caps(wake: true, listener: 'running', evWake: 9)).state,
        NexaStepState.configuredNotTested,
        reason: 'a wake with the screen on proves nothing about locked',
      );
      expect(lk(caps(evWakeLocked: 9)).state, NexaStepState.verified);
      // The assist gesture reaching AMEER while locked verifies the step, but
      // says so: it is not proof that the wake phrase works while locked.
      final viaAssist = lk(caps(roleHeld: true, evAssistLocked: 9));
      expect(viaAssist.state, NexaStepState.verified);
      expect(viaAssist.note, 'verified_via_assist_only');
    });

    test('Android 14 says the listener must be restarted with AMEER open', () {
      expect(
        lk(caps(sdk: 34, roleHeld: true)).note,
        'android14_reopen_after_restart',
      );
      expect(lk(caps(sdk: 33, roleHeld: true)).note, '');
    });

    test('without a screen lock the note says anyone can use it', () {
      expect(lk(caps(roleHeld: true, secure: false)).note, 'no_screen_lock');
    });
  });

  group('overall', () {
    test('ready only when every required step is verified', () {
      final all = caps(
        roleHeld: true,
        bound: true,
        evAssist: 1,
        wake: true,
        listener: 'running',
        evWake: 1,
        battery: true,
      );
      expect(overallOf(list(all)), NexaSetupOverall.ready);
      expect(overallOf(list(caps())), NexaSetupOverall.partial);
      expect(
        overallOf(list(caps(wake: true, reason: 'background_start_blocked'))),
        NexaSetupOverall.blocked,
      );
    });
  });

  test('capabilities are parsed from the plugin map', () {
    final c = NexaAssistantCapabilities.fromMap({
      'sdkInt': 33,
      'manufacturer': 'nubia',
      'roleApi': true,
      'roleAvailable': true,
      'roleHeld': false,
      'roleRequestable': true,
      'evidenceAssistAt': 123,
    });
    expect(c.sdkInt, 33);
    expect(c.roleHeld, isFalse);
    expect(c.restrictiveOem, isTrue);
    expect(c.evidenceAssistAt, 123);
    expect(c.evidenceWakeAt, isNull);
  });
}
