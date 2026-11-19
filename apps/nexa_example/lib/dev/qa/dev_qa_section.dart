import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexa_example/dev/qa/qa_recorder.dart';

/// DEVELOPMENT ONLY: controls for the QA diagnostics store. Label the next
/// sessions, opt in to transcript capture for one session, see recent
/// records, copy one (export) or delete them. Retrieval from a computer is
/// `dart run tool/qa.dart pull` (example README).
class DevQaSection extends StatefulWidget {
  const DevQaSection({required this.qa, super.key});

  final QaRecorder qa;

  @override
  State<DevQaSection> createState() => _DevQaSectionState();
}

class _DevQaSectionState extends State<DevQaSection> {
  late final TextEditingController _label = TextEditingController(
    text: widget.qa.label.value,
  );

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _copy(String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await widget.qa.read(id);
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(SnackBar(content: Text('Copied $id')));
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete QA records?'),
        content: const Text('All diagnostic records on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('dev_qa_delete_confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok ?? false) await widget.qa.delete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    final qa = widget.qa;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        key: const Key('dev_qa'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('QA diagnostics', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Every chat session and voice call is recorded on this device '
            '(timings, states, request ids; no tokens, no audio). '
            'Run: ${qa.runId}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('dev_qa_label'),
            controller: _label,
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Label for the next sessions',
              hintText: 'e.g. arabic-bargein-wifi',
            ),
            onChanged: (v) => qa.label.value = v,
          ),
          ValueListenableBuilder(
            valueListenable: qa.captureTranscripts,
            builder: (context, on, _) => SwitchListTile(
              key: const Key('dev_qa_capture'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Capture transcripts (next session)'),
              subtitle: const Text(
                'Keeps message text and voice transcripts for accuracy '
                'checks. Turns off when that session ends.',
              ),
              value: on,
              onChanged: (v) => qa.captureTranscripts.value = v,
            ),
          ),
          ValueListenableBuilder(
            valueListenable: qa.index,
            builder: (context, entries, _) {
              final recent = entries.reversed.take(6).toList();
              if (recent.isEmpty) {
                return Text('No records yet.', style: mono);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in recent)
                    InkWell(
                      key: Key('dev_qa_record_${e['id']}'),
                      onTap: () => _copy('${e['id']}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${e['id']}\n'
                          '  ${e['session_id'] ?? '-'} · ${e['outcome']}'
                          ' · warn ${e['warnings'] ?? '-'}'
                          ' · err ${e['errors'] ?? '-'}',
                          style: mono,
                        ),
                      ),
                    ),
                  Text('Tap a record to copy it.', style: mono),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const Key('dev_qa_delete'),
              onPressed: _deleteAll,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete all records'),
            ),
          ),
        ],
      ),
    );
  }
}
