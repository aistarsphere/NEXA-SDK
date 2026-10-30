import 'package:flutter/material.dart';
import 'package:nexa_example/dev/demo_surfaces.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// DEVELOPMENT ONLY: every Dynamic UI category and state rendered from demo
/// surfaces (labelled DEMO), plus the presentations and the theme picker.
/// Events stay local: nothing here is sent to a backend.
class DynamicUiGalleryPage extends StatefulWidget {
  const DynamicUiGalleryPage({required this.client, super.key});

  final NexaClient client;

  @override
  State<DynamicUiGalleryPage> createState() => _DynamicUiGalleryPageState();
}

class _DynamicUiGalleryPageState extends State<DynamicUiGalleryPage> {
  late final NexaSurfaceController _surfaces = NexaSurfaceController(
    host: widget.client.host,
    deviceActions: widget.client.deviceActions,
  );
  String? _lang;
  List<String> _ids = const [];
  List<String> _stateIds = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == _lang) return;
    _lang = lang;
    List<String> load(List<Map<String, Object?>> all) {
      final ids = <String>[];
      for (final j in all) {
        if (parseNexaSurface(j) case final s?) {
          _surfaces.upsert(s);
          ids.add(s.surfaceId);
        }
      }
      return ids;
    }

    // Themes: the host's real palettes (selecting previews the app), or
    // the Unavailable state when the host registered no theme controller.
    final host = widget.client.host.theme;
    _surfaces.upsert(
      host != null
          ? buildThemeSurface(
              host,
              languageCode: lang,
              surfaceId: 'demo_theme',
              presentation: NexaPresentation.inlineCard,
            )
          : parseNexaSurface({
              'schema_version': '1.0',
              'surface_id': 'demo_theme',
              'category': 'themes_appearance',
              'title': 'Theme',
              'fallback_text': '',
            })!,
    );
    _ids = ['demo_theme', ...load(demoSurfaces(arabic: lang == 'ar'))];
    _stateIds = load(demoStateSurfaces(arabic: lang == 'ar'));
  }

  @override
  void dispose() {
    _surfaces.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    final first = _ids[1];
    return Scaffold(
      appBar: AppBar(title: const Text('Dynamic UI gallery')),
      body: ListenableBuilder(
        listenable: _surfaces,
        builder: (context, _) => ListView(
          key: const Key('dui_gallery'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            label('Theme (host capability)'),
            FilledButton.tonalIcon(
              key: const Key('dui_gallery_theme'),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Open theme picker'),
              onPressed: () => widget.client.showThemePicker(context),
            ),
            label('Presentations'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in [
                  NexaPresentation.bottomSheet,
                  NexaPresentation.modal,
                  NexaPresentation.fullScreen,
                  NexaPresentation.floatingPanel,
                ])
                  OutlinedButton(
                    key: Key('dui_gallery_${p.wire}'),
                    onPressed: () =>
                        showNexaSurface(context, _surfaces, first, as: p),
                    child: Text(p.wire),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            NexaSurfaceExpandable(surfaceId: _ids[2], controller: _surfaces),
            label('Categories'),
            for (final id in _ids) ...[
              NexaSurfaceCard(surfaceId: id, controller: _surfaces),
              const SizedBox(height: 12),
            ],
            label('States'),
            for (final id in _stateIds) ...[
              NexaSurfaceCard(surfaceId: id, controller: _surfaces),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}
