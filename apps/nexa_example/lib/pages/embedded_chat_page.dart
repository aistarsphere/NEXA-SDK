import 'package:flutter/material.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// The chat embedded under a host-owned header.
class EmbeddedChatPage extends StatelessWidget {
  const EmbeddedChatPage({required this.client, super.key});

  final NexaClient client;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order #4821 — help')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Text(
              'Host banner: delivery is running 10 minutes late.',
            ),
          ),
          Expanded(
            child: client.chatView(
              key: const Key('embedded_chat'),
              showEndAction: true,
              onEnded: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
