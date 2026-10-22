import 'package:flutter/material.dart';
import 'package:nexa_example/host_auth_provider.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({required this.client, required this.auth, super.key});

  final NexaClient client;
  final HostAuthProvider auth;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final client = widget.client;
    return Scaffold(
      appBar: AppBar(title: const Text('SDK settings')),
      body: ValueListenableBuilder(
        valueListenable: client.uiSettings,
        builder: (context, settings, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Language'),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ar', label: Text('العربية')),
              ],
              selected: {settings.languageTag},
              onSelectionChanged: (s) => client.setLanguage(s.first),
            ),
            const SizedBox(height: 24),
            const Text('Theme mode'),
            SegmentedButton<NexaThemeMode>(
              segments: const [
                ButtonSegment(
                  value: NexaThemeMode.system,
                  label: Text('System'),
                ),
                ButtonSegment(value: NexaThemeMode.light, label: Text('Light')),
                ButtonSegment(value: NexaThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => client.setThemeMode(s.first),
            ),
            const SizedBox(height: 24),
            const Text('Brand override (approved customisation point)'),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Mocha (default)'),
                  onPressed: () =>
                      client.setThemeOverrides(NexaThemeOverrides.none),
                ),
                ActionChip(
                  label: const Text('Indigo seed'),
                  onPressed: () => client.setThemeOverrides(
                    const NexaThemeOverrides(seedColor: Colors.indigo),
                  ),
                ),
                ActionChip(
                  label: const Text('Compact corners'),
                  onPressed: () => client.setThemeOverrides(
                    const NexaThemeOverrides(cornerScale: 0.6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Host backend: session token lifetime (demonstrates renewal '
              'after a 401; the SDK refreshes through NexaAuthProvider)',
            ),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 15 * 60, label: Text('15 min')),
                ButtonSegment(value: 20, label: Text('20 s')),
              ],
              selected: {widget.auth.tokenTtlSeconds},
              onSelectionChanged: (s) =>
                  setState(() => widget.auth.tokenTtlSeconds = s.first),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => client.endSession(),
              child: const Text('End session'),
            ),
          ],
        ),
      ),
    );
  }
}
