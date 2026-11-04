import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/setup/assistant_setup_page.dart';
import 'package:nexa_example/assistant/voice/voice_wizard_strings.dart';

/// "Set up my voice": consent, one natural sentence, a different sentence to
/// check it, then a wake-phrase try-out. More sentences are asked for only
/// when the check is not conclusive; the number is decided by the plugin from
/// measured evidence, never a fixed count.
class VoiceWizardPage extends StatefulWidget {
  const VoiceWizardPage({required this.plugin, super.key});
  final NexaAssistant plugin;

  @override
  State<VoiceWizardPage> createState() => _VoiceWizardPageState();
}

enum _Step { loading, consent, record, verify, extra, tryIt, done, improve }

class _VoiceWizardPageState extends State<VoiceWizardPage> {
  _Step _step = _Step.loading;
  NexaEnrollStatus _status = const NexaEnrollStatus();
  bool _agreed = false;

  bool _busy = false;
  String _live = '';
  double _level = -90;
  bool _speaking = false;
  String? _problem;
  String? _moreReason;
  StreamSubscription<NexaSetupEvent>? _events;

  // Step 3.
  bool _testing = false;
  NexaWakeTest? _wake;
  bool? _assistantSet;
  String _phrase = 'يا أمير';

  @override
  void initState() {
    super.initState();
    _events = widget.plugin.setupEvents.listen(_onLive, onError: (_) {});
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    unawaited(widget.plugin.voiceSetupCancel());
    unawaited(widget.plugin.voiceSetupEnd());
    super.dispose();
  }

  void _onLive(NexaSetupEvent e) {
    if (!mounted || !_busy) return;
    setState(() {
      switch (e.stage) {
        case 'level':
          _level = e.levelDb ?? _level;
          _speaking = e.speaking;
        case 'opening' || 'ready' || 'speech' || 'processing':
          _live = e.stage;
      }
    });
  }

  Future<void> _load() async {
    final st = await widget.plugin.enrollStatus();
    if (!mounted) return;
    setState(() {
      _status = st;
      _step = _stepFor(st);
    });
    if (st.consented) await widget.plugin.voiceSetupBegin();
    if (st.consented && st.state == NexaEnrollState.ready) {
      await _checkAssistant();
    }
  }

  /// State restoration: where the person left off, from the saved state.
  _Step _stepFor(NexaEnrollStatus st) {
    if (!st.consented) return _Step.consent;
    return switch (st.state) {
      NexaEnrollState.none => _Step.record,
      NexaEnrollState.enrolled => _Step.verify,
      NexaEnrollState.more => _Step.extra,
      NexaEnrollState.ready => _Step.tryIt,
      NexaEnrollState.improve => _Step.improve,
    };
  }

  Future<void> _agree() async {
    await widget.plugin.voiceSetupConsent(accepted: true);
    await widget.plugin.voiceSetupBegin();
    final st = await widget.plugin.enrollStatus();
    if (!mounted) return;
    setState(() {
      _status = st;
      _step = _stepFor(st);
    });
  }

