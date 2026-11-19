import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/wake/wake_phrase_strings.dart';

/// Chooses which acoustic wake model is active, lets the person try it, and
/// validates a custom phrase without pretending that text alone is a model.
class WakePhrasePage extends StatefulWidget {
  const WakePhrasePage({required this.plugin, super.key});
  final NexaAssistant plugin;

  @override
  State<WakePhrasePage> createState() => _WakePhrasePageState();
}

class _WakePhrasePageState extends State<WakePhrasePage> {
  NexaAssistantStatus? _status;
  String? _testing;
  double _score = 0;
  NexaWakeTest? _result;
  String? _resultFor;
  final _custom = TextEditingController();
  StreamSubscription<NexaWakeTestEvent>? _events;

  @override
  void initState() {
    super.initState();
    _events = widget.plugin.wakeTestEvents.listen((e) {
      if (mounted && e.score != null && _testing != null) {
        setState(() => _score = e.score!);
      }
    }, onError: (_) {});
    unawaited(_load());
  }

  @override
  void dispose() {
    _custom.dispose();
    unawaited(_events?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    final st = await widget.plugin.status();
    if (mounted) setState(() => _status = st);
  }

  Future<void> _use(String id) async {
    await widget.plugin.setWakePhrase(id);
    await _load();
  }

  Future<void> _try(String id) async {
    setState(() {
      _testing = id;
      _score = 0;
      _result = null;
    });
    final r = await widget.plugin.wakeTest(id: id);
    if (!mounted) return;
    setState(() {
      _testing = null;
      _result = r;
      _resultFor = id;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = WakePhraseStrings.of(context);
    final st = _status;
    return Scaffold(
      appBar: AppBar(title: Text(s.title)),
      body: st == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              key: const Key('wake_phrase_list'),
              padding: const EdgeInsets.all(16),
              children: [
                Text(s.intro),
                const SizedBox(height: 12),
                for (final p in st.wakePhrases.where((p) => p.installed))
                  _phraseCard(s, st, p),
                const Divider(height: 32),
                _custom_(s, st),
              ],
            ),
    );
  }

  Widget _phraseCard(
    WakePhraseStrings s,
    NexaAssistantStatus st,
    NexaWakePhrase p,
  ) {
    final active = st.wakePhraseId == p.id;
    final testing = _testing == p.id;
    return Card(
      key: Key('wake_phrase_${p.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.label,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (active)
                  Chip(
                    key: Key('wake_phrase_active_${p.id}'),
                    label: Text(s.selected),
                  )
                else
                  FilledButton.tonal(
                    key: Key('wake_phrase_use_${p.id}'),
                    onPressed: _testing == null ? () => _use(p.id) : null,
                    child: Text(s.use),
                  ),
              ],
            ),
            Text(
              s.status(p.status),
              key: Key('wake_phrase_status_${p.id}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (testing) ...[
              Text(s.listening, key: const Key('wake_phrase_listening')),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _score.clamp(0.0, 1.0),
                minHeight: 8,
              ),
            ] else
              OutlinedButton(
                key: Key('wake_phrase_try_${p.id}'),
                onPressed: _testing == null ? () => _try(p.id) : null,
                child: Text(s.tryIt),
              ),
            if (_resultFor == p.id && _result != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _result!.ok
                      ? s.result(
                          _result!.detections,
                          _result!.maxScore,
                          _result!.threshold,
                        )
                      : s.micDenied,
                  key: Key('wake_phrase_result_${p.id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _custom_(WakePhraseStrings s, NexaAssistantStatus st) {
    final installed = {
      for (final p in st.wakePhrases) validateCustomPhrase(p.label).normalized,
    };
    final v = validateCustomPhrase(_custom.text, installed: installed);
    final typed = _custom.text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.customTitle, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          key: const Key('wake_custom_field'),
          controller: _custom,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: s.customHint),
        ),
        const SizedBox(height: 8),
        if (typed) ...[
          for (final i in v.issues)
            Text(
              s.issue(i),
              key: Key('wake_custom_issue_${i.name}'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          for (final w in v.warnings)
            Text(s.warning(w), key: Key('wake_custom_warning_${w.name}')),
          if (v.ok) Text(s.customTextOk, key: const Key('wake_custom_text_ok')),
          const SizedBox(height: 8),
        ],
        Text(
          s.customStatusUnsupported,
          key: const Key('wake_custom_status'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
