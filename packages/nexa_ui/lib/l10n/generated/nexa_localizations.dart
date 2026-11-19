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
  /// **'Cancelled. Nothing was shared.'**
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
  /// **'Listening to you…'**
  String get voiceStateBargeIn;

  /// No description provided for @voiceReconnected.
  ///
  /// In en, this message translates to:
  /// **'Reconnected'**
  String get voiceReconnected;

  /// No description provided for @voiceStateInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Interrupted'**
  String get voiceStateInterrupted;

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

  /// No description provided for @voiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice isn\'t available right now. Try again in a moment.'**
  String get voiceUnavailable;

  /// No description provided for @chatEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'How can I help you today?'**
  String get chatEmptyTitle;

  /// No description provided for @chatEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Ask anything by text, or start a live voice conversation.'**
  String get chatEmptyBody;

  /// No description provided for @messageCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get messageCopy;

  /// No description provided for @messageCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get messageCopied;

  /// No description provided for @composerLiveVoice.
  ///
  /// In en, this message translates to:
  /// **'Start a live voice conversation'**
  String get composerLiveVoice;

  /// No description provided for @voiceHintIdle.
  ///
  /// In en, this message translates to:
  /// **'Voice and captions start when you tap Start'**
  String get voiceHintIdle;

  /// No description provided for @voiceHintConnecting.
  ///
  /// In en, this message translates to:
  /// **'Setting up a secure session'**
  String get voiceHintConnecting;

  /// No description provided for @voiceHintListening.
  ///
  /// In en, this message translates to:
  /// **'Speak anytime'**
  String get voiceHintListening;

  /// No description provided for @voiceHintUserSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Pause briefly when you finish'**
  String get voiceHintUserSpeaking;

  /// No description provided for @voiceHintTranscribing.
  ///
  /// In en, this message translates to:
  /// **'Turning your speech into text'**
  String get voiceHintTranscribing;

  /// No description provided for @voiceHintThinking.
  ///
  /// In en, this message translates to:
  /// **'Preparing a reply'**
  String get voiceHintThinking;

  /// No description provided for @voiceHintAiSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Talk anytime to interrupt'**
  String get voiceHintAiSpeaking;

  /// No description provided for @voiceHintBargeIn.
  ///
  /// In en, this message translates to:
  /// **'Go ahead, I\'m listening'**
  String get voiceHintBargeIn;

  /// No description provided for @voiceHintMuted.
  ///
  /// In en, this message translates to:
  /// **'Unmute to talk'**
  String get voiceHintMuted;

  /// No description provided for @voiceHintWeakNetwork.
  ///
  /// In en, this message translates to:
  /// **'Audio may be delayed. Captions stay on.'**
  String get voiceHintWeakNetwork;

  /// No description provided for @voiceHintDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Tap Retry to reconnect'**
  String get voiceHintDisconnected;

  /// No description provided for @voiceHintReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Nothing is lost while we reconnect'**
  String get voiceHintReconnecting;

  /// No description provided for @voiceHintModelBusy.
  ///
  /// In en, this message translates to:
  /// **'It will continue automatically'**
  String get voiceHintModelBusy;

  /// No description provided for @voiceHintMicrophoneDenied.
  ///
  /// In en, this message translates to:
  /// **'You can still type'**
  String get voiceHintMicrophoneDenied;

  /// No description provided for @voiceHintQuotaExceeded.
  ///
  /// In en, this message translates to:
  /// **'Text chat still works'**
  String get voiceHintQuotaExceeded;

  /// No description provided for @voiceHintEnded.
  ///
  /// In en, this message translates to:
  /// **'Tap Start for a new conversation'**
  String get voiceHintEnded;

  /// No description provided for @voiceCaptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Captions of both sides appear here'**
  String get voiceCaptionsEmpty;

  /// No description provided for @voiceShowCaptions.
  ///
  /// In en, this message translates to:
  /// **'Show captions'**
  String get voiceShowCaptions;

  /// No description provided for @voiceHideCaptions.
  ///
  /// In en, this message translates to:
  /// **'Hide captions'**
  String get voiceHideCaptions;

  /// No description provided for @voiceCaptionsHidden.
  ///
  /// In en, this message translates to:
  /// **'Captions are hidden'**
  String get voiceCaptionsHidden;

  /// No description provided for @voicePartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get voicePartial;

  /// No description provided for @voiceFlagMuted.
  ///
  /// In en, this message translates to:
  /// **'Mic muted'**
  String get voiceFlagMuted;

  /// No description provided for @voiceFlagWeakNetwork.
  ///
  /// In en, this message translates to:
  /// **'Weak network'**
  String get voiceFlagWeakNetwork;

  /// No description provided for @assistantLiveVoice.
  ///
  /// In en, this message translates to:
  /// **'Live voice'**
  String get assistantLiveVoice;

  /// No description provided for @assistantLiveConversation.
  ///
  /// In en, this message translates to:
  /// **'Live conversation'**
  String get assistantLiveConversation;

  /// No description provided for @assistantNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get assistantNewConversation;

  /// No description provided for @assistantNewConversationStarted.
  ///
  /// In en, this message translates to:
  /// **'Started a new conversation'**
  String get assistantNewConversationStarted;

  /// No description provided for @assistantSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get assistantSettings;

  /// No description provided for @assistantClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get assistantClose;

  /// No description provided for @assistantStartChat.
  ///
  /// In en, this message translates to:
  /// **'Start a chat'**
  String get assistantStartChat;

  /// No description provided for @assistantStartVoice.
  ///
  /// In en, this message translates to:
  /// **'Talk live'**
  String get assistantStartVoice;

  /// No description provided for @assistantHomeBody.
  ///
  /// In en, this message translates to:
  /// **'Type your question, or talk to me live.'**
  String get assistantHomeBody;

  /// No description provided for @attachTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to conversation'**
  String get attachTitle;

  /// No description provided for @attachButton.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attachButton;

  /// No description provided for @attachTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get attachTakePhoto;

  /// No description provided for @attachChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Choose from library'**
  String get attachChooseImage;

  /// No description provided for @attachShareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share my location'**
  String get attachShareLocation;

  /// No description provided for @previewAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get previewAdd;

  /// No description provided for @cameraExplain.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at what you want to show. Nothing is shared until you tap Use photo.'**
  String get cameraExplain;

  /// No description provided for @cameraCapture.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get cameraCapture;

  /// No description provided for @cameraRetake.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get cameraRetake;

  /// No description provided for @cameraUsePhoto.
  ///
  /// In en, this message translates to:
  /// **'Use photo'**
  String get cameraUsePhoto;

  /// No description provided for @cameraDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. Allow it in Settings to take a photo.'**
  String get cameraDenied;

  /// No description provided for @cameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The camera isn\'t available on this device.'**
  String get cameraUnavailable;

  /// No description provided for @cameraError.
  ///
  /// In en, this message translates to:
  /// **'The camera couldn\'t start.'**
  String get cameraError;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @toolAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get toolAllow;

  /// No description provided for @toolNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get toolNotNow;

  /// No description provided for @locationApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Share your current location?'**
  String get locationApproveTitle;

  /// No description provided for @locationApproveBody.
  ///
  /// In en, this message translates to:
  /// **'Your location is read once for this request and is not tracked.'**
  String get locationApproveBody;

  /// No description provided for @cameraApproveTitle.
  ///
  /// In en, this message translates to:
  /// **'Open the camera?'**
  String get cameraApproveTitle;

  /// No description provided for @cameraApproveBody.
  ///
  /// In en, this message translates to:
  /// **'Take one photo to show. You review it before it is shared.'**
  String get cameraApproveBody;

  /// No description provided for @locationResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get locationResultTitle;

  /// No description provided for @locationAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accurate to about {meters} m'**
  String locationAccuracy(int meters);

  /// No description provided for @locationWorking.
  ///
  /// In en, this message translates to:
  /// **'Getting your location…'**
  String get locationWorking;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location access is off.'**
  String get locationDenied;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off.'**
  String get locationServiceOff;

  /// No description provided for @locationTimeout.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a location in time.'**
  String get locationTimeout;

  /// No description provided for @locationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location.'**
  String get locationFailed;

  /// No description provided for @toolDeclined.
  ///
  /// In en, this message translates to:
  /// **'Not shared.'**
  String get toolDeclined;

  /// No description provided for @toolNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'Not sent to the assistant: the server can\'t receive device results yet.'**
  String get toolNotDelivered;

  /// No description provided for @attachmentNotSent.
  ///
  /// In en, this message translates to:
  /// **'On this device only: the server can\'t receive attachments yet.'**
  String get attachmentNotSent;

  /// No description provided for @attachmentUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get attachmentUploading;

  /// No description provided for @attachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get attachmentFailed;

  /// No description provided for @attachmentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get attachmentCancelled;

  /// No description provided for @imageShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get imageShare;

  /// No description provided for @imageAskAbout.
  ///
  /// In en, this message translates to:
  /// **'Ask about this image'**
  String get imageAskAbout;

  /// No description provided for @imageReference.
  ///
  /// In en, this message translates to:
  /// **'About this image'**
  String get imageReference;

  /// No description provided for @referenceNotSent.
  ///
  /// In en, this message translates to:
  /// **'Image reference not sent: the server can\'t receive images yet.'**
  String get referenceNotSent;

  /// No description provided for @voiceShowSomething.
  ///
  /// In en, this message translates to:
  /// **'Show something'**
  String get voiceShowSomething;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations saved on this device yet.'**
  String get historyEmpty;

  /// No description provided for @messageSpoken.
  ///
  /// In en, this message translates to:
  /// **'Spoken'**
  String get messageSpoken;

  /// No description provided for @listEmpty.
  ///
  /// In en, this message translates to:
  /// **'No conversations yet. Start one by typing or by talking.'**
  String get listEmpty;

  /// No description provided for @historyChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get historyChat;

  /// No description provided for @historyVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get historyVoice;

  /// No description provided for @historyUntitled.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get historyUntitled;

  /// No description provided for @historyMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages: {count}'**
  String historyMessages(int count);

  /// No description provided for @historyRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get historyRename;

  /// No description provided for @historyResume.
  ///
  /// In en, this message translates to:
  /// **'Continue conversation'**
  String get historyResume;

  /// No description provided for @historyResumeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Continuing an earlier conversation needs server history, which isn\'t available yet.'**
  String get historyResumeUnavailable;

  /// No description provided for @deleteAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAction;

  /// No description provided for @deletionWorking.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get deletionWorking;

  /// No description provided for @placesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nearby places'**
  String get placesTitle;

  /// No description provided for @placesLoading.
  ///
  /// In en, this message translates to:
  /// **'Searching nearby…'**
  String get placesLoading;

  /// No description provided for @placesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No places found nearby.'**
  String get placesEmpty;

  /// No description provided for @placesLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Searching nearby needs your location.'**
  String get placesLocationDenied;

  /// No description provided for @placesError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load places.'**
  String get placesError;

  /// No description provided for @placesDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get placesDirections;

  /// No description provided for @placesDistanceM.
  ///
  /// In en, this message translates to:
  /// **'{meters} m away'**
  String placesDistanceM(int meters);

  /// No description provided for @placesDistanceKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km away'**
  String placesDistanceKm(String km);

  /// No description provided for @placesOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get placesOpenNow;

  /// No description provided for @placesClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get placesClosed;

  /// No description provided for @directionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open maps.'**
  String get directionsFailed;

  /// No description provided for @dataPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Data & privacy'**
  String get dataPrivacyTitle;

  /// No description provided for @retentionDefault.
  ///
  /// In en, this message translates to:
  /// **'How long the service keeps conversations is set by the app\'s operator.'**
  String get retentionDefault;

  /// No description provided for @scopeConversation.
  ///
  /// In en, this message translates to:
  /// **'Delete this conversation'**
  String get scopeConversation;

  /// No description provided for @scopeAllConversations.
  ///
  /// In en, this message translates to:
  /// **'Delete all conversations'**
  String get scopeAllConversations;

  /// No description provided for @scopeAllChats.
  ///
  /// In en, this message translates to:
  /// **'Clear chat history'**
  String get scopeAllChats;

  /// No description provided for @scopeAllVoice.
  ///
  /// In en, this message translates to:
  /// **'Clear voice history'**
  String get scopeAllVoice;

  /// No description provided for @scopeAssets.
  ///
  /// In en, this message translates to:
  /// **'Delete uploaded and generated files'**
  String get scopeAssets;

  /// No description provided for @scopeLocalCache.
  ///
  /// In en, this message translates to:
  /// **'Clear local cache'**
  String get scopeLocalCache;

  /// No description provided for @scopeEverything.
  ///
  /// In en, this message translates to:
  /// **'Request deletion of all my assistant data'**
  String get scopeEverything;

  /// No description provided for @scopeNoteLocalCache.
  ///
  /// In en, this message translates to:
  /// **'Only data cached on this device. History on the server is not affected.'**
  String get scopeNoteLocalCache;

  /// No description provided for @scopeNoteEverything.
  ///
  /// In en, this message translates to:
  /// **'The request is sent to the service. Billing and security audit records are kept as its retention policy requires.'**
  String get scopeNoteEverything;

  /// No description provided for @scopeNoteAllConversations.
  ///
  /// In en, this message translates to:
  /// **'Every chat and call in your history is deleted from this device and from the service. This can\'t be undone.'**
  String get scopeNoteAllConversations;

  /// No description provided for @deletionQuestion.
  ///
  /// In en, this message translates to:
  /// **'{title}?'**
  String deletionQuestion(String title);

  /// No description provided for @scopeNoteDefault.
  ///
  /// In en, this message translates to:
  /// **'Items already shared outside the app are not recalled.'**
  String get scopeNoteDefault;

  /// No description provided for @scopeServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'On the server: not available yet'**
  String get scopeServerUnavailable;

  /// No description provided for @deletionLocalDone.
  ///
  /// In en, this message translates to:
  /// **'Removed from this device'**
  String get deletionLocalDone;

  /// No description provided for @deletionServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Server deletion isn\'t available yet, so nothing was deleted on the server.'**
  String get deletionServerUnavailable;

  /// No description provided for @deletionRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested · waiting for the service to confirm'**
  String get deletionRequested;

  /// No description provided for @deletionConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Deleted on the server'**
  String get deletionConfirmed;

  /// No description provided for @deletionPartial.
  ///
  /// In en, this message translates to:
  /// **'Partly deleted: {count} items couldn\'t be removed.'**
  String deletionPartial(int count);

  /// No description provided for @deletionServerFailed.
  ///
  /// In en, this message translates to:
  /// **'The service didn\'t confirm the deletion.'**
  String get deletionServerFailed;

  /// No description provided for @deletionRequestId.
  ///
  /// In en, this message translates to:
  /// **'Request {id}'**
  String deletionRequestId(String id);

  /// No description provided for @deletionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get deletionRetry;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @historySearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get historySearch;

  /// No description provided for @historyLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load history.'**
  String get historyLoadFailed;

  /// No description provided for @historyCacheNote.
  ///
  /// In en, this message translates to:
  /// **'Shown from this device\'s cache. The server doesn\'t offer conversation history yet.'**
  String get historyCacheNote;

  /// No description provided for @historyRenameUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Renaming needs server history, which isn\'t available yet.'**
  String get historyRenameUnavailable;

  /// No description provided for @toolOriginDevice.
  ///
  /// In en, this message translates to:
  /// **'DEVICE'**
  String get toolOriginDevice;

  /// No description provided for @toolOriginServer.
  ///
  /// In en, this message translates to:
  /// **'SERVER'**
  String get toolOriginServer;

  /// No description provided for @toolOriginCompany.
  ///
  /// In en, this message translates to:
  /// **'COMPANY'**
  String get toolOriginCompany;

  /// No description provided for @toolStateApproval.
  ///
  /// In en, this message translates to:
  /// **'Needs approval'**
  String get toolStateApproval;

  /// No description provided for @toolStateDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get toolStateDenied;

  /// No description provided for @toolStateRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get toolStateRunning;

  /// No description provided for @toolStateSuccess.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get toolStateSuccess;

  /// No description provided for @toolStateError.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get toolStateError;

  /// No description provided for @toolStateCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get toolStateCancelled;

  /// No description provided for @toolStateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get toolStateUnavailable;

  /// No description provided for @toolStateSetup.
  ///
  /// In en, this message translates to:
  /// **'Requires setup'**
  String get toolStateSetup;

  /// No description provided for @toolAllowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get toolAllowOnce;

  /// No description provided for @toolRunAgain.
  ///
  /// In en, this message translates to:
  /// **'Run again'**
  String get toolRunAgain;

  /// No description provided for @toolDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get toolDismiss;

  /// No description provided for @toolLocationName.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get toolLocationName;

  /// No description provided for @toolCameraName.
  ///
  /// In en, this message translates to:
  /// **'Camera capture'**
  String get toolCameraName;

  /// No description provided for @toolDirectionsName.
  ///
  /// In en, this message translates to:
  /// **'Open navigation'**
  String get toolDirectionsName;

  /// No description provided for @toolWhereDevice.
  ///
  /// In en, this message translates to:
  /// **'Runs on this device'**
  String get toolWhereDevice;

  /// No description provided for @toolWhereOtherApp.
  ///
  /// In en, this message translates to:
  /// **'Opens another app'**
  String get toolWhereOtherApp;

  /// No description provided for @toolLocationApproval.
  ///
  /// In en, this message translates to:
  /// **'Share your location once? Nothing is shared until you allow it.'**
  String get toolLocationApproval;

  /// No description provided for @toolCameraApproval.
  ///
  /// In en, this message translates to:
  /// **'Take a photo to show? The camera opens only after you allow it.'**
  String get toolCameraApproval;

  /// No description provided for @toolCameraRunning.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the camera…'**
  String get toolCameraRunning;

  /// No description provided for @toolCameraSuccess.
  ///
  /// In en, this message translates to:
  /// **'Photo captured and attached.'**
  String get toolCameraSuccess;

  /// No description provided for @toolDirectionsSuccess.
  ///
  /// In en, this message translates to:
  /// **'Opened directions.'**
  String get toolDirectionsSuccess;

  /// No description provided for @toolDenied.
  ///
  /// In en, this message translates to:
  /// **'Access was denied. You can continue without it or allow it in Settings.'**
  String get toolDenied;

  /// No description provided for @toolUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t available on this device.'**
  String get toolUnavailable;

  /// No description provided for @toolSetup.
  ///
  /// In en, this message translates to:
  /// **'The app hasn\'t enabled this.'**
  String get toolSetup;

  /// No description provided for @toolError.
  ///
  /// In en, this message translates to:
  /// **'It didn\'t complete. Nothing was changed.'**
  String get toolError;

  /// No description provided for @toolRowCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get toolRowCoordinates;

  /// No description provided for @toolRowAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy'**
  String get toolRowAccuracy;

  /// No description provided for @toolRowShared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get toolRowShared;

  /// No description provided for @toolRowSharedOnce.
  ///
  /// In en, this message translates to:
  /// **'Once, this request only'**
  String get toolRowSharedOnce;

  /// No description provided for @toolRowPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get toolRowPhoto;

  /// No description provided for @toolRowSentAs.
  ///
  /// In en, this message translates to:
  /// **'Sent as'**
  String get toolRowSentAs;

  /// No description provided for @toolRowDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get toolRowDestination;

  /// No description provided for @toolRowOpenedIn.
  ///
  /// In en, this message translates to:
  /// **'Opens in'**
  String get toolRowOpenedIn;

  /// No description provided for @toolOpenedApp.
  ///
  /// In en, this message translates to:
  /// **'Maps app'**
  String get toolOpenedApp;

  /// No description provided for @toolOpenedBrowser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get toolOpenedBrowser;

  /// No description provided for @toolAboutMeters.
  ///
  /// In en, this message translates to:
  /// **'About {meters} m'**
  String toolAboutMeters(int meters);

  /// No description provided for @cameraOn.
  ///
  /// In en, this message translates to:
  /// **'Camera on'**
  String get cameraOn;

  /// No description provided for @attachChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get attachChooseFile;

  /// No description provided for @fileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than 10 MB.'**
  String get fileTooLarge;

  /// No description provided for @fileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get fileUnsupported;

  /// No description provided for @imageGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI-generated'**
  String get imageGenerated;

  /// No description provided for @imageEdited.
  ///
  /// In en, this message translates to:
  /// **'Edited · AI'**
  String get imageEdited;

  /// No description provided for @attachmentCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel upload'**
  String get attachmentCancel;

  /// No description provided for @attachmentReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get attachmentReady;

  /// No description provided for @toolNetworkName.
  ///
  /// In en, this message translates to:
  /// **'Network status'**
  String get toolNetworkName;

  /// No description provided for @toolWifiName.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi network'**
  String get toolWifiName;

  /// No description provided for @toolBrowserName.
  ///
  /// In en, this message translates to:
  /// **'Open website'**
  String get toolBrowserName;

  /// No description provided for @toolAppName.
  ///
  /// In en, this message translates to:
  /// **'Open app'**
  String get toolAppName;

  /// No description provided for @toolAppsName.
  ///
  /// In en, this message translates to:
  /// **'Supported apps'**
  String get toolAppsName;

  /// No description provided for @toolShareName.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get toolShareName;

  /// No description provided for @toolFilesName.
  ///
  /// In en, this message translates to:
  /// **'Pick a file'**
  String get toolFilesName;

  /// No description provided for @toolSettingsName.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get toolSettingsName;

  /// No description provided for @toolApprovalPersonal.
  ///
  /// In en, this message translates to:
  /// **'Allow the assistant to use “{name}”? Nothing is shared until you allow it.'**
  String toolApprovalPersonal(String name);

  /// No description provided for @toolApprovalExternal.
  ///
  /// In en, this message translates to:
  /// **'Allow the assistant to “{name}”? This opens outside the app.'**
  String toolApprovalExternal(String name);

  /// No description provided for @toolWorking.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get toolWorking;

  /// No description provided for @toolDoneGeneric.
  ///
  /// In en, this message translates to:
  /// **'Done.'**
  String get toolDoneGeneric;

  /// No description provided for @toolWhereServer.
  ///
  /// In en, this message translates to:
  /// **'Runs on the server'**
  String get toolWhereServer;

  /// No description provided for @toolRowNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get toolRowNetwork;

  /// No description provided for @toolRowWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get toolRowWebsite;

  /// No description provided for @toolRowApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get toolRowApp;

  /// No description provided for @toolRowStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get toolRowStatus;

  /// No description provided for @toolRowFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get toolRowFile;

  /// No description provided for @toolRowSsidHidden.
  ///
  /// In en, this message translates to:
  /// **'Not available (the system doesn\'t allow it)'**
  String get toolRowSsidHidden;

  /// No description provided for @toolFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The file is larger than 10 MB.'**
  String get toolFileTooLarge;

  /// No description provided for @toolFileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This file type isn\'t supported.'**
  String get toolFileUnsupported;

  /// No description provided for @duiDemo.
  ///
  /// In en, this message translates to:
  /// **'DEMO DATA'**
  String get duiDemo;

  /// No description provided for @duiLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get duiLoading;

  /// No description provided for @duiPartial.
  ///
  /// In en, this message translates to:
  /// **'Loading more…'**
  String get duiPartial;

  /// No description provided for @duiEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show here.'**
  String get duiEmpty;

  /// No description provided for @duiError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Nothing was changed.'**
  String get duiError;

  /// No description provided for @duiProviderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The provider is unavailable, so no results are shown.'**
  String get duiProviderUnavailable;

  /// No description provided for @duiOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline · showing the last result'**
  String get duiOffline;

  /// No description provided for @duiDisabled.
  ///
  /// In en, this message translates to:
  /// **'Not available right now.'**
  String get duiDisabled;

  /// No description provided for @duiUnsupported.
  ///
  /// In en, this message translates to:
  /// **'This content can\'t be shown in this app version.'**
  String get duiUnsupported;

  /// No description provided for @duiActionUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Not available in this app version'**
  String get duiActionUnsupported;

  /// No description provided for @duiHostUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This app doesn\'t allow changing its theme.'**
  String get duiHostUnavailable;

  /// No description provided for @duiConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get duiConfirmTitle;

  /// No description provided for @duiConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Do you want to continue?'**
  String get duiConfirmBody;

  /// No description provided for @duiConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get duiConfirm;

  /// No description provided for @duiSource.
  ///
  /// In en, this message translates to:
  /// **'Source: {name}'**
  String duiSource(String name);

  /// No description provided for @duiOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get duiOpen;

  /// No description provided for @duiExpand.
  ///
  /// In en, this message translates to:
  /// **'Expand'**
  String get duiExpand;

  /// No description provided for @duiMinimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get duiMinimize;

  /// No description provided for @duiDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get duiDismiss;

  /// No description provided for @duiPosition.
  ///
  /// In en, this message translates to:
  /// **'{position} of {count}, {label}'**
  String duiPosition(int position, int count, String label);

  /// No description provided for @duiSelected.
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get duiSelected;

  /// No description provided for @duiPreviewing.
  ///
  /// In en, this message translates to:
  /// **'Previewing'**
  String get duiPreviewing;

  /// No description provided for @duiApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get duiApplied;

  /// No description provided for @duiThemeApplied.
  ///
  /// In en, this message translates to:
  /// **'Theme applied.'**
  String get duiThemeApplied;

  /// No description provided for @duiThemeReset.
  ///
  /// In en, this message translates to:
  /// **'Original theme restored.'**
  String get duiThemeReset;

  /// No description provided for @duiSelectionsLocal.
  ///
  /// In en, this message translates to:
  /// **'Selections stay on this device until the assistant can receive them.'**
  String get duiSelectionsLocal;

  /// No description provided for @duiLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get duiLive;

  /// No description provided for @duiUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get duiUpcoming;

  /// No description provided for @duiFinished.
  ///
  /// In en, this message translates to:
  /// **'Finished'**
  String get duiFinished;

  /// No description provided for @duiStepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get duiStepDone;

  /// No description provided for @duiStepRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get duiStepRunning;

  /// No description provided for @duiStepWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get duiStepWaiting;

  /// No description provided for @duiStepFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get duiStepFailed;

  /// No description provided for @duiStepCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get duiStepCancelled;

  /// No description provided for @duiMapPreview.
  ///
  /// In en, this message translates to:
  /// **'Map preview'**
  String get duiMapPreview;

  /// No description provided for @duiPages.
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String duiPages(int count);

  /// No description provided for @duiCompare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get duiCompare;

  /// No description provided for @duiOpenLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Open this link in your browser?'**
  String get duiOpenLinkTitle;

  /// No description provided for @duiStale.
  ///
  /// In en, this message translates to:
  /// **'This choice is no longer current. Ask again for fresh options.'**
  String get duiStale;

  /// No description provided for @duiNotDelivered.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send that to the assistant. Try again.'**
  String get duiNotDelivered;

  /// No description provided for @duiSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get duiSend;

  /// No description provided for @tcAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get tcAllow;

  /// No description provided for @tcNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get tcNotNow;

  /// No description provided for @tcWaitingForYou.
  ///
  /// In en, this message translates to:
  /// **'Waiting for your approval'**
  String get tcWaitingForYou;

  /// No description provided for @tcRunning.
  ///
  /// In en, this message translates to:
  /// **'Working…'**
  String get tcRunning;

  /// No description provided for @tcSending.
  ///
  /// In en, this message translates to:
  /// **'Sending the result…'**
  String get tcSending;

  /// No description provided for @tcDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get tcDone;

  /// No description provided for @tcFailed.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t complete'**
  String get tcFailed;

  /// No description provided for @tcDenied.
  ///
  /// In en, this message translates to:
  /// **'You said no'**
  String get tcDenied;

  /// No description provided for @tcExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired: no answer in time'**
  String get tcExpired;

  /// No description provided for @tcCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tcCancelled;

  /// No description provided for @tcClosed.
  ///
  /// In en, this message translates to:
  /// **'This request is no longer open.'**
  String get tcClosed;

  /// No description provided for @tcCancelJob.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get tcCancelJob;

  /// No description provided for @tcJobStarted.
  ///
  /// In en, this message translates to:
  /// **'Started. You can keep chatting.'**
  String get tcJobStarted;

  /// No description provided for @tcJobQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a free slot…'**
  String get tcJobQueued;

  /// No description provided for @tcJobWaited.
  ///
  /// In en, this message translates to:
  /// **'Waiting {seconds}s'**
  String tcJobWaited(int seconds);

  /// No description provided for @tcUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available: {reason}'**
  String tcUnavailable(String reason);

  /// No description provided for @tcErrorCode.
  ///
  /// In en, this message translates to:
  /// **'Error: {code}'**
  String tcErrorCode(String code);

  /// No description provided for @tcThemePreview.
  ///
  /// In en, this message translates to:
  /// **'Previewing the new colors'**
  String get tcThemePreview;

  /// No description provided for @tcApplyTheme.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get tcApplyTheme;

  /// No description provided for @tcToolLocation.
  ///
  /// In en, this message translates to:
  /// **'Use your current location'**
  String get tcToolLocation;

  /// No description provided for @tcToolCamera.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get tcToolCamera;

  /// No description provided for @tcToolPhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get tcToolPhoto;

  /// No description provided for @tcToolFile.
  ///
  /// In en, this message translates to:
  /// **'Choose a file'**
  String get tcToolFile;

  /// No description provided for @tcToolDirections.
  ///
  /// In en, this message translates to:
  /// **'Open directions in Maps'**
  String get tcToolDirections;

  /// No description provided for @tcToolOpenUrl.
  ///
  /// In en, this message translates to:
  /// **'Open a link in your browser'**
  String get tcToolOpenUrl;

  /// No description provided for @tcToolNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your connection'**
  String get tcToolNetwork;

  /// No description provided for @tcToolShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get tcToolShare;

  /// No description provided for @tcToolSettings.
  ///
  /// In en, this message translates to:
  /// **'Open app settings'**
  String get tcToolSettings;

  /// No description provided for @tcToolTheme.
  ///
  /// In en, this message translates to:
  /// **'Change the app colors'**
  String get tcToolTheme;

  /// No description provided for @tcToolThemeReset.
  ///
  /// In en, this message translates to:
  /// **'Restore the original colors'**
  String get tcToolThemeReset;

  /// No description provided for @tcToolPlaces.
  ///
  /// In en, this message translates to:
  /// **'Searching places'**
  String get tcToolPlaces;

  /// No description provided for @tcToolVision.
  ///
  /// In en, this message translates to:
  /// **'Looking at the image'**
  String get tcToolVision;

  /// No description provided for @tcToolImageGenerate.
  ///
  /// In en, this message translates to:
  /// **'Creating an image'**
  String get tcToolImageGenerate;

  /// No description provided for @tcToolImageEdit.
  ///
  /// In en, this message translates to:
  /// **'Editing the image'**
  String get tcToolImageEdit;

  /// No description provided for @tcToolOcr.
  ///
  /// In en, this message translates to:
  /// **'Reading text from the image'**
  String get tcToolOcr;

  /// No description provided for @tcToolFileRead.
  ///
  /// In en, this message translates to:
  /// **'Reading the file'**
  String get tcToolFileRead;

  /// No description provided for @tcToolFileCreate.
  ///
  /// In en, this message translates to:
  /// **'Creating a file'**
  String get tcToolFileCreate;

  /// No description provided for @tcToolWeb.
  ///
  /// In en, this message translates to:
  /// **'Searching the web'**
  String get tcToolWeb;

  /// No description provided for @tcToolNews.
  ///
  /// In en, this message translates to:
  /// **'Searching the news'**
  String get tcToolNews;

  /// No description provided for @tcToolSports.
  ///
  /// In en, this message translates to:
  /// **'Checking match results'**
  String get tcToolSports;

  /// No description provided for @tcToolVideo.
  ///
  /// In en, this message translates to:
  /// **'Finding videos'**
  String get tcToolVideo;

  /// No description provided for @tcToolPalettes.
  ///
  /// In en, this message translates to:
  /// **'Listing color themes'**
  String get tcToolPalettes;

  /// No description provided for @tcToolJobs.
  ///
  /// In en, this message translates to:
  /// **'Checking your tasks'**
  String get tcToolJobs;

  /// No description provided for @tcToolOther.
  ///
  /// In en, this message translates to:
  /// **'Assistant tool'**
  String get tcToolOther;

  /// No description provided for @tcProviderBlocked.
  ///
  /// In en, this message translates to:
  /// **'This source isn\'t connected yet, so no results are shown.'**
  String get tcProviderBlocked;

  /// No description provided for @tcRateLimited.
  ///
  /// In en, this message translates to:
  /// **'The source is busy. Try again later.'**
  String get tcRateLimited;

  /// No description provided for @tcGpuBlocked.
  ///
  /// In en, this message translates to:
  /// **'The AI service can\'t run this right now.'**
  String get tcGpuBlocked;

  /// No description provided for @tcEncyclopedia.
  ///
  /// In en, this message translates to:
  /// **'Reference articles (encyclopedia), not live web results'**
  String get tcEncyclopedia;

  /// No description provided for @tcSeenAt.
  ///
  /// In en, this message translates to:
  /// **'First seen {time}'**
  String tcSeenAt(String time);

  /// No description provided for @tcOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get tcOpenLink;

  /// No description provided for @tcGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated image'**
  String get tcGenerated;

  /// No description provided for @tcPurpose.
  ///
  /// In en, this message translates to:
  /// **'Why: {purpose}'**
  String tcPurpose(String purpose);

  /// No description provided for @tcUploadUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Attachments aren\'t enabled for this app yet.'**
  String get tcUploadUnavailable;

  /// No description provided for @tcGpuBusy.
  ///
  /// In en, this message translates to:
  /// **'The image service is busy right now (it\'s kept free for live voice). Try again in a moment.'**
  String get tcGpuBusy;

  /// No description provided for @tcNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'This feature isn\'t enabled for this app yet.'**
  String get tcNotEnabled;

  /// No description provided for @tcTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get tcTryAgain;

  /// No description provided for @tcDomainNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'That site isn\'t allowed for this app.'**
  String get tcDomainNotAllowed;

  /// No description provided for @tcNotReadable.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be read as text.'**
  String get tcNotReadable;

  /// No description provided for @tcJobNotFound.
  ///
  /// In en, this message translates to:
  /// **'This job no longer exists.'**
  String get tcJobNotFound;

  /// No description provided for @tcCouldNotRun.
  ///
  /// In en, this message translates to:
  /// **'The assistant couldn\'t run this.'**
  String get tcCouldNotRun;

  /// No description provided for @tcAssetDeleted.
  ///
  /// In en, this message translates to:
  /// **'File deleted'**
  String get tcAssetDeleted;

  /// No description provided for @tcDeleteAssetTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this file?'**
  String get tcDeleteAssetTitle;

  /// No description provided for @tcDeleteAssetBody.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from the conversation for good.'**
  String get tcDeleteAssetBody;

  /// No description provided for @tcShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get tcShare;

  /// No description provided for @tcDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'The file couldn\'t be deleted.'**
  String get tcDeleteFailed;

  /// No description provided for @recTitle.
  ///
  /// In en, this message translates to:
  /// **'Record your voice'**
  String get recTitle;

  /// No description provided for @recIntro.
  ///
  /// In en, this message translates to:
  /// **'Only what you record now is captured. It is used to create your private voice.'**
  String get recIntro;

  /// No description provided for @recHint.
  ///
  /// In en, this message translates to:
  /// **'Speak naturally for {min} to {max} seconds, then tap Finish.'**
  String recHint(int min, int max);

  /// No description provided for @recStart.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get recStart;

  /// No description provided for @recFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get recFinish;

  /// No description provided for @recRecording.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recRecording;

  /// No description provided for @recMore.
  ///
  /// In en, this message translates to:
  /// **'Keep talking: {seconds} s more'**
  String recMore(int seconds);

  /// No description provided for @recElapsed.
  ///
  /// In en, this message translates to:
  /// **'{seconds} of {max} s'**
  String recElapsed(int seconds, int max);

  /// No description provided for @recUploading.
  ///
  /// In en, this message translates to:
  /// **'Sending the recording…'**
  String get recUploading;

  /// No description provided for @recMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is off. Allow it in Settings to record.'**
  String get recMicDenied;

  /// No description provided for @audioPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get audioPlay;

  /// No description provided for @audioPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get audioPause;

  /// No description provided for @audioFailed.
  ///
  /// In en, this message translates to:
  /// **'The audio couldn\'t be played.'**
  String get audioFailed;

  /// No description provided for @voiceIdentityApplied.
  ///
  /// In en, this message translates to:
  /// **'Speaking in your voice'**
  String get voiceIdentityApplied;

  /// No description provided for @voiceIdentityNotApplied.
  ///
  /// In en, this message translates to:
  /// **'Your voice isn\'t used in this call'**
  String get voiceIdentityNotApplied;

  /// No description provided for @voiceSwitching.
  ///
  /// In en, this message translates to:
  /// **'Switching to the new voice…'**
  String get voiceSwitching;

  /// No description provided for @panelExpand.
  ///
  /// In en, this message translates to:
  /// **'Open full screen'**
  String get panelExpand;

  /// No description provided for @panelClose.
  ///
  /// In en, this message translates to:
  /// **'Close assistant'**
  String get panelClose;

  /// No description provided for @panelVoiceVerified.
  ///
  /// In en, this message translates to:
  /// **'Your voice'**
  String get panelVoiceVerified;

  /// No description provided for @panelWorking.
  ///
  /// In en, this message translates to:
  /// **'Working on it…'**
  String get panelWorking;

  /// No description provided for @panelNeedsApproval.
  ///
  /// In en, this message translates to:
  /// **'Needs your OK'**
  String get panelNeedsApproval;

  /// No description provided for @panelOpenToContinue.
  ///
  /// In en, this message translates to:
  /// **'Open to continue'**
  String get panelOpenToContinue;

  /// No description provided for @panelShowOptions.
  ///
  /// In en, this message translates to:
  /// **'Show options'**
  String get panelShowOptions;

  /// No description provided for @tcJiraNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Jira isn\'t connected for your organization yet.'**
  String get tcJiraNotConnected;

  /// No description provided for @tcJiraReconnect.
  ///
  /// In en, this message translates to:
  /// **'Your administrator needs to reconnect Jira.'**
  String get tcJiraReconnect;

  /// No description provided for @tcJiraForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have access to this in Jira.'**
  String get tcJiraForbidden;

  /// No description provided for @tcJiraNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found in Jira.'**
  String get tcJiraNotFound;

  /// No description provided for @tcUnsupportedMedia.
  ///
  /// In en, this message translates to:
  /// **'This file type can\'t be sent.'**
  String get tcUnsupportedMedia;

  /// No description provided for @tcToolVoiceProfile.
  ///
  /// In en, this message translates to:
  /// **'Your voice'**
  String get tcToolVoiceProfile;

  /// No description provided for @tcToolJira.
  ///
  /// In en, this message translates to:
  /// **'Jira'**
  String get tcToolJira;

  /// No description provided for @voiceOutputSpeaker.
  ///
  /// In en, this message translates to:
  /// **'Speaker'**
  String get voiceOutputSpeaker;

  /// No description provided for @voiceOutputEarpiece.
  ///
  /// In en, this message translates to:
  /// **'Earpiece'**
  String get voiceOutputEarpiece;

  /// No description provided for @voiceOutputHeadset.
  ///
  /// In en, this message translates to:
  /// **'Headset'**
  String get voiceOutputHeadset;

  /// No description provided for @voiceOutputSpeakerTooltip.
  ///
  /// In en, this message translates to:
  /// **'Speaker on. Tap to use the phone earpiece'**
  String get voiceOutputSpeakerTooltip;

  /// No description provided for @voiceOutputEarpieceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Phone earpiece. Tap to use the speaker'**
  String get voiceOutputEarpieceTooltip;

  /// No description provided for @voiceOutputHeadsetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Headset connected. Tap to change the phone output for when it is removed'**
  String get voiceOutputHeadsetTooltip;

  /// No description provided for @voicePhoneCallHold.
  ///
  /// In en, this message translates to:
  /// **'Paused for a phone call'**
  String get voicePhoneCallHold;

  /// No description provided for @voiceOtherAppHold.
  ///
  /// In en, this message translates to:
  /// **'Paused: another app is using the audio'**
  String get voiceOtherAppHold;

  /// No description provided for @voiceResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get voiceResume;
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
