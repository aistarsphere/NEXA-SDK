import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexa_example/brand/labeeb_palette.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// One LABEEB palette: 12 role colors per brightness, in the order of the
/// design prototype (`LABEEB Dynamic UI.dc.html`, `PAL`): background,
/// surface 1–3, outline variant, on-surface, on-surface variant, primary,
/// secondary, on-primary, primary container, on-primary container.
/// Positions 0–7 and 9–11 match the LABEEB design tokens; 8 has no token
/// and is used as `secondary`.
final class LabeebPaletteSpec {
  const LabeebPaletteSpec({
    required this.id,
    required this.en,
    required this.ar,
    required this.light,
    required this.dark,
  });

  final String id;
  final String en;
  final String ar;
  final List<int> light;
  final List<int> dark;

  ColorScheme scheme(Brightness b) {
    final r = [for (final v in b == Brightness.light ? light : dark) Color(v)];
    return ColorScheme.fromSeed(seedColor: r[7], brightness: b).copyWith(
      surface: r[0],
      surfaceContainerLowest: b == Brightness.light
          ? const Color(0xFFFFFFFF)
          : r[1],
      surfaceContainerLow: r[1],
      surfaceContainer: r[2],
      surfaceContainerHigh: r[3],
      surfaceContainerHighest: r[3],
      outlineVariant: r[4],
      onSurface: r[5],
      onSurfaceVariant: r[6],
      primary: r[7],
      secondary: r[8],
      onPrimary: r[9],
      primaryContainer: r[10],
      onPrimaryContainer: r[11],
    );
  }
}

