import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';

/// Light / dark / follow the system.
enum NexaAppearance { light, dark, system }

/// A palette the host offers. [swatches] are only painted inside the
/// palette's own preview swatch (design rule); the SDK never builds
/// ThemeData from them.
@immutable
final class NexaThemeOption {
  const NexaThemeOption({
    required this.id,
    required this.label,
    required this.swatches,
    this.localizedLabels = const {},
  });

  /// Stable id (`pal_ruby`), used by touch, text and voice selection.
  final String id;
  final String label;
  final Map<String, String> localizedLabels;
  final List<Color> swatches;

  String labelFor(String languageCode) =>
      localizedLabels[languageCode] ?? label;
}

/// The host app's theme controls. The SDK calls these; the host owns its
/// ThemeData, persistence and what "original" means.
abstract interface class NexaHostThemeController implements Listenable {
  List<NexaThemeOption> get palettes;
  String get appliedPaletteId;
  NexaAppearance get appliedAppearance;

  /// Temporary, app-wide preview; [cancelPreview] restores the applied one.
  Future<bool> preview(String paletteId, NexaAppearance appearance);
  Future<bool> cancelPreview();

  /// Commits and persists.
  Future<bool> apply(String paletteId, NexaAppearance appearance);

  /// Back to the host's original appearance (persisted).
  Future<bool> reset();

  /// Previews a server-resolved palette (`app.theme.apply` arguments:
  /// `palette_id`, `colors`, `mode`). False when the host cannot show it.
  Future<bool> previewSpec(NexaThemeSpec spec);

  /// Commits and persists a server-resolved palette (after the user
  /// confirmed). False when the host refused it.
  Future<bool> applySpec(NexaThemeSpec spec);
}

/// A palette resolved by the server (contract `theme.palettes`): an id,
/// role colors (`primary`, `on_primary`, `secondary`, `surface`, …) and
/// light/dark/system. The host maps roles onto its own ThemeData.
@immutable
final class NexaThemeSpec {
  const NexaThemeSpec({
    required this.paletteId,
    this.colors = const {},
    this.appearance = NexaAppearance.system,
  });

  final String paletteId;
  final Map<String, Color> colors;
  final NexaAppearance appearance;
}

/// Capabilities the host grants the assistant. Absent = unavailable (the
/// surface shows Unavailable; the AWS orchestrator is told nothing).
@immutable
final class NexaHostCapabilities {
  const NexaHostCapabilities({this.theme, this.uiComponents = const {}});
  final NexaHostThemeController? theme;

  /// Host renderers for `nexa.ui/1` component types beyond the standard
  /// set (extension types agreed with the backend). Keyed by `type`.
  /// They render with the host's design system and can only answer
  /// through [NexaUiComponentContext.send] (a validated `ui_event`).
  final Map<String, NexaUiComponentBuilder> uiComponents;
}

/// Builds a host-rendered `nexa.ui/1` component.
typedef NexaUiComponentBuilder =
    Widget Function(BuildContext context, NexaUiComponentContext component);

/// What a host renderer gets: the node (props, options, children) and the
/// only way to act on it.
final class NexaUiComponentContext {
  const NexaUiComponentContext({
    required this.node,
    required this.languageCode,
    required this.send,
    required this.buildChild,
  });

  final NexaUiNode node;
  final String languageCode;

  /// Sends a `ui_event` for this component (`event` defaults to the
  /// action's). Returns the gateway refusal code, null when accepted.
  final Future<String?> Function({
    String? action,
    String? event,
    List<String>? optionIds,
    Object? value,
  })
  send;

  /// Renders a child node with the SDK renderer (standard or host types).
  final Widget Function(NexaUiNode child) buildChild;
}

String _appearanceWire(NexaAppearance a) => a.name;
NexaAppearance? appearanceFromWire(Object? v) =>
    NexaAppearance.values.where((a) => a.name == v).firstOrNull;

