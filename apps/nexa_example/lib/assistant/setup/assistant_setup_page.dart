import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/setup/assistant_setup_strings.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Capability-driven assistant setup. Every state shown comes from Android
/// (or from evidence that something really happened), and the screen asks
/// Android again every time the app comes back to the foreground.
class AssistantSetupPage extends StatefulWidget {
  const AssistantSetupPage({required this.plugin, super.key});

  final NexaAssistant plugin;

  @override
  State<AssistantSetupPage> createState() => _AssistantSetupPageState();
}

class _AssistantSetupPageState extends State<AssistantSetupPage>
    with WidgetsBindingObserver {
  NexaAssistantCapabilities? _caps;
  bool _hasModel = false;
  StreamSubscription<NexaAssistantActivation>? _activations;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _activations = widget.plugin.activations.listen((_) => _refresh());
    unawaited(_refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_activations?.cancel());
    super.dispose();
  }

  /// Coming back from any Android screen: ask the system again. Returning
  /// proves nothing by itself.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final caps = await widget.plugin.capabilities();
    final st = await widget.plugin.status();
    if (!mounted) return;
    setState(() {
      _caps = caps;
      _hasModel = st.wakePhrases.any((p) => p.installed);
    });
  }

  Future<void> _run(NexaStepAction a) async {
    final s = AssistantSetupStrings.of(context);
    switch (a) {
      case NexaStepAction.requestMicrophone:
        final r = await ph.Permission.microphone.request();
        if (r.isPermanentlyDenied) await _open('app_details', s);
      case NexaStepAction.requestNotifications:
        final r = await ph.Permission.notification.request();
        if (r.isPermanentlyDenied) await _open('notifications', s);
      case NexaStepAction.openDefaultApps:
        await _open('default_apps', s);
      case NexaStepAction.openVoiceInput:
        await _open('voice_input', s);
      case NexaStepAction.openNotifications:
        await _open('notifications', s);
      case NexaStepAction.openBattery:
        await _open('battery_list', s);
      case NexaStepAction.openOemBackground:
        await _open(_caps?.oemBackgroundSettings ?? 'app_details', s);
      case NexaStepAction.openAppDetails:
        await _open('app_details', s);
      case NexaStepAction.enableWake:
        await widget.plugin.setWakeEnabled(true);
      case NexaStepAction.testAssist:
        await _info(s.testAssistTitle, s.testAssistBody, s);
      case NexaStepAction.testLock:
        await _info(s.testLockTitle, s.testLockBody, s);
      case NexaStepAction.none:
        break;
    }
    await _refresh();
  }

  Future<void> _open(String id, AssistantSetupStrings s) async {
    final r = await widget.plugin.openSetting(id);
    if (r != 'opened' && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.notOpenable)));
    }
  }

  Future<void> _info(String title, String body, AssistantSetupStrings s) =>
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(s.ok)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = AssistantSetupStrings.of(context);
    final c = _caps;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          IconButton(
            key: const Key('assistant_setup_refresh'),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, s, c),
    );
  }

  Widget _body(
    BuildContext context,
    AssistantSetupStrings s,
    NexaAssistantCapabilities c,
  ) {
    final steps = buildAssistantChecklist(c, hasWakeModel: _hasModel);
    final overall = overallOf(steps);
    final scheme = Theme.of(context).colorScheme;
    final overallColor = switch (overall) {
      NexaSetupOverall.ready => scheme.primary,
      NexaSetupOverall.partial => scheme.tertiary,
      NexaSetupOverall.blocked => scheme.error,
    };
    return ListView(
      key: const Key('assistant_setup_list'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          s.device(c.manufacturer, c.model, c.sdkInt),
          key: const Key('assistant_setup_device'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Chip(
          key: const Key('assistant_setup_overall'),
          label: Text(s.overall(overall)),
          backgroundColor: overallColor.withValues(alpha: 0.15),
          side: BorderSide(color: overallColor),
        ),
        const SizedBox(height: 8),
        for (final st in steps) _tile(context, s, st),
      ],
    );
  }

  Widget _tile(
    BuildContext context,
    AssistantSetupStrings s,
    NexaSetupStep st,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (st.state) {
      NexaStepState.verified => (Icons.check_circle_rounded, scheme.primary),
      NexaStepState.configuredNotTested => (
        Icons.help_outline_rounded,
        scheme.tertiary,
      ),
      NexaStepState.todo => (
        Icons.radio_button_unchecked_rounded,
        scheme.outline,
      ),
      NexaStepState.blocked => (Icons.block_rounded, scheme.error),
      NexaStepState.unsupported => (
        Icons.do_not_disturb_on_outlined,
        scheme.outline,
      ),
    };
    final note = s.note(st.note);
    return Card(
      key: Key('assistant_step_${st.id.name}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.stepTitle(st.id),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  key: Key('assistant_step_state_${st.id.name}'),
                  s.state(st.state),
                  style: TextStyle(color: color),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.stepBody(st.id)),
            if (!st.required)
              Text(s.optional, style: Theme.of(context).textTheme.labelSmall),
            if (note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  note,
                  key: Key('assistant_step_note_${st.id.name}'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (st.action != NexaStepAction.none &&
                st.state != NexaStepState.verified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonal(
                      key: Key('assistant_step_action_${st.id.name}'),
                      onPressed: () => _run(st.action),
                      child: Text(s.action(st.action)),
                    ),
                    if (st.fallback != NexaStepAction.none)
                      TextButton(
                        key: Key('assistant_step_fallback_${st.id.name}'),
                        onPressed: () => _run(st.fallback),
                        child: Text(s.action(st.fallback)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
