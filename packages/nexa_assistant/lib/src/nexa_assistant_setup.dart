/// Capability-driven assistant setup: facts read from Android, and the
/// checklist derived from them. Nothing is "done" because the user returned
/// from a settings screen; every state comes from the system or from evidence
/// that something really happened on this device.
library;

/// What this device reports (read from Android on every call).
final class NexaAssistantCapabilities {
  const NexaAssistantCapabilities({
    this.sdkInt = 0,
    this.manufacturer = '',
    this.model = '',
    this.roleApi = false,
    this.roleAvailable,
    this.roleHeld,
    this.roleRequestable = false,
    this.serviceDeclared = false,
    this.serviceBound = false,
    this.settingsDefaultApps = false,
    this.settingsVoiceInput = false,
    this.microphonePermission = false,
    this.microphoneFgsStart = 'allowed',
    this.postNotificationsRuntime = false,
    this.notificationsEnabled = false,
    this.ignoringBatteryOptimizations = false,
    this.batterySettingsResolvable = false,
    this.oemBackgroundSettings,
    this.powerSaveMode = false,
    this.keyguardSupportDeclared = false,
    this.deviceSecure = false,
    this.keyguardLocked = false,
    this.wakeEnabled = false,
    this.listenerState = 'stopped',
    this.listenerReason,
    this.hotwordHardware = 'unavailable',
    this.evidenceAssistAt,
    this.evidenceWakeAt,
    this.evidenceWakeLockedAt,
    this.evidenceRoleSeenAt,
  });

  factory NexaAssistantCapabilities.fromMap(Map<Object?, Object?> m) {
    int? ms(String k) => (m[k] as num?)?.toInt();
    return NexaAssistantCapabilities(
      sdkInt: ms('sdkInt') ?? 0,
      manufacturer: m['manufacturer'] as String? ?? '',
      model: m['model'] as String? ?? '',
      roleApi: m['roleApi'] == true,
      roleAvailable: m['roleAvailable'] as bool?,
      roleHeld: m['roleHeld'] as bool?,
      roleRequestable: m['roleRequestable'] == true,
      serviceDeclared: m['serviceDeclared'] == true,
      serviceBound: m['serviceBound'] == true,
      settingsDefaultApps: m['settingsDefaultApps'] == true,
      settingsVoiceInput: m['settingsVoiceInput'] == true,
      microphonePermission: m['microphonePermission'] == true,
      microphoneFgsStart: m['microphoneFgsStart'] as String? ?? 'allowed',
      postNotificationsRuntime: m['postNotificationsRuntime'] == true,
      notificationsEnabled: m['notificationsEnabled'] == true,
      ignoringBatteryOptimizations: m['ignoringBatteryOptimizations'] == true,
      batterySettingsResolvable: m['batterySettingsResolvable'] == true,
      oemBackgroundSettings: m['oemBackgroundSettings'] as String?,
      powerSaveMode: m['powerSaveMode'] == true,
      keyguardSupportDeclared: m['keyguardSupportDeclared'] == true,
      deviceSecure: m['deviceSecure'] == true,
      keyguardLocked: m['keyguardLocked'] == true,
      wakeEnabled: m['wakeEnabled'] == true,
      listenerState: m['listenerState'] as String? ?? 'stopped',
      listenerReason: m['listenerReason'] as String?,
      hotwordHardware: m['hotwordHardware'] as String? ?? 'unavailable',
      evidenceAssistAt: ms('evidenceAssistAt'),
      evidenceWakeAt: ms('evidenceWakeAt'),
      evidenceWakeLockedAt: ms('evidenceWakeLockedAt'),
      evidenceRoleSeenAt: ms('evidenceRoleSeenAt'),
    );
  }

  final int sdkInt;
  final String manufacturer;
  final String model;
  final bool roleApi;

