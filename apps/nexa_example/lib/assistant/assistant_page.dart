import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexa_example/assistant/app_strings.dart';
import 'package:nexa_example/brand/labeeb_brand.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_example/host_permission_handler.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// The LABEEB assistant. Chat, live voice, navigation between them and the
/// assistant header are the SDK's `assistantView`; the app supplies the
/// brand, launch mode, feature visibility and its settings screen, and
/// shows its own "not connected" state when it has no credential.
class AssistantPage extends StatelessWidget {
  const AssistantPage({
    required this.client,
    required this.auth,
    this.voiceRequests,
    super.key,
  });

  final NexaClient client;
  final NexaAuthProvider auth;

  /// Opens live voice (Android assistant gesture or «يا لبيب»).
  final Stream<void>? voiceRequests;

  bool get _connected => switch (auth) {
    final DevTokenAuthProvider dev => dev.hasToken && !dev.isExpired,
    _ => true,
  };

  @override
  Widget build(BuildContext context) {
    final a = auth;
    return a is DevTokenAuthProvider
        ? ListenableBuilder(
            listenable: a,
            builder: (context, _) => _body(context),
          )
        : _body(context);
  }

  Widget _body(BuildContext context) {
    if (!_connected) {
      return Scaffold(
        appBar: AppBar(
          titleSpacing: 16,
          title: Text(
            Labeeb.name(Localizations.localeOf(context).languageCode),
          ),
          actions: [
            IconButton(
              key: const Key('assistant_settings'),
              tooltip: AppStrings.of(context).settings,
              onPressed: () => context.push('/settings'),
              icon: const Icon(Icons.tune_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _NotConnected(auth: auth),
      );
    }
    return ValueListenableBuilder(
      valueListenable: Labeeb.profile,
      builder: (context, _, _) => _assistant(context),
    );
  }

  Widget _assistant(BuildContext context) {
    return client.assistantView(
      brand: Labeeb.brand,
      launchMode: ExampleConfig.launchMode,
      features: ExampleConfig.features,
      suggestions: AppStrings.suggestionsFor,
      onOpenSettings: () => context.push('/settings'),
      onOpenMicrophoneSettings: HostPermissionHandler.openSettings,
      headerBadge: ExampleConfig.devTools ? const _DevBadge() : null,
      voiceRequests: voiceRequests,
    );
  }
}

/// Marks development builds (design: the "DEMO" tag in the chat header).
class _DevBadge extends StatelessWidget {
  const _DevBadge();

  @override
  Widget build(BuildContext context) {
    final colors = NexaColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        'DEV',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// No credential: production builds explain why; development builds say
/// how to supply a short-lived SDK token from the secrets file.
class _NotConnected extends StatelessWidget {
  const _NotConnected({required this.auth});
  final NexaAuthProvider auth;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dev = auth is DevTokenAuthProvider
        ? auth as DevTokenAuthProvider
        : null;
    final expired = dev != null && dev.hasToken && dev.isExpired;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          key: const Key('assistant_not_connected'),
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    expired ? Icons.timer_off_rounded : Icons.key_off_rounded,
                    size: 30,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  expired ? s.tokenExpiredTitle : s.notConnectedTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ExampleConfig.devTools && dev != null
                      ? s.devTokenBody
                      : s.notConnectedBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (ExampleConfig.devTools && dev != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    key: const Key('assistant_dev_token_hint'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '--dart-define-from-file=~/.nexa/nexa_dev.json',
                      textDirection: TextDirection.ltr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
