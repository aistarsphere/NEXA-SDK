import 'package:flutter/material.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Wraps [child] in a localised, themed MaterialApp for widget tests.
Widget harness(
  Widget child, {
  Locale locale = const Locale('en'),
  Brightness brightness = Brightness.light,
  bool reducedMotion = false,
}) {
  return MaterialApp(
    locale: locale,
    supportedLocales: NexaLocale.supported,
    localizationsDelegates: NexaLocale.delegates,
    theme: NexaTheme.forBrightness(brightness, locale),
    builder: (context, app) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
      child: app!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}
