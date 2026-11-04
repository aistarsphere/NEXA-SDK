import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/device_assistant.dart';
import 'package:nexa_example/assistant/device_assistant_strings.dart';
import 'package:nexa_example/assistant/voice_setup/voice_setup_page.dart';
import 'package:nexa_example/assistant/voice_setup/voice_setup_strings.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// "LABEEB as assistant": default-assistant role, «يا لبيب», the owner's
/// voice, sensitivity, a live test, background limits and privacy. Each
/// item says whether it is set up, needs a permission, or is not
/// available on this device.
class DeviceAssistantPage extends StatefulWidget {
  const DeviceAssistantPage({required this.assistant, super.key});
  final DeviceAssistant assistant;

  @override
  State<DeviceAssistantPage> createState() => _DeviceAssistantPageState();
}

class _DeviceAssistantPageState extends State<DeviceAssistantPage>
    with WidgetsBindingObserver {
  NexaAssistant get _plugin => widget.assistant.plugin;
  NexaAssistantStatus? _status;
  NexaWakeDecision? _test;
  bool _testing = false;
  String? _note;
  StreamSubscription<NexaAssistantEvent>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _events = _plugin.events.listen((e) {
      if (e is NexaWakeListenerChanged) unawaited(_refresh());
    });
    _refreshSoon();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_events?.cancel());
    super.dispose();
  }

  // Back from Android settings: the role or a permission may have changed.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshSoon();
  }

  Future<void> _refresh() async {
    final s = await _plugin.status();
    if (mounted) setState(() => _status = s);
  }

  /// Android binds a newly chosen assistant a moment after its settings
  /// screen closes: read the real state now and twice more shortly after.
  void _refreshSoon() {
    unawaited(_refresh());
    for (final ms in const [800, 2500]) {
      Future<void>.delayed(Duration(milliseconds: ms), () {
        if (mounted) unawaited(_refresh());
      });
    }
  }

  Future<void> _setWake(bool on) async {
    final s = DeviceAssistantStrings.of(context);
    if (on) {
      if (!await ph.Permission.microphone.request().isGranted) {
        setState(() => _note = s.micNeeded);
        return;
      }
      // Android 13+: the listening notice needs notification permission.
      await ph.Permission.notification.request();
    }
    final r = await _plugin.setWakeEnabled(on);
    setState(
      () => _note = switch (r) {
        NexaAssistantToggle.permissionDenied => s.micNeeded,
        NexaAssistantToggle.notEnrolled => s.wakeNeedsEnrollment,
        NexaAssistantToggle.notInForeground => s.wakeNeedsForeground,
        _ => null,
      },
    );
    await _refresh();
  }

  Future<void> _setRequireVoice(bool on) async {
    final s = DeviceAssistantStrings.of(context);
    final r = await _plugin.setRequireOwnerVoice(on);
    setState(
      () => _note = switch (r) {
        NexaAssistantToggle.modelUnavailable => s.modelMissing,
        NexaAssistantToggle.notEnrolled => s.noVoiceProfile,
        _ => null,
      },
    );
    await _refresh();
  }

  Future<void> _enroll() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VoiceEnrollmentPage(plugin: _plugin),
      ),
    );
    await _refresh();
  }

  Future<void> _delete() async {
    final s = DeviceAssistantStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteVoice),
        content: Text(s.deleteVoiceBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('device_assistant_delete_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.deleteVoice),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _plugin.deleteVoiceProfile();
    messenger.showSnackBar(SnackBar(content: Text(s.deleted)));
    setState(() => _test = null);
    await _refresh();
  }

  Future<void> _runTest() async {
    if (!await ph.Permission.microphone.request().isGranted) return;
    setState(() {
      _testing = true;
      _test = null;
    });
    final r = await _plugin.testListen();
    if (mounted) {
      setState(() {
        _testing = false;
        _test = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DeviceAssistantStrings.of(context);
    final st = _status;
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: st == null
          ? const Center(child: CircularProgressIndicator())
          : !st.platformSupported
          ? Center(child: Text(s.notOnThisDevice))
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const Key('device_assistant_list'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_note != null)
                    _Banner(
                      text: _note!,
                      onClose: () => setState(() => _note = null),
                    ),
                  ..._role(context, s, st),
                  ..._panel(context, s, st),
                  ..._wake(context, s, st),
                  ..._voice(context, s, st),
                  ..._testSection(context, s, st),
                  ..._background(context, s, st),
                  ..._diagnostics(context, s, st),
                  _Label(s.privacy),
                  _Card(
                    icon: Icons.shield_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.privacyBody),
                        const SizedBox(height: 8),
                        Text(s.sensitiveNote),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _panel(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    final device = widget.assistant;
    final timeout = device.idleTimeout?.inSeconds ?? 0;
    return [
      _Label(s.panelTitle),
      _Card(
        icon: Icons.picture_in_picture_alt_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.panelBody),
            const SizedBox(height: 12),
            Text(
              s.panelPosition,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            SegmentedButton<NexaPanelPosition>(
              key: const Key('device_assistant_position'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: NexaPanelPosition.bottom,
                  label: Text(s.posBottom),
                ),
                ButtonSegment(
                  value: NexaPanelPosition.top,
                  label: Text(s.posTop),
                ),
                ButtonSegment(
                  value: NexaPanelPosition.left,
                  label: Text(s.posLeft),
                ),
                ButtonSegment(
                  value: NexaPanelPosition.right,
                  label: Text(s.posRight),
                ),
              ],
              selected: {st.panelPosition},
              onSelectionChanged: (v) async {
                await _plugin.setPanelPosition(v.first);
                await _refresh();
              },
            ),
            const SizedBox(height: 12),
            Text(s.idleTimeout, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              key: const Key('device_assistant_idle'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 30, label: Text(s.seconds(30))),
                ButtonSegment(value: 60, label: Text(s.seconds(60))),
                ButtonSegment(value: 120, label: Text(s.minutes(2))),
                ButtonSegment(value: 0, label: Text(s.never)),
              ],
              selected: {
                const [30, 60, 120, 0].contains(timeout) ? timeout : 60,
              },
              onSelectionChanged: (v) {
                device.idleTimeout = v.first == 0
                    ? null
                    : Duration(seconds: v.first);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    ];
  }

  static String _yn(bool? v) => v == null ? '?' : (v ? '✓' : '✗');

  /// One line per check, each with its own real result.
  List<Widget> _diagnostics(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    final t = _test;
    String when(String? v) {
      if (v == null) return s.never;
      final parts = v.split('@');
      final ms = parts.length > 1 ? int.tryParse(parts.last) : null;
      final at = ms == null
          ? ''
          : ' · ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(ms)).format(context)}';
      return '${parts.first}$at';
    }

    return [
      _Label(s.checks),
      Card(
        child: Column(
          key: const Key('device_assistant_checks'),
          children: [
            _Check(
              s.checkRole,
              st.isDefaultAssistant,
              '${s.signalRole}: ${_yn(st.assistantRoleHeld)} · '
              '${s.signalSetting}: ${_yn(st.voiceInteractionSetting ?? st.assistantSetting)} · '
              '${s.signalBound}: ${_yn(st.assistantServiceBound)}',
            ),
            _Check(
              s.checkEnrollment,
              st.enrolled,
              st.enrolled ? s.enrolledSamples(st.enrolledSamples) : null,
            ),
            _Check(
              s.checkOffline,
              t?.ok == true
                  ? t!.keywordDistance != null &&
                        t.keywordDistance! <= (t.keywordThreshold ?? 0)
                  : null,
              t == null ? s.checkRunTest : null,
            ),
            _Check(
              s.checkOwner,
              !st.requireOwnerVoice
                  ? null
                  : (t?.speakerScore == null
                        ? null
                        : t!.speakerScore! >= (t.speakerThreshold ?? 1)),
              !st.speakerModelAvailable
                  ? s.modelMissing
                  : st.requireOwnerVoice
                  ? null
                  : s.checkOff,
            ),
            _Check(
              s.checkListener,
              !st.wakeEnabled
                  ? null
                  : st.listenerState == 'running' ||
                        st.listenerState == 'paused',
              st.wakeEnabled
                  ? '${st.listenerState}${st.listenerReason == null ? '' : ' (${st.listenerReason})'}'
                  : s.checkOff,
            ),
            _Check(
              s.checkInvocation,
              st.lastActivation != null,
              when(st.lastActivation),
            ),
            _Check(
              s.checkMicrophone,
              st.microphonePermission,
              st.listenerState == 'paused' ? s.micHandedOver : null,
            ),
            _Check(s.checkLastEnd, null, when(st.lastEnd)),
          ],
        ),
      ),
    ];
  }

  /// Setup steps only while something is missing; once Android reports
  /// LABEEB as the assistant, a compact verified card (read live each time).
  List<Widget> _role(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    if (st.isDefaultAssistant) {
      return [
        _Label(s.defaultAssistant),
        Card(
          child: ListTile(
            key: const Key('device_assistant_role_verified'),
            leading: Icon(
              Icons.verified_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(s.isDefault),
            trailing: TextButton(
              key: const Key('device_assistant_change'),
              onPressed: _plugin.openAssistantSettings,
              child: Text(s.change),
            ),
          ),
        ),
      ];
    }
    return [
      _Label(s.defaultAssistant),
      _Card(
        icon: Icons.assistant_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              st.assistantRoleAvailable ? s.notDefault : s.roleUnavailable,
              key: const Key('device_assistant_role_status'),
            ),
            if (st.assistantRoleAvailable) ...[
              const SizedBox(height: 8),
              Text(s.roleHelp, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('device_assistant_choose'),
                    onPressed: _plugin.openAssistantSettings,
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(s.chooseInSettings),
                  ),
                  TextButton.icon(
                    key: const Key('device_assistant_recheck'),
                    onPressed: _refreshSoon,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(s.recheck),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _wake(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final state = !st.wakeEnabled
        ? s.wakeOff
        : switch (st.listenerState) {
            'running' => s.wakeListening,
            'paused' => s.wakePaused,
            _ when st.listenerReason == 'background_start_blocked' =>
              s.wakeBlocked,
            _ when st.listenerReason == 'permission_denied' => s.micNeeded,
            _ => s.wakeNeedsForeground,
          };
    return [
      _Label(s.wakeTitle),
      Card(
        child: Column(
          children: [
            SwitchListTile(
              key: const Key('device_assistant_wake'),
              title: Text(
                s.wakeSwitch(st.wakePhraseLabel ?? DeviceAssistant.wakePhrase),
              ),
              subtitle: Text(
                st.enrolled || st.wakeDetector == 'neural'
                    ? state
                    : s.wakeNeedsEnrollment,
              ),
              value: st.wakeEnabled,
              onChanged: st.enrolled || st.wakeDetector == 'neural'
                  ? _setWake
                  : null,
              secondary: Icon(
                st.listening
                    ? Icons.hearing_rounded
                    : Icons.hearing_disabled_rounded,
                color: st.listening ? scheme.primary : null,
              ),
            ),
            if (st.wakeEnabled && !st.notificationsEnabled)
              ListTile(
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: scheme.error,
                ),
                title: Text(s.notificationsOff),
                trailing: TextButton(
                  onPressed: () async {
                    await ph.Permission.notification.request();
                    await _refresh();
                  },
                  child: Text(s.allowNotifications),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _Card(icon: Icons.memory_rounded, child: Text(s.hardwareHotword)),
      _Label(s.sensitivity),
      SegmentedButton<NexaWakeSensitivity>(
        key: const Key('device_assistant_sensitivity'),
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: NexaWakeSensitivity.strict,
            label: Text(s.strict),
          ),
          ButtonSegment(
            value: NexaWakeSensitivity.normal,
            label: Text(s.normal),
          ),
          ButtonSegment(
            value: NexaWakeSensitivity.relaxed,
            label: Text(s.relaxed),
          ),
        ],
        selected: {st.sensitivity},
        onSelectionChanged: (v) async {
          await _plugin.setSensitivity(v.first);
          await _refresh();
        },
      ),
    ];
  }

  List<Widget> _voice(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return [
      _Label(s.voiceTitle),
      Card(
        child: Column(
          children: [
            ListTile(
              key: const Key('device_assistant_voice_setup'),
              leading: const Icon(Icons.graphic_eq_rounded),
              title: Text(VoiceSetupStrings.of(context).entry),
              subtitle: Text(VoiceSetupStrings.of(context).entrySubtitle),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => VoiceSetupPage(plugin: _plugin),
                  ),
                );
                await _refresh();
              },
            ),
            ListTile(
              key: const Key('device_assistant_enroll'),
              leading: const Icon(Icons.record_voice_over_outlined),
              title: Text(st.enrolled ? s.reEnroll : s.enroll),
              subtitle: st.enrolled
                  ? Text(s.enrolledSamples(st.enrolledSamples))
                  : null,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _enroll,
            ),
            SwitchListTile(
              key: const Key('device_assistant_require_voice'),
              title: Text(s.requireMyVoice),
              subtitle: Text(
                !st.speakerModelAvailable
                    ? s.modelMissing
                    : st.enrolled && !st.speakerEnrolled
                    ? s.noVoiceProfile
                    : s.requireMyVoiceBody,
              ),
              value: st.requireOwnerVoice,
              onChanged: st.speakerEnrolled && st.speakerModelAvailable
                  ? _setRequireVoice
                  : null,
            ),
            if (st.enrolled)
              ListTile(
                key: const Key('device_assistant_delete'),
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: scheme.error,
                ),
                title: Text(
                  s.deleteVoice,
                  style: TextStyle(color: scheme.error),
                ),
                onTap: _delete,
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _testSection(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    if (!st.enrolled) return const [];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = _test;
    return [
      _Label(s.test),
      _Card(
        icon: Icons.graphic_eq_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_testing)
              Text(s.testPrompt(DeviceAssistant.wakePhrase))
            else if (t != null) ...[
              Text(
                !t.ok
                    ? (t.reason == 'no_speech'
                          ? s.heardNothing
                          : s.sampleProblem(t.reason))
                    : t.accepted
                    ? s.testAccepted
                    : s.testRejected,
                key: const Key('device_assistant_test_result'),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: t.accepted ? scheme.primary : scheme.error,
                ),
              ),
              if (t.ok && t.keywordDistance != null)
                Text(
                  '${t.keywordDistance! <= (t.keywordThreshold ?? 0) ? s.phraseMatched : s.phraseNotMatched}'
                  ' (${t.keywordDistance!.toStringAsFixed(3)} / ${t.keywordThreshold?.toStringAsFixed(3)})',
                ),
              if (t.ok && t.speakerScore != null)
                Text(
                  '${t.speakerScore! >= (t.speakerThreshold ?? 1) ? s.voiceMatched : s.voiceNotMatched}'
                  ' (${t.speakerScore!.toStringAsFixed(2)} / ${t.speakerThreshold?.toStringAsFixed(2)})',
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('device_assistant_test'),
              onPressed: _testing ? null : _runTest,
              icon: _testing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.mic_none_rounded),
              label: Text(s.testRun),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _background(
    BuildContext context,
    DeviceAssistantStrings s,
    NexaAssistantStatus st,
  ) {
    final xiaomi = const {
      'xiaomi',
      'redmi',
      'poco',
    }.contains(st.manufacturer?.toLowerCase());
    final device = [
      st.manufacturer,
      st.model,
      if (st.release != null) 'Android ${st.release}',
    ].whereType<String>().join(' · ');
    return [
      _Label(s.background),
      _Card(
        icon: st.ignoringBatteryOptimizations
            ? Icons.battery_full_rounded
            : Icons.battery_alert_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(st.ignoringBatteryOptimizations ? s.batteryOk : s.batteryOn),
            if (xiaomi) ...[const SizedBox(height: 8), Text(s.oemNote)],
            const SizedBox(height: 8),
            Text(s.limits),
            const SizedBox(height: 8),
            Text(device, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  key: const Key('device_assistant_battery'),
                  onPressed: _plugin.openBatterySettings,
                  child: Text(s.batterySettings),
                ),
                if (xiaomi)
                  OutlinedButton(
                    key: const Key('device_assistant_autostart'),
                    onPressed: _plugin.openBackgroundSettings,
                    child: Text(s.oemSettings),
                  ),
              ],
            ),
          ],
        ),
      ),
    ];
  }
}

/// Records «يا لبيب» five times (at least three kept), then saves the
/// encrypted on-device profile. Audio never leaves memory.
class VoiceEnrollmentPage extends StatefulWidget {
  const VoiceEnrollmentPage({required this.plugin, super.key});
  final NexaAssistant plugin;

  static const target = 5;

  @override
  State<VoiceEnrollmentPage> createState() => _VoiceEnrollmentPageState();
}

class _VoiceEnrollmentPageState extends State<VoiceEnrollmentPage> {
  int _count = 0;
  bool _recording = false;
  bool _saving = false;
  bool _finished = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    unawaited(widget.plugin.startEnrollment());
  }

  @override
  void dispose() {
    if (!_finished) unawaited(widget.plugin.cancelEnrollment());
    super.dispose();
  }

  Future<void> _record() async {
    final s = DeviceAssistantStrings.of(context);
    if (!await ph.Permission.microphone.request().isGranted) {
      setState(() => _problem = 'permission_denied');
      return;
    }
    setState(() {
      _recording = true;
      _problem = null;
    });
    final r = await widget.plugin.recordEnrollmentSample();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _count = r.count;
      _problem = r.ok ? null : r.reason;
    });
    if (r.ok && _count >= VoiceEnrollmentPage.target) await _save(s);
  }

  Future<void> _save(DeviceAssistantStrings s) async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _saving = true);
    final r = await widget.plugin.finishEnrollment();
    _finished = r.ok;
    if (!mounted) return;
    setState(() => _saving = false);
    if (!r.ok) {
      setState(() => _problem = 'save_failed');
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text(r.speaker ? s.saved : s.savedNoVoice)),
    );
    nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final s = DeviceAssistantStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const total = VoiceEnrollmentPage.target;
    return Scaffold(
      appBar: AppBar(title: Text(s.enrollTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(s.enrollIntro(DeviceAssistant.wakePhrase, total)),
              const SizedBox(height: 8),
              Text(s.enrollTip, style: theme.textTheme.bodySmall),
              const Spacer(),
              Center(
                child: Text(
                  '«${DeviceAssistant.wakePhrase}»',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox.square(
                  dimension: 96,
                  child: FilledButton(
                    key: const Key('enroll_record'),
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: _recording
                          ? scheme.error
                          : scheme.primary,
                    ),
                    onPressed: _recording || _saving ? null : _record,
                    child: Icon(
                      _recording ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                      size: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  _recording ? s.listening : s.enrollProgress(_count, total),
                  key: const Key('enroll_progress'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _count / total),
              if (_problem != null) ...[
                const SizedBox(height: 12),
                Text(
                  _problem == 'save_failed'
                      ? s.saveFailed
                      : s.sampleProblem(_problem),
                  key: const Key('enroll_problem'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.error),
                ),
                if (_problem == 'permission_denied')
                  TextButton(
                    onPressed: ph.openAppSettings,
                    child: Text(s.openSettings),
                  ),
              ],
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(s.cancel),
                  ),
                  const Spacer(),
                  FilledButton(
                    key: const Key('enroll_save'),
                    onPressed: _count >= 3 && !_recording && !_saving
                        ? () => _save(s)
                        : null,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(s.save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A diagnostics row: passed, failed, or not run / not applicable.
class _Check extends StatelessWidget {
  const _Check(this.title, this.passed, this.detail);
  final String title;
  final bool? passed;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(
        passed == null
            ? Icons.radio_button_unchecked_rounded
            : passed!
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded,
        color: passed == null
            ? scheme.onSurfaceVariant
            : passed!
            ? scheme.primary
            : scheme.error,
      ),
      title: Text(title),
      subtitle: detail == null ? null : Text(detail!),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: ListTile(
        key: const Key('device_assistant_note'),
        title: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
        trailing: IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
