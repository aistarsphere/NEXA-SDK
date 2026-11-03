import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';

/// DEVELOPMENT ONLY: records labelled clips for the offline wake-word
/// benchmark (docs/qa/wake-word-technology-benchmark.md). Nothing is
/// recorded before the consent below; clips stay in the app's own files
/// folder on this phone, are never uploaded, and "Delete all" removes them.
class WakeBenchmarkPage extends StatefulWidget {
  const WakeBenchmarkPage({required this.plugin, super.key});
  final NexaAssistant plugin;

  @override
  State<WakeBenchmarkPage> createState() => _WakeBenchmarkPageState();
}

typedef _Item = ({String label, String say, int seconds});

const _positives = <_Item>[
  (label: 'pos_normal', say: 'يا لبيب — normal', seconds: 3),
  (label: 'pos_fast', say: 'يا لبيب — fast', seconds: 3),
  (label: 'pos_slow', say: 'يا لبيب — slow', seconds: 3),
  (label: 'pos_loud', say: 'يا لبيب — louder', seconds: 3),
  (label: 'pos_soft', say: 'يا لبيب — quietly', seconds: 3),
  (label: 'pos_pause', say: 'يا … لبيب — with a pause', seconds: 4),
  (label: 'pos_far', say: 'يا لبيب — phone at arm\'s length', seconds: 3),
  (
    label: 'pos_sentence',
    say: 'يا لبيب شلونك — phrase then more words',
    seconds: 4,
  ),
];

const _negatives = <_Item>[
  (label: 'neg_habibi', say: 'يا حبيبي', seconds: 3),
  (label: 'neg_tabib', say: 'يا طبيب', seconds: 3),
  (label: 'neg_labeeb', say: 'لبيب (without يا)', seconds: 3),
  (label: 'neg_ya', say: 'يا … (another name)', seconds: 3),
  (label: 'neg_sentence', say: 'Any normal sentence', seconds: 4),
  (label: 'neg_shlonak', say: 'شلونك شنو الأخبار', seconds: 3),
];

const _others = <_Item>[
  (
    label: 'other_pos',
    say: 'ANOTHER person (consenting) says يا لبيب',
    seconds: 3,
  ),
  (label: 'other_neg', say: 'ANOTHER person says any sentence', seconds: 4),
];

const _background = <_Item>[
  (label: 'bg_quiet', say: 'Quiet room, nobody speaks', seconds: 10),
  (label: 'bg_tv', say: 'TV / video playing, nobody else speaks', seconds: 10),
  (label: 'bg_talk', say: 'Background conversation', seconds: 10),
  (label: 'bg_fan', say: 'Fan / AC noise', seconds: 10),
];

class _WakeBenchmarkPageState extends State<WakeBenchmarkPage> {
  bool _consented = false;
  String? _recording;
  String? _last;
  int _total = 0;
  final Map<String, int> _counts = {};

  @override
  void initState() {
    super.initState();
    widget.plugin.benchCount().then((n) {
      if (mounted) setState(() => _total = n);
    });
  }

  Future<void> _record(_Item item) async {
    setState(() {
      _recording = item.label;
      _last = null;
    });
    final r = await widget.plugin.benchRecord(item.label, item.seconds);
    if (!mounted) return;
    setState(() {
      _recording = null;
      if (r['ok'] == true) {
        _counts[item.label] = (_counts[item.label] ?? 0) + 1;
        _total = r['count'] as int? ?? _total + 1;
        _last = '✓ ${item.label}';
      } else {
        _last = '✗ ${r['reason']}';
      }
    });
  }

  Future<void> _clear() async {
    final n = await widget.plugin.benchClear();
    if (!mounted) return;
    setState(() {
      _counts.clear();
      _total = 0;
      _last = 'Deleted $n clips';
    });
  }

  Widget _section(String title, List<_Item> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final i in items)
        Card(
          child: ListTile(
            key: Key('bench_${i.label}'),
            title: Text(i.say, textDirection: TextDirection.rtl),
            subtitle: Text(
              '${i.label} · ${i.seconds}s · ${_counts[i.label] ?? 0} recorded',
            ),
            trailing: _recording == i.label
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.fiber_manual_record_rounded),
            onTap: _recording == null ? () => _record(i) : null,
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(title: const Text('Wake-word benchmark (dev)')),
        body: !_consented
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'This records short labelled audio clips to compare wake-word '
                      'methods. Clips are saved only on this phone, in LABEEB\'s own '
                      'files folder, for offline evaluation by the developer over USB. '
                      'They are never uploaded and can be deleted here at any time. '
                      'Only record other people with their consent.',
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const Key('bench_consent'),
                      onPressed: () => setState(() => _consented = true),
                      child: const Text('I agree, start'),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  Text(
                    'Tap a row, then speak within the window. '
                    'Total clips on this phone: $_total'
                    '${_last == null ? '' : '   ·   $_last'}',
                  ),
                  _section(
                    'Owner: «يا لبيب» (record each 3–5 times)',
                    _positives,
                  ),
                  _section('Owner: other phrases (each 2–3 times)', _negatives),
                  _section('Another person (with consent)', _others),
                  _section('Background (nobody says the phrase)', _background),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    key: const Key('bench_speed'),
                    onPressed: _recording == null
                        ? () async {
                            setState(() => _recording = 'speed');
                            final r = await widget.plugin.benchModelSpeed();
                            if (mounted) {
                              setState(() {
                                _recording = null;
                                _last = r.toString();
                              });
                            }
                          }
                        : null,
                    icon: const Icon(Icons.speed_rounded),
                    label: const Text('Measure detector speed (60 s, no mic)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    key: const Key('bench_clear'),
                    onPressed: _recording == null ? _clear : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete all benchmark clips'),
                  ),
                ],
              ),
      ),
    );
  }
}
