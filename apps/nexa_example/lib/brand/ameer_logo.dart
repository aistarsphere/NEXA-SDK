import 'package:flutter/material.dart';

/// The approved AMEER logo, drawn exactly as supplied: transparent
/// background, original colours, aspect ratio kept (never stretched, tinted or
/// given effects). Use this widget wherever the example application itself is
/// represented; other applications and tenants keep their own logos.
///
/// The asset is generated from `assets/new_logo.png` (the single source of
/// truth) by `tool/branding/generate_ameer_assets.py`.
class AmeerLogo extends StatelessWidget {
  const AmeerLogo({this.size = 40, this.semanticLabel = 'AMEER', super.key});

  /// Asset path (square canvas, transparent).
  static const asset = 'assets/brand/ameer_logo.png';

  /// Width and height of the square slot; the symbol is scaled to fit.
  final double size;

  /// Spoken name; null marks the logo decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    ),
  );
}
