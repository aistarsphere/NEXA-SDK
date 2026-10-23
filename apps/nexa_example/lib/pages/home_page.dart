import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

class HomePage extends StatefulWidget {
  const HomePage({required this.client, required this.auth, super.key});

  final NexaClient client;
  final HostAuthProvider auth;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _gatewayStatus = 'checking…';

  @override
  void initState() {
    super.initState();
    _checkGateway();
  }

  Future<void> _checkGateway() async {
    if (ExampleConfig.useMock) {
      setState(() => _gatewayStatus = 'MOCK transport (no server)');
      return;
    }
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 3);
    try {
      final req = await http.getUrl(
        ExampleConfig.gatewayUri.resolve('/healthz'),
      );
      final res = await req.close();
      final body =
          jsonDecode(await utf8.decodeStream(res)) as Map<String, Object?>;
      if (!mounted) return;
      setState(
        () => _gatewayStatus =
            'reference gateway ${body['contract_version']} reachable',
      );
    } on Object catch (e) {
      if (!mounted) return;
      setState(
        () => _gatewayStatus =
            'unreachable (${e.runtimeType}) — run `make gateway`',
      );
    } finally {
      http.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host app')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'This screen belongs to the host. Everything below the buttons is '
            'the NEXA SDK.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('open_chat'),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Open support chat (modal)'),
            onPressed: () => widget.client.openChat(context),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('open_embedded'),
            icon: const Icon(Icons.view_agenda_outlined),
            label: const Text('Embedded chat page'),
            onPressed: () => context.go('/embedded'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('open_voice'),
            icon: const Icon(Icons.mic_rounded),
            label: const Text('Live voice page'),
            onPressed: () => context.go('/voice'),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.tune),
            label: const Text('SDK settings (language / theme / token TTL)'),
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Backend',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text('Gateway: ${ExampleConfig.gatewayUri}'),
                  Text(
                    'Status: $_gatewayStatus',
                    key: const Key('gateway_status'),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder(
                    valueListenable: widget.client.uiSettings,
                    builder: (context, settings, _) => Text(
                      'SDK language: ${settings.languageTag} · '
                      'session: ${widget.client.currentSession?.sessionId.value ?? 'none'} · '
                      'tokens issued by host backend: ${widget.auth.issued}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      setState(() => _gatewayStatus = 'checking…');
                      _checkGateway();
                    },
                    child: const Text('Re-check'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scripted scenarios (type a keyword): "long", "slow" (then Stop), '
            '"fail", "reject", "interrupt" (stream dropped → reconnect), '
            '"duplicate", "ratelimit" (429 → Retry), "quota", "expire", '
            '"weather", "book", "mic".',
          ),
        ],
      ),
    );
  }
}
