import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// DEVELOPMENT ONLY: exercises the real device tools without AI
/// orchestration (the backend sends no client tool calls yet), and shows a
/// clearly labelled *sample* places result to check the card UI. Nothing
/// here talks to a place provider.
class DevClientToolsSection extends StatelessWidget {
  const DevClientToolsSection({required this.client, super.key});

  final NexaClient client;

  static const sampleAttribution =
      'Sample data (development) — not a live place search';

  /// Fixture in the `nexa.places.v1` shape AWS is asked to send.
  static Map<String, Object?> samplePlaces() => {
    'contract': placesContractV1,
    'result_id': 'dev_sample_${DateTime.now().millisecondsSinceEpoch}',
    'tool': 'places.search_nearby',
    'status': 'ok',
    'query': 'Restaurants nearby (sample)',
    'attribution': sampleAttribution,
    'places': [
      {
        'place_id': 'ChIJ_sample_place_0001',
        'name': 'Sample Grill',
        'category': 'Restaurant',
        'rating': 4.5,
        'user_rating_count': 812,
        'distance_m': 350,
        'location': {'lat': 33.3152, 'lng': 44.3661},
        'open_now': true,
      },
      {
        'place_id': 'ChIJ_sample_place_0002',
        'name': 'مطعم تجريبي',
        'category': 'مطعم',
        'rating': 4.1,
        'user_rating_count': 230,
        'distance_m': 1250,
        'location': {'lat': 33.3201, 'lng': 44.3710},
      },
    ],
  };

  /// The real `device.microphone.record_sample` sheet and recorder, but
  /// nothing is uploaded: reports what was captured, then deletes it.
  Future<void> _recordSample(BuildContext context) async {
    final outcome = await showModalBottomSheet<LabeebSampleOutcome>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const LabeebRecordSampleSheet(
        purpose: 'Development check only: nothing is uploaded.',
        minSeconds: 5,
        maxSeconds: 30,
        recorder: PluginMicrophoneRecorder.new,
      ),
    );
    final text = switch (outcome) {
      LabeebSampleRecorded(:final file, :final duration) => () {
        final bytes = file.lengthSync();
        file.deleteSync();
        return 'recorded ${(duration.inMilliseconds / 1000).toStringAsFixed(1)} s, '
            '$bytes bytes WAV (deleted, not uploaded)';
      }(),
      LabeebSampleDenied() => 'microphone permission denied',
      LabeebSampleFailed() => 'recorder failed',
      _ => 'cancelled',
    };
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const Key('dev_record_sample_result'),
          content: Text('Voice sample: $text'),
        ),
      );
    }
  }

  Future<void> _show(BuildContext context, ClientToolResult r) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${r.toolId}: ${r.status.name}'),
          content: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(r.toJson()),
              key: const Key('dev_tool_result'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final actions = client.deviceActions;
    final theme = Theme.of(context);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        key: const Key('dev_client_tools'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Client tools', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Runs the real device flows. Results stay on the device: the '
            'backend has no client-tool result API yet.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const Key('dev_test_record_sample'),
                onPressed: () => _recordSample(context),
                icon: const Icon(Icons.mic_none_rounded),
                label: const Text('Voice sample (local)'),
              ),
              OutlinedButton.icon(
                key: const Key('dev_test_location'),
                onPressed: () async {
                  final r = await actions.shareLocation(context);
                  if (context.mounted) await _show(context, r);
                },
                icon: const Icon(Icons.my_location_rounded),
                label: const Text('Test location'),
              ),
              OutlinedButton.icon(
                key: const Key('dev_test_camera'),
                onPressed: () async {
                  final r = await actions.takePhoto(context);
                  if (context.mounted) await _show(context, r);
                },
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Test camera'),
              ),
              OutlinedButton.icon(
                key: const Key('dev_sample_places'),
                onPressed: () {
                  actions.showPlaces(samplePlaces());
                  Navigator.of(context).maybePop();
                },
                icon: const Icon(Icons.place_outlined),
                label: const Text('Sample places card'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
