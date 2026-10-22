// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'nexa_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class NexaLocalizationsEn extends NexaLocalizations {
  NexaLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get chatTitle => 'Assistant';

  @override
  String get composerHint => 'Message';

  @override
  String get send => 'Send';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get stopGenerating => 'Stop';

  @override
  String get endSession => 'End chat';

  @override
  String get connecting => 'Connecting…';

  @override
  String get thinking => 'Thinking…';

  @override
  String get assistantTyping => 'Assistant is typing';

  @override
  String get messageFailed => 'Couldn\'t send this message.';

  @override
  String get messageCancelled => 'Stopped.';

  @override
  String get sessionEnded => 'This chat has ended.';

  @override
  String get sessionEndedQuota =>
      'You\'ve reached the usage limit for this chat.';

  @override
  String get sessionError => 'Something went wrong. Please try again.';

  @override
  String get offline =>
      'You\'re offline. Messages will fail until you reconnect.';

  @override
  String quotaWarning(int remaining) {
    return '$remaining messages left';
  }

  @override
  String get toolRunning => 'Working on it…';

  @override
  String get toolFailed => 'This step failed.';

  @override
  String get toolCancelled => 'Cancelled.';

  @override
  String get invalidResult =>
      'The assistant returned something we couldn\'t display.';

  @override
  String get confirm => 'Confirm';

  @override
  String get decline => 'Cancel';

  @override
  String get submit => 'Submit';

  @override
  String get requiredField => 'Required';

  @override
  String get selectOne => 'Choose one';

  @override
  String get selectMany => 'Choose one or more';

  @override
  String get openNow => 'Open now';

  @override
  String get closed => 'Closed';

  @override
  String distanceKm(String km) {
    return '$km km';
  }

  @override
  String distanceM(int m) {
    return '$m m';
  }

  @override
  String routeSummary(String distance, int minutes) {
    return '$distance · $minutes min';
  }

  @override
  String weatherFeelsLike(int temp) {
    return 'Feels like $temp°';
  }

  @override
  String weatherHumidity(int percent) {
    return 'Humidity $percent%';
  }

  @override
  String weatherWind(int kph) {
    return 'Wind $kph km/h';
  }

  @override
  String get permissionMicrophoneTitle => 'Microphone access';

  @override
  String get permissionMicrophoneBody =>
      'Allow microphone access to talk with the assistant.';

  @override
  String get permissionAllow => 'Allow';

  @override
  String get permissionDeny => 'Not now';

  @override
  String get mediaPlay => 'Play';

  @override
  String semanticsUserMessage(String text) {
    return 'You said: $text';
  }

  @override
  String semanticsAssistantMessage(String text) {
    return 'Assistant said: $text';
  }

  @override
  String get semanticsSendButton => 'Send message';

  @override
  String get semanticsStopButton => 'Stop generating';

  @override
  String get poweredBy => 'Powered by NEXA';

  @override
  String get reconnecting => 'Reconnecting…';

  @override
  String get connected => 'Connected';

  @override
  String get authError => 'We couldn\'t verify your access. Please try again.';

  @override
  String get sessionExpired => 'Your session expired. Start again to continue.';

  @override
  String get rateLimited => 'Too many requests. Please wait a moment.';

  @override
  String get jumpToLatest => 'Jump to latest';

  @override
  String get semanticsAssistantResponding => 'Assistant is responding';

  @override
  String get semanticsAssistantFinished => 'Assistant finished responding';

  @override
  String get semanticsMessageFailed => 'Message failed to send';
}
