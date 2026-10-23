import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'nexa_localizations_ar.dart';
import 'nexa_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of NexaLocalizations
/// returned by `NexaLocalizations.of(context)`.
///
/// Applications need to include `NexaLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/nexa_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: NexaLocalizations.localizationsDelegates,
///   supportedLocales: NexaLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the NexaLocalizations.supportedLocales
/// property.
abstract class NexaLocalizations {
  NexaLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static NexaLocalizations of(BuildContext context) {
    return Localizations.of<NexaLocalizations>(context, NexaLocalizations)!;
  }

  static const LocalizationsDelegate<NexaLocalizations> delegate =
      _NexaLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get chatTitle;

  /// No description provided for @composerHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get composerHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @stopGenerating.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopGenerating;

  /// No description provided for @endSession.
  ///
  /// In en, this message translates to:
  /// **'End chat'**
  String get endSession;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @assistantTyping.
  ///
  /// In en, this message translates to:
  /// **'Assistant is typing'**
  String get assistantTyping;

  /// No description provided for @messageFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send this message.'**
  String get messageFailed;

  /// No description provided for @messageCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped.'**
  String get messageCancelled;

  /// No description provided for @sessionEnded.
  ///
  /// In en, this message translates to:
  /// **'This chat has ended.'**
  String get sessionEnded;

  /// No description provided for @sessionEndedQuota.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the usage limit for this chat.'**
  String get sessionEndedQuota;

  /// No description provided for @sessionError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get sessionError;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Messages will fail until you reconnect.'**
  String get offline;

  /// No description provided for @quotaWarning.
  ///
  /// In en, this message translates to:
  /// **'{remaining} messages left'**
  String quotaWarning(int remaining);

  /// No description provided for @toolRunning.
  ///
  /// In en, this message translates to:
  /// **'Working on it…'**
  String get toolRunning;

  /// No description provided for @toolFailed.
  ///
  /// In en, this message translates to:
  /// **'This step failed.'**
  String get toolFailed;

  /// No description provided for @toolCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled.'**
  String get toolCancelled;

  /// No description provided for @invalidResult.
  ///
  /// In en, this message translates to:
  /// **'The assistant returned something we couldn\'t display.'**
  String get invalidResult;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @decline.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get decline;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @requiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredField;

  /// No description provided for @selectOne.
  ///
  /// In en, this message translates to:
  /// **'Choose one'**
  String get selectOne;

  /// No description provided for @selectMany.
  ///
  /// In en, this message translates to:
  /// **'Choose one or more'**
  String get selectMany;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get openNow;

  /// No description provided for @closed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// No description provided for @distanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distanceKm(String km);

  /// No description provided for @distanceM.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distanceM(int m);

  /// No description provided for @routeSummary.
  ///
  /// In en, this message translates to:
  /// **'{distance} · {minutes} min'**
  String routeSummary(String distance, int minutes);

  /// No description provided for @weatherFeelsLike.
  ///
  /// In en, this message translates to:
  /// **'Feels like {temp}°'**
  String weatherFeelsLike(int temp);

  /// No description provided for @weatherHumidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity {percent}%'**
  String weatherHumidity(int percent);

  /// No description provided for @weatherWind.
  ///
  /// In en, this message translates to:
  /// **'Wind {kph} km/h'**
  String weatherWind(int kph);

  /// No description provided for @permissionMicrophoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone access'**
  String get permissionMicrophoneTitle;

  /// No description provided for @permissionMicrophoneBody.
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access to talk with the assistant.'**
  String get permissionMicrophoneBody;

  /// No description provided for @permissionAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get permissionAllow;

  /// No description provided for @permissionDeny.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get permissionDeny;

  /// No description provided for @mediaPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get mediaPlay;

  /// No description provided for @semanticsUserMessage.
  ///
  /// In en, this message translates to:
  /// **'You said: {text}'**
  String semanticsUserMessage(String text);

  /// No description provided for @semanticsAssistantMessage.
  ///
  /// In en, this message translates to:
  /// **'Assistant said: {text}'**
  String semanticsAssistantMessage(String text);

  /// No description provided for @semanticsSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get semanticsSendButton;

  /// No description provided for @semanticsStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop generating'**
  String get semanticsStopButton;

  /// No description provided for @poweredBy.
  ///
  /// In en, this message translates to:
  /// **'Powered by NEXA'**
  String get poweredBy;

  /// No description provided for @reconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get reconnecting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t verify your access. Please try again.'**
  String get authError;

  /// No description provided for @sessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Start again to continue.'**
  String get sessionExpired;

  /// No description provided for @rateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait a moment.'**
  String get rateLimited;

