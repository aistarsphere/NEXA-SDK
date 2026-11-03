import 'package:flutter/material.dart';

/// The host's brand as shown by `NexaClient.assistantView`. The SDK itself
/// is brand-neutral: name, subtitle and logo always come from the host.
@immutable
final class NexaBrand {
  const NexaBrand({
    required this.name,
    this.localizedNames = const {},
    this.subtitle,
    this.localizedSubtitles = const {},
    this.logoBuilder,
    this.monogram,
  });

  /// Brand name (fallback for languages without a [localizedNames] entry).
  final String name;

  /// Brand name per language code, e.g. `{'ar': 'لبيب'}`.
  final Map<String, String> localizedNames;

  /// Short line under the name (optional), with per-language variants.
  final String? subtitle;
  final Map<String, String> localizedSubtitles;

  /// Builds the logo at [size] logical pixels. When null (or when it
  /// returns null), [NexaBrandMark] shows a text fallback.
  final Widget? Function(BuildContext context, double size)? logoBuilder;

  /// Text of the fallback mark (default: first letter of the name).
  final String? monogram;

  String nameFor(String languageCode) => localizedNames[languageCode] ?? name;

  String? subtitleFor(String languageCode) =>
      localizedSubtitles[languageCode] ?? subtitle;
}

/// What `assistantView` opens with.
enum NexaLaunchMode {
  /// The conversation, with live voice one tap away.
  chat,

  /// Live voice only: no text chat surface.
  voice,

  /// A home screen with the brand and both entry points.
  home,

  /// The conversation list is the root screen. The host router shows
  /// [NexaAssistantView.listPage]; the view itself falls back to the chat.
  list,
}

/// Host-controlled visibility of assistant features. These can only **hide**
/// features: a feature also needs its capability requested in `NexaConfig`,
/// and the backend still enforces what the session is allowed to do.
@immutable
final class NexaAssistantFeatures {
  const NexaAssistantFeatures({
    this.voice = true,
    this.newConversation = true,
    this.suggestions = true,
    this.history = true,
  });

  /// Live voice entry points (header, composer, home).
  final bool voice;

  /// The "new conversation" action.
  final bool newConversation;

  /// Tappable first messages in an empty conversation.
  final bool suggestions;

  /// The history action (only when the host enabled `NexaHistoryOptions`).
  final bool history;
}

/// The brand's logo, or a text fallback tile when no logo is provided.
class NexaBrandMark extends StatelessWidget {
  const NexaBrandMark({required this.brand, this.size = 36, super.key});

  final NexaBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = brand.logoBuilder?.call(context, size);
    if (logo != null) {
      return SizedBox.square(
        key: const Key('nexa_brand_logo'),
        dimension: size,
        child: logo,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    final name = brand.nameFor(lang);
    final text = brand.monogram ?? (name.isEmpty ? '?' : name.characters.first);
    return Container(
      key: const Key('nexa_brand_fallback'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(size / 3),
          topEnd: Radius.circular(size / 2),
          bottomStart: Radius.circular(size / 2),
          bottomEnd: Radius.circular(size / 2),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.45,
          height: 1,
        ),
      ),
    );
  }
}