/// The six palettes of the design (order = choice order).
const labeebPalettes = [
  LabeebPaletteSpec(
    id: 'pal_mocha',
    en: 'AMEER Mocha',
    ar: 'أمير موكا',
    light: [
      0xFFF7F3F0,
      0xFFFAF6F3,
      0xFFF4EDE8,
      0xFFEEE5DF,
      0xFFDDCEC4,
      0xFF211915,
      0xFF72635D,
      0xFF7B5A49,
      0xFF65493C,
      0xFFFFFFFF,
      0xFFEAD9CF,
      0xFF2E1C13,
    ],
    dark: [
      0xFF110D0B,
      0xFF161110,
      0xFF1B1512,
      0xFF251D18,
      0xFF3D2F28,
      0xFFF7EFEA,
      0xFFC0AEA5,
      0xFFBD9075,
      0xFFCF9E80,
      0xFF2A1A10,
      0xFF2C211B,
      0xFFF2DCCD,
    ],
  ),
  LabeebPaletteSpec(
    id: 'pal_ruby',
    en: 'Ruby red',
    ar: 'أحمر ياقوتي',
    light: [
      0xFFFBF3F2,
      0xFFFFF9F8,
      0xFFF8EAE8,
      0xFFF1DDDA,
      0xFFE6CBC7,
      0xFF2A1412,
      0xFF7A5651,
      0xFFA8322D,
      0xFF8C2622,
      0xFFFFFFFF,
      0xFFF7D9D6,
      0xFF410E0B,
    ],
    dark: [
      0xFF140B0A,
      0xFF1B1110,
      0xFF221514,
      0xFF2E1D1B,
      0xFF4A302D,
      0xFFFBEDEB,
      0xFFCDB0AC,
      0xFFFF9C93,
      0xFFFFB4AB,
      0xFF4A0F0B,
      0xFF4A1A16,
      0xFFFFDAD6,
    ],
  ),
  LabeebPaletteSpec(
    id: 'pal_sand',
    en: 'Warm neutral',
    ar: 'محايد دافئ',
    light: [
      0xFFF5F4F2,
      0xFFFAF9F8,
      0xFFEEECE9,
      0xFFE6E3DF,
      0xFFD3CFC8,
      0xFF1F1E1C,
      0xFF68645E,
      0xFF5F5A52,
      0xFF48443D,
      0xFFFFFFFF,
      0xFFE4E0D9,
      0xFF25221D,
    ],
    dark: [
      0xFF0F0F0E,
      0xFF151514,
      0xFF1A1A18,
      0xFF242321,
      0xFF3A3835,
      0xFFF2F0EC,
      0xFFB8B3AA,
      0xFFC4BCAE,
      0xFFD6CEC0,
      0xFF262219,
      0xFF2A2825,
      0xFFEAE4D8,
    ],
  ),
  LabeebPaletteSpec(
    id: 'pal_ocean',
    en: 'Ocean blue',
    ar: 'أزرق محيطي',
    light: [
      0xFFF1F5F9,
      0xFFF7FAFC,
      0xFFE8EFF5,
      0xFFDDE7F0,
      0xFFC5D4E1,
      0xFF121C25,
      0xFF506474,
      0xFF2F5F8A,
      0xFF244B6D,
      0xFFFFFFFF,
      0xFFD6E4F2,
      0xFF0B2538,
    ],
    dark: [
      0xFF0A1118,
      0xFF0F171F,
      0xFF141E28,
      0xFF1C2936,
      0xFF2F4254,
      0xFFE9F1F8,
      0xFFA9BCCB,
      0xFF8DB8DD,
      0xFFA8C9E8,
      0xFF0B2538,
      0xFF1B2D3D,
      0xFFD6E7F5,
    ],
  ),
  LabeebPaletteSpec(
    id: 'pal_forest',
    en: 'Forest green',
    ar: 'أخضر غابة',
    light: [
      0xFFF2F6F2,
      0xFFF8FAF8,
      0xFFE9F0E9,
      0xFFDFE8DF,
      0xFFC8D6C9,
      0xFF14201A,
      0xFF52665A,
      0xFF3B6B4C,
      0xFF2E563C,
      0xFFFFFFFF,
      0xFFDCEBDD,
      0xFF0C2616,
    ],
    dark: [
      0xFF0A100C,
      0xFF101712,
      0xFF151E17,
      0xFF1D2921,
      0xFF2F4236,
      0xFFEAF4EC,
      0xFFAABFB0,
      0xFFA3D1B0,
      0xFFBBE0C6,
      0xFF0C2616,
      0xFF1F3326,
      0xFFDCEFE0,
    ],
  ),
  LabeebPaletteSpec(
    id: 'pal_violet',
    en: 'Violet',
    ar: 'بنفسجي',
    light: [
      0xFFF6F3FA,
      0xFFFBF9FD,
      0xFFEEE9F6,
      0xFFE5DEF0,
      0xFFD2C8E3,
      0xFF1C1626,
      0xFF625873,
      0xFF6A55A0,
      0xFF554385,
      0xFFFFFFFF,
      0xFFE4DDF5,
      0xFF241A3D,
    ],
    dark: [
      0xFF100C16,
      0xFF16111D,
      0xFF1C1626,
      0xFF271F34,
      0xFF3E3452,
      0xFFF1ECF9,
      0xFFBCB2CE,
      0xFFC5B4F0,
      0xFFD6C9F5,
      0xFF2A1A52,
      0xFF2E2447,
      0xFFE8DEFA,
    ],
  ),
];

