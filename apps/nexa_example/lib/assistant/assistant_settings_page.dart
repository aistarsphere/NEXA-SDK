import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexa_example/assistant/app_strings.dart';
import 'package:nexa_example/assistant/device_assistant.dart';
import 'package:nexa_example/assistant/device_assistant_strings.dart';
import 'package:nexa_example/dev/dev_client_tools_section.dart';
import 'package:nexa_example/dev/dev_token_section.dart';
import 'package:nexa_example/dev/qa/dev_qa_section.dart';
import 'package:nexa_example/dev/qa/qa_recorder.dart';
import 'package:nexa_example/dev/wake_benchmark_page.dart';
import 'package:nexa_example/dev_token_auth_provider.dart';
import 'package:nexa_example/example_config.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// User settings: language and appearance, what the app does and does not
/// keep, and (development builds only) the developer section.
class AssistantSettingsPage extends StatelessWidget {
  const AssistantSettingsPage({
    required this.client,
    required this.auth,
    this.qa,
    this.device,
    super.key,
  });

  final NexaClient client;
  final NexaAuthProvider auth;

  /// Android assistant integration (null where unsupported).
  final DeviceAssistant? device;

  /// Development builds only: the QA diagnostics store.
  final QaRecorder? qa;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ValueListenableBuilder(
        valueListenable: client.uiSettings,
        builder: (context, settings, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _SectionLabel(s.language),
            SegmentedButton<String>(
              key: const Key('settings_language'),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ar', label: Text('العربية')),
              ],
              selected: {settings.languageTag},
              onSelectionChanged: (v) => client.setLanguage(v.first),
            ),
            _SectionLabel(s.appearance),
            _AppearanceSelector(client: client, settings: settings),
            if (client.host.theme != null) ...[
              const SizedBox(height: 12),
              _ColorThemeTile(client: client),
            ],
            if (device?.supported ?? false) ...[
              _SectionLabel(
                DeviceAssistantStrings.of(context).defaultAssistant,
              ),
              Card(
                child: ListTile(
                  key: const Key('settings_device_assistant'),
                  leading: Icon(
                    Icons.assistant_outlined,
                    color: scheme.primary,
                  ),
                  title: Text(DeviceAssistantStrings.of(context).title),
                  subtitle: Text(
                    DeviceAssistantStrings.of(context).entrySubtitle,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/settings/assistant'),
                ),
              ),
            ],
            _SectionLabel(s.conversations),
            _InfoCard(
              icon: Icons.history_rounded,
              child: Text(
                client.history?.serverBacked ?? false
                    ? s.historyServer
                    : s.historyUnavailable,
              ),
            ),
            _SectionLabel(s.privacy),
            Card(
              child: ListTile(
                key: const Key('settings_delete_data'),
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: scheme.error,
                ),
                title: Text(s.deleteData),
                onTap: () => _deleteData(context),
              ),
            ),
            _SectionLabel(s.about),
            _InfoCard(
              icon: Icons.auto_awesome_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.appName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.version(ExampleConfig.appVersion),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(s.privacyNote),
                ],
              ),
            ),
            if (ExampleConfig.devTools) ..._developer(context, s),
          ],
        ),
      ),
    );
  }

  /// `DELETE /me/assistant-data` after an explicit confirmation; then a
  /// fresh conversation, since the old one no longer exists.
  Future<void> _deleteData(BuildContext context) async {
    final s = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteData),
        content: Text(s.deleteDataBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('settings_delete_data_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await client.api.deleteAssistantData();
      await client.history?.refresh();
      await client.newConversation();
      messenger.showSnackBar(SnackBar(content: Text(s.deleteDataDone)));
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(s.deleteDataFailed)));
    }
  }

  List<Widget> _developer(BuildContext context, AppStrings s) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      color: scheme.onSurfaceVariant,
    );
    const mode = ExampleConfig.useMock
        ? 'mock transport'
        : ExampleConfig.realBackend
        ? 'real NEXA backend'
        : 'reference gateway';
    return [
      _SectionLabel(s.developer),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          s.developerOnly,
          style: theme.textTheme.bodySmall?.copyWith(
            color: NexaColors.of(context).warning,
          ),
        ),
      ),
      if (auth case final DevTokenAuthProvider dev)
        _InfoCard(
          icon: Icons.key_rounded,
          child: DevTokenSection(auth: dev),
        ),
      const SizedBox(height: 8),
      _InfoCard(
        icon: Icons.monitor_heart_outlined,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            key: const Key('settings_diagnostics'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.diagnostics, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text('mode: $mode', style: mono),
              Text('gateway: ${ExampleConfig.gatewayUri}', style: mono),
              Text('app: ${ExampleConfig.applicationId}', style: mono),
              Text(
                'session: ${client.currentSession?.sessionId.value ?? 'none'}',
                style: mono,
              ),
              Text('sdk: $nexaSdkVersion', style: mono),
              Text(
                'installation: ${client.installation.id}',
                key: const Key('settings_installation_id'),
                style: mono,
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      _InfoCard(
        icon: Icons.build_circle_outlined,
        child: DevClientToolsSection(client: client),
      ),
      if (qa case final QaRecorder qa) ...[
        const SizedBox(height: 8),
        _InfoCard(
          icon: Icons.fact_check_outlined,
          child: DevQaSection(qa: qa),
        ),
      ],
      if (device case final DeviceAssistant d when d.supported) ...[
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            key: const Key('settings_wake_benchmark'),
            leading: const Icon(Icons.graphic_eq_rounded),
            title: const Text('Wake-word benchmark (dev)'),
            subtitle: const Text(
              'Record labelled clips for offline comparison',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => WakeBenchmarkPage(plugin: d.plugin),
              ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      Card(
        child: ListTile(
          key: const Key('settings_playground'),
          leading: const Icon(Icons.science_outlined),
          title: Text(s.playground),
          subtitle: Text(s.playgroundBody),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.go('/dev'),
        ),
      ),
    ];
  }
}

/// Light / dark / system. With a host theme controller it is the single
/// source (persisted with the palette); otherwise the SDK setting.
class _AppearanceSelector extends StatelessWidget {
  const _AppearanceSelector({required this.client, required this.settings});

  final NexaClient client;
  final NexaUiSettings settings;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = client.host.theme;
    Widget selector(NexaThemeMode selected) => SegmentedButton<NexaThemeMode>(
      key: const Key('settings_theme'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: NexaThemeMode.system,
          icon: const Icon(Icons.brightness_auto_rounded),
          label: Text(s.system),
        ),
        ButtonSegment(
          value: NexaThemeMode.light,
          icon: const Icon(Icons.light_mode_rounded),
          label: Text(s.light),
        ),
        ButtonSegment(
          value: NexaThemeMode.dark,
          icon: const Icon(Icons.dark_mode_rounded),
          label: Text(s.dark),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (v) {
        if (theme == null) {
          client.setThemeMode(v.first);
        } else {
          theme.apply(theme.appliedPaletteId, switch (v.first) {
            NexaThemeMode.light => NexaAppearance.light,
            NexaThemeMode.dark => NexaAppearance.dark,
            NexaThemeMode.system => NexaAppearance.system,
          });
        }
      },
    );
    if (theme == null) return selector(settings.themeMode);
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) => selector(switch (theme.appliedAppearance) {
        NexaAppearance.light => NexaThemeMode.light,
        NexaAppearance.dark => NexaThemeMode.dark,
        NexaAppearance.system => NexaThemeMode.system,
      }),
    );
  }
}

/// Opens the SDK theme picker (palette preview, Apply / Cancel / Reset).
class _ColorThemeTile extends StatelessWidget {
  const _ColorThemeTile({required this.client});

  final NexaClient client;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final theme = client.host.theme!;
    final lang = Localizations.localeOf(context).languageCode;
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: theme,
      builder: (context, _) {
        final current = theme.palettes
            .where((p) => p.id == theme.appliedPaletteId)
            .firstOrNull;
        return Card(
          child: ListTile(
            key: const Key('settings_color_theme'),
            leading: Icon(Icons.palette_outlined, color: scheme.primary),
            title: Text(s.colorTheme),
            subtitle: current == null ? null : Text(current.labelFor(lang)),
            trailing: const Icon(Icons.chevron_right_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            onTap: () => client.showThemePicker(context),
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(4, 24, 4, 10),
    child: Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: Theme.of(context).textTheme.bodyMedium,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