/// Builds the theme choice surface (design "Theme choice surface") from the
/// host's palettes: the same schema the orchestrator will send, so touch
/// now and AI/voice later share one renderer and one event model.
NexaSurface buildThemeSurface(
  NexaHostThemeController theme, {
  required String languageCode,
  String surfaceId = 'srf_theme_local',
  NexaPresentation presentation = NexaPresentation.bottomSheet,
}) {
  final ar = languageCode == 'ar';
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  final palettes = theme.palettes;
  return parseNexaSurface({
    'schema_version': '1.0',
    'surface_id': surfaceId,
    'category': 'themes_appearance',
    'presentation': presentation.wire,
    'title': ar ? 'اختر مظهر التطبيق' : 'Choose your app theme',
    'fallback_text': [
      for (final (i, p) in palettes.indexed)
        '${i + 1} ${p.labelFor(languageCode)}',
    ].join(', '),
    'status': {'state': 'ready'},
    'components': [
      {
        'type': 'palette_choice',
        'id': 'c_palette',
        'a11y_label': ar ? 'ألوان المظهر' : 'Color themes',
        'value': theme.appliedPaletteId,
        'choices': [
          for (final (i, p) in palettes.indexed)
            {
              'id': p.id,
              'order': i + 1,
              'label': p.labelFor(languageCode),
              'swatches': [for (final c in p.swatches) hex(c)],
            },
        ],
      },
      {
        'type': 'segmented',
        'id': 'c_appearance',
        'a11y_label': ar ? 'الوضع' : 'Appearance',
        'value': _appearanceWire(theme.appliedAppearance),
        'choices': [
          {'id': 'light', 'order': 1, 'label': ar ? 'فاتح' : 'Light'},
          {'id': 'dark', 'order': 2, 'label': ar ? 'داكن' : 'Dark'},
          {'id': 'system', 'order': 3, 'label': ar ? 'النظام' : 'System'},
        ],
      },
    ],
    'actions': [
      {
        'id': 'a_apply',
        'type': 'host.theme.apply',
        'label': ar ? 'تطبيق' : 'Apply',
        'requires_confirmation': true,
        'params_from': ['c_palette', 'c_appearance'],
      },
      {'id': 'a_cancel', 'type': 'cancel', 'label': ar ? 'إلغاء' : 'Cancel'},
      {
        'id': 'a_reset',
        'type': 'host.theme.reset',
        'label': ar ? 'إعادة الضبط' : 'Reset',
        'requires_confirmation': true,
      },
    ],
  })!;
}

// ------------------------------------------------------------ client tools

ClientToolDescriptor _themeDescriptor(
  String id,
  String title,
  List<String> paletteIds, {
  required bool approval,
  bool params = true,
}) => ClientToolDescriptor(
  id: id,
  version: 1,
  title: title,
  requiresApproval: approval,
  sensitivity: ClientToolSensitivity.low,
  timeout: const Duration(seconds: 30),
  inputSchema: {
    'type': 'object',
    'additionalProperties': false,
    if (params) 'required': const ['palette_id'],
    if (params)
      'properties': {
        'palette_id': {'type': 'string', 'enum': paletteIds},
        'appearance': {
          'type': 'string',
          'enum': const ['light', 'dark', 'system'],
        },
      },
  },
  outputSchema: const {
    'type': 'object',
    'required': ['applied'],
    'properties': {
      'applied': {'type': 'boolean'},
      'palette_id': {'type': 'string'},
      'appearance': {'type': 'string'},
    },
  },
);

/// `host.theme.preview` / `host.theme.apply` / `host.theme.reset` v1:
/// registered only when the host provides a theme controller.
final class HostThemeTool implements ClientToolExecutor {
  HostThemeTool._(this.theme, this.descriptor, this._run);

  static const previewId = 'host.theme.preview';
  static const applyId = 'host.theme.apply';
  static const resetId = 'host.theme.reset';

  static List<HostThemeTool> forHost(NexaHostThemeController theme) {
    final ids = [for (final p in theme.palettes) p.id];
    Future<bool> withParams(
      ClientToolRequest r,
      Future<bool> Function(String, NexaAppearance) f,
    ) => f(
      r.arguments['palette_id']! as String,
      appearanceFromWire(r.arguments['appearance']) ?? theme.appliedAppearance,
    );
    return [
      HostThemeTool._(
        theme,
        _themeDescriptor(previewId, 'Preview theme', ids, approval: false),
        (r) => withParams(r, theme.preview),
      ),
      HostThemeTool._(
        theme,
        _themeDescriptor(applyId, 'Apply theme', ids, approval: true),
        (r) => withParams(r, theme.apply),
      ),
      HostThemeTool._(
        theme,
        _themeDescriptor(
          resetId,
          'Reset theme',
          ids,
          approval: true,
          params: false,
        ),
        (_) => theme.reset(),
      ),
    ];
  }

  final NexaHostThemeController theme;
  @override
  final ClientToolDescriptor descriptor;
  final Future<bool> Function(ClientToolRequest) _run;

  @override
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final ok = await _run(request);
    if (!ok) {
      return ClientToolResult.failure(
        request,
        const ClientToolError(ClientToolErrorCode.deviceError, 'host refused'),
      );
    }
    return ClientToolResult.success(request, {
      'applied': descriptor.id != previewId,
      'palette_id': theme.appliedPaletteId,
      'appearance': theme.appliedAppearance.name,
    });
  }
}