  /// Null when Android would not tell.
  final bool? roleAvailable;
  final bool? roleHeld;
  final bool roleRequestable;
  final bool serviceDeclared;
  final bool serviceBound;
  final bool settingsDefaultApps;
  final bool settingsVoiceInput;
  final bool microphonePermission;

  /// `allowed` (Android 10 and older), `while_in_use` (11-13), `foreground_only_strict` (14+).
  final String microphoneFgsStart;
  final bool postNotificationsRuntime;
  final bool notificationsEnabled;
  final bool ignoringBatteryOptimizations;
  final bool batterySettingsResolvable;

  /// Id of a vendor background screen this device can open (`oem_xiaomi`...), or null.
  final String? oemBackgroundSettings;
  final bool powerSaveMode;
  final bool keyguardSupportDeclared;
  final bool deviceSecure;
  final bool keyguardLocked;
  final bool wakeEnabled;
  final String listenerState;
  final String? listenerReason;
  final String hotwordHardware;
  final int? evidenceAssistAt;
  final int? evidenceWakeAt;
  final int? evidenceWakeLockedAt;
  final int? evidenceRoleSeenAt;

  /// Vendors whose background management is known to stop services.
  bool get restrictiveOem => const {
    'xiaomi',
    'redmi',
    'poco',
    'oppo',
    'realme',
    'vivo',
    'oneplus',
    'huawei',
    'honor',
    'samsung',
    'nubia',
    'zte',
    'asus',
    'tecno',
    'infinix',
    'meizu',
  }.contains(manufacturer.toLowerCase());
}

/// What a step needs to say about itself.
enum NexaStepState {
  /// Independently verified (system state or real evidence).
  verified,

  /// Set up, but nothing proved that it works yet: offer the test.
  configuredNotTested,

  /// The person still has to do it.
  todo,

  /// The system or manufacturer stops it right now.
  blocked,

  /// This device or Android version cannot do it.
  unsupported,
}

enum NexaStepId {
  microphone,
  notifications,
  defaultAssistant,
  wakeListening,
  battery,
  oemBackground,
  lockScreen,
}

/// What pressing the step's button does.
enum NexaStepAction {
  none,
  requestMicrophone,
  requestNotifications,
  openDefaultApps,
  openVoiceInput,
  openNotifications,
  openBattery,
  openOemBackground,
  openAppDetails,
  enableWake,
  testAssist,
  testLock,
}

final class NexaSetupStep {
  const NexaSetupStep({
    required this.id,
    required this.state,
    this.required = true,
    this.action = NexaStepAction.none,
    this.fallback = NexaStepAction.none,
    this.note = '',
  });

  final NexaStepId id;
  final NexaStepState state;

  /// False for recommendations that do not stop the assistant working.
  final bool required;
  final NexaStepAction action;

  /// Offered when the first action cannot be opened on this device.
  final NexaStepAction fallback;

  /// A code the screen turns into guidance (`role_held_not_bound`, `no_screen_lock`, ...).
  final String note;
}