  Future<void> _record(String role) async {
    setState(() {
      _busy = true;
      _live = 'opening';
      _level = -90;
      _speaking = false;
      _problem = null;
    });
    final take = await widget.plugin.enrollRecord(role);
    if (!mounted) return;
    final st = await widget.plugin.enrollStatus();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _live = '';
      _status = st;
      if (!take.ok) {
        _problem = take.reason;
      } else {
        _moreReason = take.reason;
        _step = _stepFor(st);
        if (st.state == NexaEnrollState.ready) unawaited(_checkAssistant());
      }
    });
  }

  Future<void> _stop() => widget.plugin.voiceSetupCancel();

  Future<void> _checkAssistant() async {
    final c = await widget.plugin.capabilities();
    final stt = await widget.plugin.status();
    if (!mounted) return;
    setState(() {
      _assistantSet = c.roleHeld == true;
      _phrase = stt.wakePhraseLabel ?? _phrase;
    });
  }

  Future<void> _runWakeTest() async {
    setState(() {
      _testing = true;
      _wake = null;
    });
    final r = await widget.plugin.wakeTest(checkOwner: _status.hasProfile);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _wake = r;
    });
  }

  Future<void> _startOver() async {
    await widget.plugin.voiceSetupDelete();
    await widget.plugin.voiceSetupConsent(accepted: true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = VoiceWizardStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.setUp)),
      body: SafeArea(
        child: switch (_step) {
          _Step.loading => const Center(child: CircularProgressIndicator()),
          _Step.consent => _consent(s),
          _Step.record => _recordStep(s, 'enroll', 0, s.read),
          _Step.verify => _recordStep(s, 'verify', 1, s.readDifferent),
          _Step.extra => _recordStep(s, 'extra', 1, s.readAnother),
          _Step.tryIt => _tryStep(s),
          _Step.done => _done(s),
          _Step.improve => _improve(s),
        },
      ),
    );
  }

  Widget _header(VoiceWizardStrings s, int active) {
    final scheme = Theme.of(context).colorScheme;
    final labels = [s.step1, s.step2, s.step3];
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        key: const Key('voice_wizard_steps'),
        children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: i <= active
                        ? scheme.primary
                        : scheme.surfaceContainerHighest,
                    child: i < active
                        ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                        : Text(
                            '${i + 1}',
                            style: TextStyle(
                              color: i == active
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _consent(VoiceWizardStrings s) {
    Widget line(IconData icon, String t) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(t)),
        ],
      ),
    );
    return ListView(
      key: const Key('voice_wizard_consent'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.consentTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        line(Icons.mic_none_rounded, s.consent1),
        line(Icons.lock_outline_rounded, s.consent2),
        line(Icons.delete_outline_rounded, s.consent3),
        CheckboxListTile(
          key: const Key('voice_wizard_consent_check'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _agreed,
          onChanged: (v) => setState(() => _agreed = v == true),
          title: Text(s.consentCheck),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const Key('voice_wizard_consent_accept'),
          onPressed: _agreed ? _agree : null,
          child: Text(s.start),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(s.notNow),
        ),
      ],
    );
  }

  Widget _recordStep(
    VoiceWizardStrings s,
    String role,
    int active,
    String title,
  ) {
    final scheme = Theme.of(context).colorScheme;
    // Different text for every sentence of this setup (none contains the wake phrase).
    final text = s.sentence(_status.takes);
    final (live, color) = switch (_live) {
      'ready' => (s.speakNow, scheme.primary),
      'speech' => (s.hearing, scheme.tertiary),
      'processing' => (s.checking, scheme.outline),
      _ => (s.preparing, scheme.outline),
    };
    final meter = ((_level + 60) / 45).clamp(0.0, 1.0);
    return Padding(
      key: Key('voice_wizard_$role'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(s, active),
          Text(
            role == 'extra' ? s.more(_moreReason ?? _status.reason) : title,
            key: const Key('voice_wizard_title'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          Center(
            child: Text(
              text,
              key: const Key('voice_wizard_sentence'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const Spacer(),
          if (_busy)
            Card(
              key: Key(
                'voice_wizard_live_${_live.isEmpty ? 'opening' : _live}',
              ),
              color: color.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      live,
                      key: const Key('voice_wizard_live_text'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: color),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      key: const Key('voice_wizard_meter'),
                      value: _live == 'opening' || _live == '' ? null : meter,
                      color: _speaking ? scheme.tertiary : color,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),
            )
          else if (_problem != null)
            Card(
              key: const Key('voice_wizard_problem'),
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(s.problem(_problem)),
              ),
            ),
          const SizedBox(height: 12),
          if (_busy)
            OutlinedButton.icon(
              key: const Key('voice_wizard_stop'),
              onPressed: _stop,
              icon: const Icon(Icons.stop_rounded),
              label: Text(s.stop),
            )
          else
            FilledButton.icon(
              key: const Key('voice_wizard_record'),
              onPressed: () => _record(role),
              icon: Icon(
                _problem == null ? Icons.mic_rounded : Icons.refresh_rounded,
              ),
              label: Text(_problem == null ? s.record : s.tryAgain),
            ),
        ],
      ),
    );
  }

  Widget _tryStep(VoiceWizardStrings s) {
    final w = _wake;
    return Padding(
      key: const Key('voice_wizard_try'),
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          _header(s, 2),
          Text(s.tryTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(s.tryBody(_phrase)),
          const SizedBox(height: 16),
          if (_testing)
            Column(
              children: [
                Text(
                  s.listening,
                  key: const Key('voice_wizard_wake_listening'),
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
              ],
            )
          else
            FilledButton.icon(
              key: const Key('voice_wizard_wake_test'),
              onPressed: _runWakeTest,
              icon: const Icon(Icons.hearing_rounded),
              label: Text(w == null ? s.tryRun : s.tryAgain),
            ),
          if (w != null && w.ok) ...[
            const SizedBox(height: 16),
            _row(
              w.detections > 0,
              s.phraseResult(w.detections > 0),
              const Key('voice_wizard_wake_result'),
            ),
            if (w.owner != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s.ownerResult(w.owner),
                  key: const Key('voice_wizard_owner_result'),
                ),
              ),
          ] else if (w != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(s.problem(w.reason)),
            ),
          const Divider(height: 32),
          _row(
            _assistantSet == true,
            _assistantSet == true ? s.assistantOk : s.assistantNo,
            const Key('voice_wizard_assistant'),
          ),
          if (_assistantSet != true)
            TextButton(
              key: const Key('voice_wizard_assistant_open'),
              onPressed: () async {
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => AssistantSetupPage(plugin: widget.plugin),
                  ),
                );
                await _checkAssistant();
              },
              child: Text(s.assistantOpen),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('voice_wizard_finish'),
            onPressed: () => setState(() => _step = _Step.done),
            child: Text(s.finish),
          ),
        ],
      ),
    );
  }

  Widget _row(bool ok, String text, Key key) => Row(
    children: [
      Icon(
        ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
        color: ok ? Theme.of(context).colorScheme.primary : null,
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, key: key)),
    ],
  );

  Widget _done(VoiceWizardStrings s) => Padding(
    key: const Key('voice_wizard_done'),
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.verified_user_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          s.status(NexaEnrollState.ready),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(s.finishNote, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('voice_wizard_close'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(s.finish),
        ),
      ],
    ),
  );

  Widget _improve(VoiceWizardStrings s) => Padding(
    key: const Key('voice_wizard_improve'),
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 56,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(height: 16),
        Text(
          s.status(NexaEnrollState.improve),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(s.improveNote, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('voice_wizard_again'),
          onPressed: _startOver,
          child: Text(s.reEnroll),
        ),
      ],
    ),
  );
}
