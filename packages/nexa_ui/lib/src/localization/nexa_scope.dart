import 'package:flutter/material.dart';
import 'package:nexa_ui/src/localization/nexa_locale.dart';

/// Carries the SDK's locale, text direction and theme from [context] into
/// a route, dialog or sheet the SDK pushes on the **host's** navigator
/// (which may have no NEXA localisations and a different theme).
Widget nexaScoped(BuildContext context, Widget child) {
  final locale = Localizations.localeOf(context);
  final themes = InheritedTheme.capture(
    from: context,
    to: Navigator.of(context).context,
  );
  return Localizations.override(
    context: context,
    locale: locale,
    delegates: NexaLocale.delegates,
    child: Directionality(
      textDirection: NexaLocale.directionOf(locale),
      child: themes.wrap(child),
    ),
  );
}