/// The checklist for THIS device. [hasWakeModel] is whether an installed
/// acoustic wake model exists; [wantsWake] whether wake listening is intended.
List<NexaSetupStep> buildAssistantChecklist(
  NexaAssistantCapabilities c, {
  required bool hasWakeModel,
  bool wantsWake = true,
}) {
  final steps = <NexaSetupStep>[];

  steps.add(
    c.microphonePermission
        ? const NexaSetupStep(
            id: NexaStepId.microphone,
            state: NexaStepState.verified,
          )
        : const NexaSetupStep(
            id: NexaStepId.microphone,
            state: NexaStepState.todo,
            action: NexaStepAction.requestMicrophone,
            fallback: NexaStepAction.openAppDetails,
          ),
  );

  if (wantsWake) {
    steps.add(
      c.notificationsEnabled
          ? const NexaSetupStep(
              id: NexaStepId.notifications,
              state: NexaStepState.verified,
            )
          : NexaSetupStep(
              id: NexaStepId.notifications,
              state: NexaStepState.todo,
              action: c.postNotificationsRuntime
                  ? NexaStepAction.requestNotifications
                  : NexaStepAction.openNotifications,
              fallback: NexaStepAction.openNotifications,
              note: 'listening_needs_visible_notification',
            ),
    );
  }

  steps.add(_defaultAssistant(c));
  if (wantsWake) steps.add(_wake(c, hasWakeModel));

  // Recommendations: only when they can matter on this device.
  if (wantsWake) {
    steps.add(
      c.ignoringBatteryOptimizations
          ? const NexaSetupStep(
              id: NexaStepId.battery,
              state: NexaStepState.verified,
              required: false,
            )
          : NexaSetupStep(
              id: NexaStepId.battery,
              state: c.powerSaveMode
                  ? NexaStepState.blocked
                  : NexaStepState.todo,
              required: false,
              action: c.batterySettingsResolvable
                  ? NexaStepAction.openBattery
                  : NexaStepAction.openAppDetails,
              note: c.powerSaveMode ? 'battery_saver_on' : '',
            ),
    );
    if (c.oemBackgroundSettings != null) {
      steps.add(
        const NexaSetupStep(
          id: NexaStepId.oemBackground,
          // Android cannot tell us what the vendor screen is set to.
          state: NexaStepState.configuredNotTested,
          required: false,
          action: NexaStepAction.openOemBackground,
          fallback: NexaStepAction.openAppDetails,
          note: 'oem_cannot_be_verified',
        ),
      );
    } else if (c.restrictiveOem) {
      steps.add(
        const NexaSetupStep(
          id: NexaStepId.oemBackground,
          state: NexaStepState.configuredNotTested,
          required: false,
          action: NexaStepAction.openAppDetails,
          note: 'oem_manual',
        ),
      );
    }
  }

  steps.add(_lock(c, wantsWake));
  return steps;
}

NexaSetupStep _defaultAssistant(NexaAssistantCapabilities c) {
  const id = NexaStepId.defaultAssistant;
  if (c.roleApi && c.roleAvailable == false) {
    // No role on this build: only the older settings route may exist.
    return NexaSetupStep(
      id: id,
      state: NexaStepState.unsupported,
      required: false,
      action: c.settingsDefaultApps
          ? NexaStepAction.openDefaultApps
          : NexaStepAction.none,
      note: 'role_unavailable',
    );
  }
  if (c.roleHeld == true) {
    final proven = c.serviceBound && c.evidenceAssistAt != null;
    return NexaSetupStep(
      id: id,
      state: proven
          ? NexaStepState.verified
          : NexaStepState.configuredNotTested,
      required: false,
      action: proven ? NexaStepAction.none : NexaStepAction.testAssist,
      note: proven
          ? ''
          : (c.serviceBound
                ? 'role_held_not_tested'
                : 'role_held_service_not_bound'),
    );
  }
  if (!c.roleApi) {
    // Android 9 and older: nothing can be checked through a role.
    return NexaSetupStep(
      id: id,
      state: NexaStepState.todo,
      required: false,
      action: c.settingsVoiceInput
          ? NexaStepAction.openVoiceInput
          : NexaStepAction.openDefaultApps,
      note: 'cannot_verify_role',
    );
  }
  // The assistant role is NOT requestable by apps (Android logs "Role is not
  // requestable: android.app.role.ASSISTANT"; verified on Android 13): the
  // person picks it in Settings. Prefer the voice-input/assistant picker,
  // then the default-apps list, each only if this device can open it.
  if (c.settingsVoiceInput || c.settingsDefaultApps) {
    return NexaSetupStep(
      id: id,
      state: NexaStepState.todo,
      required: false,
      action: c.settingsVoiceInput
          ? NexaStepAction.openVoiceInput
          : NexaStepAction.openDefaultApps,
      fallback: (c.settingsVoiceInput && c.settingsDefaultApps)
          ? NexaStepAction.openDefaultApps
          : NexaStepAction.none,
      note: 'choose_digital_assistant',
    );
  }
  return const NexaSetupStep(
    id: id,
    state: NexaStepState.blocked,
    required: false,
    note: 'no_settings_destination',
  );
}

