import 'package:flutter/material.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';

/// DEVELOPMENT ONLY: read-only status of the SDK token loaded at build time
/// from the developer's secrets file (`--dart-define-from-file`, see the
/// example README). There is deliberately no way to type or paste a token in
/// the app, and production builds never load one (`ExampleConfig.devTools`).
class DevTokenSection extends StatelessWidget {
  const DevTokenSection({required this.auth, super.key});

  final DevTokenAuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SDK token (development)', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            !auth.hasToken
                ? 'Not configured'
                : auth.isExpired
                ? 'Expired · ${auth.expiresAt!.toIso8601String()}'
                : 'Loaded${auth.expiresAt == null ? '' : ' · expires ${auth.expiresAt!.toIso8601String()}'}',
            key: const Key('dev_token_status'),
          ),
          const SizedBox(height: 4),
          Text(
            'Set NEXA_DEV_SDK_TOKEN in your secrets file and rebuild with '
            '--dart-define-from-file.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
