import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/voice_setup/voice_setup_protocol.dart';
import 'package:nexa_example/assistant/voice_setup/voice_setup_strings.dart';

/// Guided voice setup: explicit consent first, then the recording protocol,
/// then the calibrated profile. Recording never starts before the owner taps
/// «Agree and start» (the plugin refuses too).
class VoiceSetupPage extends StatefulWidget {
  const VoiceSetupPage({required this.plugin, super.key});

  final NexaAssistant plugin;

  @override
  State<VoiceSetupPage> createState() => _VoiceSetupPageState();
}

enum _Phase { loading, consent, overview, recording, summary }

class _VoiceSetupPageState extends State<VoiceSetupPage> {
  _Phase _phase = _Phase.loading;
  NexaVoiceSetupStatus _status = const NexaVoiceSetupStatus();

  bool _understood = false;
  bool _keep = true;

  List<SetupStage> _stages = ownerProtocol;
  String _speaker = 'owner';
  int _guests = 0;

  /// Prompts accepted in this visit.
  final Set<String> _done = {};
  int _stage = 0;
  int _prompt = 0;
  bool _recording = false;
  NexaSetupTake? _take;
  NexaSetupFinish? _result;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    unawaited(widget.plugin.voiceSetupEnd());
    super.dispose();
  }

  Future<void> _load() async {
    final st = await widget.plugin.voiceSetupStatus();
    if (!mounted) return;
    setState(() {
      _status = st;
      _phase = st.consented ? _Phase.overview : _Phase.consent;
      _guests = {
        for (final k in st.clips.keys)
          if (k.startsWith('guest_')) k.split(':').first,
      }.length;
    });
    if (st.consented) await widget.plugin.voiceSetupBegin();
  }

  Future<void> _agree() async {
    final st = await widget.plugin.voiceSetupConsent(
      accepted: true,
      keepClips: _keep,
    );
    if (!mounted) return;
    await widget.plugin.voiceSetupBegin();
    setState(() {
      _status = st;
      _phase = _Phase.overview;
    });
  }

  Future<void> _delete(VoiceSetupStrings s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.deleteData),
        content: Text(s.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('voice_setup_delete_confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.deleteData),
          ),
        ],
      ),
    );
    if (yes != true) return;
    final st = await widget.plugin.voiceSetupDelete();
    if (!mounted) return;
    _done.clear();
    setState(() {
      _status = st;
      _stages = ownerProtocol;
      _speaker = 'owner';
      _guests = 0;
      _understood = false;
      _phase = _Phase.consent;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.deleted)));
  }

  Future<void> _addGuest(VoiceSetupStrings s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.guestConfirmTitle),
        content: Text(s.guestConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(s.cancel),
          ),
          TextButton(
            key: const Key('voice_setup_guest_confirm'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(s.confirm),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _guests++;
      _speaker = 'guest_$_guests';
      _stages = guestProtocol();
      _stage = 0;
      _prompt = 0;
      _take = null;
      _phase = _Phase.overview;
    });
  }

  void _open(int stage) {
    setState(() {
      _stage = stage;
      _prompt = _firstOpen(stage);
      _take = null;
      _phase = _Phase.recording;
    });
  }

  int _firstOpen(int stage) {
    final prompts = _stages[stage].prompts;
    for (var i = 0; i < prompts.length; i++) {
      if (!_done.contains(_key(prompts[i]))) return i;
    }
    return 0;
  }

  String _key(SetupPrompt p) => '$_speaker/${p.id}';

  int _doneIn(SetupStage st) =>
      st.prompts.where((p) => _done.contains(_key(p))).length;

  SetupPrompt get _current => _stages[_stage].prompts[_prompt];

  Future<void> _record() async {
    final p = _current;
    setState(() {
      _recording = true;
      _take = null;
    });
    final take = await widget.plugin.voiceSetupRecord(
      kind: p.kind,
      promptId: p.id,
      tags: p.tags,
      speaker: _speaker,
      maxMs: p.maxMs,
    );
    if (!mounted) return;
    setState(() {
      _recording = false;
      _take = take;
      if (take.ok) {
        _done.add(_key(p));
        if (take.status != null) _status = take.status!;
      }
    });
  }

  void _next() {
    final prompts = _stages[_stage].prompts;
    var n = _prompt + 1;
    while (n < prompts.length && _done.contains(_key(prompts[n]))) {
      n++;
    }
    setState(() {
      _take = null;
      if (n >= prompts.length) {
        _phase = _Phase.overview;
      } else {
        _prompt = n;
      }
    });
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    final r = await widget.plugin.voiceSetupFinish();
    if (!mounted) return;
    setState(() {
      _finishing = false;
      _result = r;
      if (r.ok) _phase = _Phase.summary;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = VoiceSetupStrings.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.title),
        actions: [
          if (_phase != _Phase.consent && _phase != _Phase.loading)
            IconButton(
              key: const Key('voice_setup_delete'),
              tooltip: s.deleteData,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _delete(s),
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.consent => _consent(s),
          _Phase.overview => _overview(s),
          _Phase.recording => _recordingView(s),
          _Phase.summary => _summary(s),
        },
      ),
    );
  }

  // -------------------------------------------------------------- consent

  Widget _consent(VoiceSetupStrings s) {
    Widget block(String h, String b) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(h, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(b),
        ],
      ),
    );
    return ListView(
      key: const Key('voice_setup_consent'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.consentTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        block(s.consentWhat, s.consentWhatBody),
        block(s.consentStored, s.consentStoredBody),
        block(s.consentLimits, s.consentLimitsBody),
        block(s.consentDelete, s.consentDeleteBody),
        CheckboxListTile(
          key: const Key('voice_setup_consent_check'),
          contentPadding: EdgeInsets.zero,
          value: _understood,
          onChanged: (v) => setState(() => _understood = v == true),
          title: Text(s.consentCheck),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        SwitchListTile(
          key: const Key('voice_setup_keep'),
          contentPadding: EdgeInsets.zero,
          value: _keep,
          onChanged: (v) => setState(() => _keep = v),
          title: Text(s.consentKeep),
          subtitle: Text(s.consentKeepHint),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('voice_setup_consent_accept'),
          onPressed: _understood ? _agree : null,
          child: Text(s.agree),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(s.notNow),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- overview

  Widget _overview(VoiceSetupStrings s) {
    final isGuest = _speaker != 'owner';
    return ListView(
      key: const Key('voice_setup_overview'),
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          isGuest ? '${s.overviewTitle} · $_speaker' : s.overviewTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (_status.keepClips)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              s.keptClips(_status.clips.values.fold(0, (a, b) => a + b)),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 12),
        for (var i = 0; i < _stages.length; i++) _stageCard(s, i),
        const SizedBox(height: 16),
        if (!isGuest) ...[
          FilledButton.icon(
            key: const Key('voice_setup_finish'),
            onPressed: _finishing ? null : _finish,
            icon: _finishing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(s.finish),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _result != null && !_result!.ok
                  ? s.missing(_result!.reason, _result!.have)
                  : s.finishHint,
              key: const Key('voice_setup_finish_hint'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 32),
          ListTile(
            key: const Key('voice_setup_add_guest'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.person_add_alt_1_outlined),
            title: Text(s.addGuest),
            subtitle: Text(s.addGuestHint),
            onTap: () => _addGuest(s),
          ),
        ] else
          OutlinedButton(
            onPressed: () => setState(() {
              _speaker = 'owner';
              _stages = ownerProtocol;
            }),
            child: Text(s.backToSteps),
          ),
      ],
    );
  }

  Widget _stageCard(VoiceSetupStrings s, int i) {
    final st = _stages[i];
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final done = _doneIn(st);
    final all = done == st.prompts.length;
    return Card(
      key: Key('voice_setup_stage_${st.id}'),
      child: ListTile(
        leading: Icon(
          all ? Icons.check_circle_rounded : Icons.mic_none_rounded,
          color: all ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(ar ? st.titleAr : st.titleEn),
        subtitle: Text(s.progress(done, st.prompts.length)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _open(i),
      ),
    );
  }

  // ------------------------------------------------------------ recording

  Widget _recordingView(VoiceSetupStrings s) {
    final st = _stages[_stage];
    final p = _current;
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final take = _take;
    final background = p.kind == 'background';
    return Padding(
      key: const Key('voice_setup_recording'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${ar ? st.titleAr : st.titleEn} · '
            '${s.progress(_prompt + 1, st.prompts.length)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(ar ? st.hintAr : st.hintEn),
          const Spacer(),
          Center(
            child: Text(
              ar ? p.textAr : p.textEn,
              key: const Key('voice_setup_prompt'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall,
            ),
          ),
          if (background)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s.tapToRecordBackground, textAlign: TextAlign.center),
            ),
          const Spacer(),
          if (take != null) _takeCard(s, take),
          const SizedBox(height: 12),
          if (_recording)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(s.listening, key: const Key('voice_setup_listening')),
                ],
              ),
            )
          else if (take != null && take.ok)
            FilledButton(
              key: const Key('voice_setup_next'),
              onPressed: _next,
              child: Text(s.next),
            )
          else
            FilledButton.icon(
              key: const Key('voice_setup_record'),
              onPressed: _record,
              icon: const Icon(Icons.mic_rounded),
              label: Text(take == null ? s.record : s.redo),
            ),
          const SizedBox(height: 8),
          if (take != null && take.ok)
            TextButton(
              key: const Key('voice_setup_redo'),
              onPressed: _recording ? null : _record,
              child: Text(s.redo),
            ),
          TextButton(
            onPressed: _recording
                ? null
                : () => setState(() => _phase = _Phase.overview),
            child: Text(s.backToSteps),
          ),
        ],
      ),
    );
  }

  Widget _takeCard(VoiceSetupStrings s, NexaSetupTake t) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: Key(t.ok ? 'voice_setup_take_ok' : 'voice_setup_take_problem'),
      color: t.ok ? scheme.primaryContainer : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: t.ok
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.taken, style: Theme.of(context).textTheme.titleSmall),
                  if (t.metrics != null)
                    Text(s.level(t.metrics!.peakDb, t.metrics!.snrDb)),
                ],
              )
            : Text(s.reason(t.reason)),
      ),
    );
  }

  // -------------------------------------------------------------- summary

  Widget _summary(VoiceSetupStrings s) {
    final c = _result?.calibration;
    if (c == null) return const SizedBox.shrink();
    return ListView(
      key: const Key('voice_setup_summary'),
      padding: const EdgeInsets.all(20),
      children: [
        Text(s.summaryTitle, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(s.threshold(c.threshold)),
        Text(s.ownerScores(c.ownerP05, c.ownerMedian)),
        Text(s.samples(c.ownerSamples, c.identitySamples, c.impostorSamples)),
        const SizedBox(height: 12),
        Text(c.measuredStrangers ? s.withGuestsNote : s.ownerOnlyNote),
        if (c.measuredStrangers && !c.separable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              s.notSeparable,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('voice_setup_done'),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(s.done),
        ),
      ],
    );
  }
}