  /// No description provided for @jumpToLatest.
  ///
  /// In en, this message translates to:
  /// **'Jump to latest'**
  String get jumpToLatest;

  /// No description provided for @semanticsAssistantResponding.
  ///
  /// In en, this message translates to:
  /// **'Assistant is responding'**
  String get semanticsAssistantResponding;

  /// No description provided for @semanticsAssistantFinished.
  ///
  /// In en, this message translates to:
  /// **'Assistant finished responding'**
  String get semanticsAssistantFinished;

  /// No description provided for @semanticsMessageFailed.
  ///
  /// In en, this message translates to:
  /// **'Message failed to send'**
  String get semanticsMessageFailed;

  /// No description provided for @voiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Live voice'**
  String get voiceTitle;

  /// No description provided for @voiceStart.
  ///
  /// In en, this message translates to:
  /// **'Start voice'**
  String get voiceStart;

  /// No description provided for @voiceEnd.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get voiceEnd;

  /// No description provided for @voiceMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get voiceMute;

  /// No description provided for @voiceUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get voiceUnmute;

  /// No description provided for @voiceRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get voiceRetry;

  /// No description provided for @voiceOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get voiceOpenSettings;

  /// No description provided for @voiceStateIdle.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get voiceStateIdle;

  /// No description provided for @voiceStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get voiceStateConnecting;

  /// No description provided for @voiceStateListening.
  ///
  /// In en, this message translates to:
  /// **'Listening'**
  String get voiceStateListening;

  /// No description provided for @voiceStateUserSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Go on, I\'m listening'**
  String get voiceStateUserSpeaking;

  /// No description provided for @voiceStateTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Got it…'**
  String get voiceStateTranscribing;

  /// No description provided for @voiceStateThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get voiceStateThinking;

  /// No description provided for @voiceStateAiSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Speaking'**
  String get voiceStateAiSpeaking;

  /// No description provided for @voiceStateBargeIn.
  ///
  /// In en, this message translates to:
  /// **'Interrupting…'**
  String get voiceStateBargeIn;

  /// No description provided for @voiceStateMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get voiceStateMuted;

  /// No description provided for @voiceStateWeakNetwork.
  ///
  /// In en, this message translates to:
  /// **'Weak connection'**
  String get voiceStateWeakNetwork;

  /// No description provided for @voiceStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get voiceStateDisconnected;

  /// No description provided for @voiceStateReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get voiceStateReconnecting;

  /// No description provided for @voiceStateModelBusy.
  ///
  /// In en, this message translates to:
  /// **'The assistant is busy, hold on…'**
  String get voiceStateModelBusy;

  /// No description provided for @voiceStateMicrophoneDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off'**
  String get voiceStateMicrophoneDenied;

  /// No description provided for @voiceStateQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Voice limit reached'**
  String get voiceStateQuotaExceeded;

  /// No description provided for @voiceStateEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get voiceStateEnded;

  /// No description provided for @voiceTranscriptYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get voiceTranscriptYou;

  /// No description provided for @voiceTranscriptAssistant.
  ///
  /// In en, this message translates to:
  /// **'Assistant'**
  String get voiceTranscriptAssistant;

  /// No description provided for @voiceUnverifiedEvents.
  ///
  /// In en, this message translates to:
  /// **'Development mode: agent events are not signed.'**
  String get voiceUnverifiedEvents;

  /// No description provided for @voiceAgentWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the assistant to join…'**
  String get voiceAgentWaiting;

  /// No description provided for @semanticsVoiceOrb.
  ///
  /// In en, this message translates to:
  /// **'Voice status: {state}'**
  String semanticsVoiceOrb(String state);

  /// No description provided for @semanticsMuteButton.
  ///
  /// In en, this message translates to:
  /// **'Mute microphone'**
  String get semanticsMuteButton;

  /// No description provided for @semanticsUnmuteButton.
  ///
  /// In en, this message translates to:
  /// **'Unmute microphone'**
  String get semanticsUnmuteButton;

  /// No description provided for @semanticsEndCallButton.
  ///
  /// In en, this message translates to:
  /// **'End voice call'**
  String get semanticsEndCallButton;
}

class _NexaLocalizationsDelegate
    extends LocalizationsDelegate<NexaLocalizations> {
  const _NexaLocalizationsDelegate();

  @override
  Future<NexaLocalizations> load(Locale locale) {
    return SynchronousFuture<NexaLocalizations>(
      lookupNexaLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_NexaLocalizationsDelegate old) => false;
}

NexaLocalizations lookupNexaLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return NexaLocalizationsAr();
    case 'en':
      return NexaLocalizationsEn();
  }

  throw FlutterError(
    'NexaLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