/// LABEEB's host theme controller: the app's single source of palette and
/// light/dark/system, with app-wide preview, apply (persisted), cancel and
/// reset. Registered with the SDK as a host capability; the SDK never
/// builds ThemeData.
final class LabeebThemeController extends ChangeNotifier
    implements NexaHostThemeController {
  LabeebThemeController._(this._file);

  static const originalPalette = 'pal_mocha';
  static const originalAppearance = NexaAppearance.system;

  /// Loads the persisted choice from [file] (missing/invalid: original).
  static Future<LabeebThemeController> load(File file) async {
    final c = LabeebThemeController._(file);
    try {
      if (file.existsSync()) {
        final j = jsonDecode(await file.readAsString()) as Map;
        final p = j['palette'];
        final a = appearanceFromWire(j['appearance']);
        if (j['colors'] case final Map<Object?, Object?> colors
            when p is String) {
          // A server palette (labeeb.sdk/1 `theme.palettes`).
          c._server[p] = {
            for (final MapEntry(:key, :value) in colors.entries)
              if (key is String && value is int) key: Color(value),
          };
          c._palette = p;
        } else if (labeebPalettes.any((s) => s.id == p)) {
          c._palette = p! as String;
        }
        if (a != null) c._appearance = a;
      }
    } on Object {
      // Unreadable preference: keep the original appearance.
    }
    return c;
  }

  final File _file;

  /// Server palettes seen in `app.theme.apply`: id → role colors.
  final Map<String, Map<String, Color>> _server = {};
  String _palette = originalPalette;
  NexaAppearance _appearance = originalAppearance;
  (String, NexaAppearance)? _preview;

  @override
  List<NexaThemeOption> get palettes => [
    for (final p in labeebPalettes)
      NexaThemeOption(
        id: p.id,
        label: p.en,
        localizedLabels: {'ar': p.ar},
        swatches: [
          Color(p.light[7]),
          Color(p.light[10]),
          Color(p.light[0]),
          Color(p.light[5]),
        ],
      ),
  ];

  @override
  String get appliedPaletteId => _palette;
  @override
  NexaAppearance get appliedAppearance => _appearance;

  bool get previewing => _preview != null;

  /// What the app shows now (preview wins).
  String get effectivePalette => _preview?.$1 ?? _palette;
  NexaAppearance get effectiveAppearance => _preview?.$2 ?? _appearance;

  ThemeMode get themeMode => switch (effectiveAppearance) {
    NexaAppearance.light => ThemeMode.light,
    NexaAppearance.dark => ThemeMode.dark,
    NexaAppearance.system => ThemeMode.system,
  };

  /// The color scheme + roles for [b] of the effective palette. Mocha keeps
  /// the exact LABEEB tokens.
  (ColorScheme, NexaColors) colors(Brightness b) {
    if (effectivePalette == originalPalette) {
      return b == Brightness.light
          ? (LabeebPalette.light, LabeebPalette.lightRoles)
          : (LabeebPalette.dark, LabeebPalette.darkRoles);
    }
    final server = _server[effectivePalette];
    if (server != null) {
      final scheme = _serverScheme(server, b);
      return (scheme, NexaColors.fromScheme(scheme));
    }
    final spec = labeebPalettes.firstWhere((p) => p.id == effectivePalette);
    final scheme = spec.scheme(b);
    return (scheme, NexaColors.fromScheme(scheme));
  }

  /// Maps server role colors (`primary`, `on_primary`, `secondary`,
  /// `surface`, light-mode values) onto a full scheme; dark mode keeps
  /// the seed's tonal palette so contrast holds.
  static ColorScheme _serverScheme(Map<String, Color> c, Brightness b) {
    final seed = c['primary'] ?? LabeebPalette.light.primary;
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    if (b == Brightness.dark) return base;
    return base.copyWith(
      primary: c['primary'],
      onPrimary: c['on_primary'],
      secondary: c['secondary'],
      surface: c['surface'],
    );
  }

  bool _known(String id) =>
      labeebPalettes.any((p) => p.id == id) || _server.containsKey(id);

  @override
  Future<bool> previewSpec(NexaThemeSpec spec) async {
    if (labeebPalettes.any((p) => p.id == spec.paletteId)) {
      return preview(spec.paletteId, spec.appearance);
    }
    if (spec.colors['primary'] == null) return false;
    _server[spec.paletteId] = spec.colors;
    return preview(spec.paletteId, spec.appearance);
  }

  @override
  Future<bool> applySpec(NexaThemeSpec spec) async {
    if (!labeebPalettes.any((p) => p.id == spec.paletteId)) {
      if (spec.colors['primary'] == null) return false;
      _server[spec.paletteId] = spec.colors;
    }
    return apply(spec.paletteId, spec.appearance);
  }

  @override
  Future<bool> preview(String paletteId, NexaAppearance appearance) async {
    if (!_known(paletteId)) return false;
    _preview = (paletteId, appearance);
    notifyListeners();
    return true;
  }

  @override
  Future<bool> cancelPreview() async {
    if (_preview == null) return true;
    _preview = null;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> apply(String paletteId, NexaAppearance appearance) async {
    if (!_known(paletteId)) return false;
    _palette = paletteId;
    _appearance = appearance;
    _preview = null;
    notifyListeners();
    await _save();
    return true;
  }

  @override
  Future<bool> reset() => apply(originalPalette, originalAppearance);

  Future<void> _save() async {
    await _file.parent.create(recursive: true);
    final server = _server[_palette];
    await _file.writeAsString(
      jsonEncode({
        'palette': _palette,
        'appearance': _appearance.name,
        if (server != null)
          'colors': {
            for (final MapEntry(:key, :value) in server.entries)
              key: value.toARGB32(),
          },
      }),
    );
  }
}
