import 'package:flutter/material.dart';
import 'package:nexa_sdk/src/features/chat/presentation/nexa_chat_view.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Full-screen chat with its own app bar. Pushed by `NexaClient.openChat`.
/// Hosts that want the chat inside their own scaffold use `chatView()`
/// instead.
class NexaChatScreen extends StatelessWidget {
  const NexaChatScreen({required this.view, super.key});

  final NexaChatView view;

  @override
  Widget build(BuildContext context) {
    // The view installs theme + localisations for its subtree; the app bar
    // needs them too, so wrap the scaffold with the same providers via a
    // builder inside the view's settings scope.
    return ValueListenableBuilder(
      valueListenable: view.settings,
      builder: (context, settings, _) {
        final locale = NexaLocale.fromTag(settings.languageTag);
        final brightness = MediaQuery.platformBrightnessOf(context);
        final theme = NexaTheme.forBrightness(
          brightness,
          locale,
          overrides: settings.themeOverrides,
        );
        return Localizations(
          locale: locale,
          delegates: NexaLocale.delegates,
          child: Directionality(
            textDirection: NexaLocale.directionOf(locale),
            child: Theme(
              data: theme,
              child: Builder(
                builder: (context) => Scaffold(
                  appBar: AppBar(
                    // The route is a fullscreenDialog, which would add a
                    // second, unlabelled close button; keep only ours.
                    automaticallyImplyLeading: false,
                    title: Text(NexaLocalizations.of(context).chatTitle),
                    actions: [
                      IconButton(
                        tooltip: NexaLocalizations.of(context).endSession,
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                  body: view,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
