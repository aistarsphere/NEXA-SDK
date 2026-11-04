import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/voice/voice_wizard_page.dart';
import 'package:nexa_example/assistant/voice/voice_wizard_strings.dart';

/// The one voice entry of the assistant settings: "Set up my voice", or its
/// status with test, set up again and delete. No counts, scores or thresholds.
class VoiceStatusCard extends StatefulWidget {
  const VoiceStatusCard({required this.plugin, super.key});
  final NexaAssistant plugin;

  @override
  State<VoiceStatusCard> createState() => _VoiceStatusCardState();
}

class _VoiceStatusCardState extends State<VoiceStatusCard> {
  NexaEnrollStatus? _st;
  bool _requireOwner = false;
  bool _testing = false;
  String? _testResult;
  String? _testProblem;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final st = await widget.plugin.enrollStatus();
    final a = await widget.plugin.status();
    if (!mounted) return;
    setState(() {
      _st = st;
      _requireOwner = a.requireOwnerVoice;
    });
  }

  Future<void> _open() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => VoiceWizardPage(plugin: widget.plugin)),
    );
    await _load();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testProblem = null;
    });
    final r = await widget.plugin.voiceTest();
    if (!mounted) return;
    setState(() {
      _testing = false;
      if (r.ok) {
        _testResult = r.testResult;
      } else {
        _testProblem = r.reason;
      }
    });
  }

  Future<void> _delete(VoiceWizardStrings s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(s.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('voice_card_delete_confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await widget.plugin.voiceSetupDelete();
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.deleted)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = VoiceWizardStrings.of(context);
    final st = _st;
    final scheme = Theme.of(context).colorScheme;
    if (st == null) return const SizedBox.shrink();
    final state = st.consented ? st.state : NexaEnrollState.none;
    final ready = state == NexaEnrollState.ready;
    final color = switch (state) {
      NexaEnrollState.ready => scheme.primary,
      NexaEnrollState.improve => scheme.error,
      _ => scheme.outline,
    };
    return Card(
      key: const Key('voice_card'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.record_voice_over_rounded, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  s.status(state),
                  key: const Key('voice_card_status'),
                  style: TextStyle(color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state == NexaEnrollState.none ||
                state == NexaEnrollState.enrolled ||
                state == NexaEnrollState.more) ...[
              Text(s.setUpBody),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('voice_card_setup'),
                onPressed: _open,
                child: Text(s.setUp),
              ),
            ] else ...[
              Text(
                ready ? s.readyNote : s.improveNote,
                key: const Key('voice_card_note'),
              ),
              const SizedBox(height: 8),
              if (ready) ...[
                SwitchListTile(
                  key: const Key('voice_card_only_me'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.onlyMyVoice),
                  subtitle: Text(s.onlyMyVoiceBody),
                  value: _requireOwner,
                  onChanged: (v) async {
                    await widget.plugin.setRequireOwnerVoice(v);
                    await _load();
                  },
                ),
                OutlinedButton.icon(
                  key: const Key('voice_card_test'),
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mic_none_rounded),
                  label: Text(s.testMyVoice),
                ),
                if (_testing)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(s.sentence(2)),
                  ),
                if (_testResult != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.ownerResult(_testResult),
                      key: const Key('voice_card_test_result'),
                    ),
                  ),
                if (_testProblem != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.problem(_testProblem),
                      key: const Key('voice_card_test_problem'),
                    ),
                  ),
              ],
              TextButton(
                key: const Key('voice_card_again'),
                onPressed: _open,
                child: Text(s.reEnroll),
              ),
              TextButton(
                key: const Key('voice_card_delete'),
                onPressed: () => _delete(s),
                child: Text(s.delete, style: TextStyle(color: scheme.error)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