NexaSetupStep _wake(NexaAssistantCapabilities c, bool hasWakeModel) {
  const id = NexaStepId.wakeListening;
  if (!hasWakeModel) {
    return const NexaSetupStep(
      id: id,
      state: NexaStepState.unsupported,
      note: 'no_wake_model',
    );
  }
  if (!c.microphonePermission || !c.notificationsEnabled) {
    return const NexaSetupStep(
      id: id,
      state: NexaStepState.todo,
      note: 'needs_microphone_and_notification',
    );
  }
  if (c.listenerState == 'running') {
    final proven = c.evidenceWakeAt != null;
    return NexaSetupStep(
      id: id,
      state: proven
          ? NexaStepState.verified
          : NexaStepState.configuredNotTested,
      note: proven ? '' : 'listening_not_tested',
    );
  }
  if (c.listenerReason == 'background_start_blocked' ||
      c.listenerReason == 'permission_denied') {
    return NexaSetupStep(
      id: id,
      state: NexaStepState.blocked,
      action: NexaStepAction.enableWake,
      note: c.listenerReason!,
    );
  }
  return NexaSetupStep(
    id: id,
    state: NexaStepState.todo,
    action: NexaStepAction.enableWake,
    // After a reboot or a force-stop Android only lets it start while AMEER is open.
    note: c.wakeEnabled ? 'enabled_but_not_running' : '',
  );
}

NexaSetupStep _lock(NexaAssistantCapabilities c, bool wantsWake) {
  const id = NexaStepId.lockScreen;
  if (!c.keyguardSupportDeclared) {
    return const NexaSetupStep(
      id: id,
      state: NexaStepState.unsupported,
      required: false,
      note: 'keyguard_not_supported',
    );
  }
  if (c.evidenceWakeLockedAt != null) {
    return NexaSetupStep(
      id: id,
      state: NexaStepState.verified,
      required: false,
      note: c.deviceSecure ? '' : 'no_screen_lock',
    );
  }
  final viaAssist = c.roleHeld == true;
  final viaWake = wantsWake && c.listenerState == 'running';
  if (!viaAssist && !viaWake) {
    return const NexaSetupStep(
      id: id,
      state: NexaStepState.todo,
      required: false,
      note: 'needs_assistant_or_listening',
    );
  }
  return NexaSetupStep(
    id: id,
    state: NexaStepState.configuredNotTested,
    required: false,
    action: NexaStepAction.testLock,
    note: c.microphoneFgsStart == 'foreground_only_strict'
        ? 'android14_reopen_after_restart'
        : (c.deviceSecure ? '' : 'no_screen_lock'),
  );
}

/// The one-line outcome of a checklist.
enum NexaSetupOverall { ready, partial, blocked }

NexaSetupOverall overallOf(List<NexaSetupStep> steps) {
  final required = steps.where((s) => s.required);
  if (required.any((s) => s.state == NexaStepState.blocked)) {
    return NexaSetupOverall.blocked;
  }
  if (required.every((s) => s.state == NexaStepState.verified)) {
    return NexaSetupOverall.ready;
  }
  return NexaSetupOverall.partial;
}

/// Outcome of the role request.
final class NexaRoleRequest {
  const NexaRoleRequest({required this.started, this.held, this.reason});

  factory NexaRoleRequest.fromMap(Map<Object?, Object?> m) => NexaRoleRequest(
    started: m['started'] == true,
    held: m['held'] as bool?,
    reason: m['reason'] as String?,
  );

  /// The system screen was opened.
  final bool started;

  /// The role as Android reports it after the request (null if unreadable).
  final bool? held;
  final String? reason;
}
