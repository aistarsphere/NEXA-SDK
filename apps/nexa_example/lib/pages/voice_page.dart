import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_permission_handler.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// Host page embedding the Live Voice Capsule.
///
/// Journey demonstrated (see the event log at the bottom):
/// 1. SDK already initialised by `main`.
/// 2. `client.voice.start()` → microphone permission (host handler) →
///    `POST .../voice` on the gateway → scoped LiveKit grant.
/// 3. The SDK joins the LiveKit room and publishes the microphone.
/// 4. Agent audio (synthetic, mock agent) is received and played.
/// 5. Signed agent events drive the capsule states.
/// 6. Mute/unmute, network recovery (engine reconnect), end.
///
/// The SDK never pushes routes: this page is the host's own route.
class VoicePage extends StatefulWidget {
  const VoicePage({required this.client, super.key});

  final NexaClient client;

  @override
  State<VoicePage> createState() => _VoicePageState();
}

class _VoicePageState extends State<VoicePage> {
  final List<String> _log = [];
  StreamSubscription<NexaVoiceEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.client.voice.events.listen((e) {
      final line = switch (e) {
        NexaVoicePhaseChanged(:final from, :final to) =>
          'state ${from.name} → ${to.name}',
        NexaVoiceTranscriptUpdated(:final entry) =>
          '${entry.speaker.name}: ${entry.text}${entry.isFinal ? '' : ' …'}',
        NexaVoiceAgentPresence(:final identity, :final present) =>
          'agent $identity ${present ? 'joined' : 'left'}',
        NexaVoiceMuteChanged(:final muted) => muted ? 'muted' : 'unmuted',
        NexaVoiceErrorOccurred(:final error) => 'error ${error.code.name}',
        NexaVoiceEventRejected(:final reason) => 'REJECTED event: $reason',
        NexaVoiceEnded(:final reason) => 'ended ($reason)',
      };
      if (!mounted) return;
      setState(() {
        _log.insert(0, line);
        if (_log.length > 40) _log.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Leaving the page ends the call; the controller itself lives with the
    // client so a host could also keep the call running in the background.
    widget.client.voice.end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mode = ExampleConfig.useMock
        ? 'MOCK transport (no LiveKit, no gateway)'
        : 'reference gateway + local LiveKit (mock agent, synthetic audio)';
    return Scaffold(
      appBar: AppBar(title: const Text('Live voice (host page)')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: ExampleConfig.useMock
                ? Colors.orange.shade100
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Text(
              'Mode: $mode',
              key: const Key('voice_mode_banner'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          Expanded(
            flex: 3,
            child: widget.client.voiceView(
              key: const Key('voice_view'),
              onOpenSettings: HostPermissionHandler.openSettings,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: ValueListenableBuilder<NexaVoiceState>(
              valueListenable: widget.client.voice.state,
              builder: (context, s, _) => ListView(
                key: const Key('voice_event_log'),
                padding: const EdgeInsets.all(12),
                children: [
                  Text(
                    'phase=${s.phase.name} muted=${s.muted} '
                    'agent=${s.agentPresent ? s.agentIdentity : 'absent'} '
                    'verified=${s.eventsVerified} rejected=${s.rejectedEvents}',
                    key: const Key('voice_status_line'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  for (final line in _log)
                    Text(line, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
