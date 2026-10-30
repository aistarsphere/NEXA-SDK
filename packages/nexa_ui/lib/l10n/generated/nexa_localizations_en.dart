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
  String get toolCancelled => 'Cancelled. Nothing was shared.';

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

  @override
  String get voiceTitle => 'Live voice';

  @override
  String get voiceStart => 'Start voice';

  @override
  String get voiceEnd => 'End call';

  @override
  String get voiceMute => 'Mute';

  @override
  String get voiceUnmute => 'Unmute';

  @override
  String get voiceRetry => 'Try again';

  @override
  String get voiceOpenSettings => 'Open settings';

  @override
  String get voiceStateIdle => 'Ready';

  @override
  String get voiceStateConnecting => 'Connecting…';

  @override
  String get voiceStateListening => 'Listening';

  @override
  String get voiceStateUserSpeaking => 'Go on, I\'m listening';

  @override
  String get voiceStateTranscribing => 'Got it…';

  @override
  String get voiceStateThinking => 'Thinking…';

  @override
  String get voiceStateAiSpeaking => 'Speaking';

  @override
  String get voiceStateBargeIn => 'Interrupting…';

  @override
  String get voiceStateMuted => 'Muted';

  @override
  String get voiceStateWeakNetwork => 'Weak connection';

  @override
  String get voiceStateDisconnected => 'Disconnected';

  @override
  String get voiceStateReconnecting => 'Reconnecting…';

  @override
  String get voiceStateModelBusy => 'The assistant is busy, hold on…';

  @override
  String get voiceStateMicrophoneDenied => 'Microphone access is off';

  @override
  String get voiceStateQuotaExceeded => 'Voice limit reached';

  @override
  String get voiceStateEnded => 'Call ended';

  @override
  String get voiceTranscriptYou => 'You';

  @override
  String get voiceTranscriptAssistant => 'Assistant';

  @override
  String get voiceUnverifiedEvents =>
      'Development mode: agent events are not signed.';

  @override
  String get voiceAgentWaiting => 'Waiting for the assistant to join…';

  @override
  String semanticsVoiceOrb(String state) {
    return 'Voice status: $state';
  }

  @override
  String get semanticsMuteButton => 'Mute microphone';

  @override
  String get semanticsUnmuteButton => 'Unmute microphone';

  @override
  String get semanticsEndCallButton => 'End voice call';

  @override
  String get voiceUnavailable =>
      'Voice isn\'t available right now. Try again in a moment.';

  @override
  String get chatEmptyTitle => 'How can I help you today?';

  @override
  String get chatEmptyBody =>
      'Ask anything by text, or start a live voice conversation.';

  @override
  String get messageCopy => 'Copy';

  @override
  String get messageCopied => 'Copied';

  @override
  String get composerLiveVoice => 'Start a live voice conversation';

  @override
  String get voiceHintIdle => 'Voice and captions start when you tap Start';

  @override
  String get voiceHintConnecting => 'Setting up a secure session';

  @override
  String get voiceHintListening => 'Speak anytime';

  @override
  String get voiceHintUserSpeaking => 'Pause briefly when you finish';

  @override
  String get voiceHintTranscribing => 'Turning your speech into text';

  @override
  String get voiceHintThinking => 'Preparing a reply';

  @override
  String get voiceHintAiSpeaking => 'Talk anytime to interrupt';

  @override
  String get voiceHintBargeIn => 'Go ahead, I\'m listening';

  @override
  String get voiceHintMuted => 'Unmute to talk';

  @override
  String get voiceHintWeakNetwork => 'Audio may be delayed. Captions stay on.';

  @override
  String get voiceHintDisconnected => 'Tap Retry to reconnect';

  @override
  String get voiceHintReconnecting => 'Nothing is lost while we reconnect';

  @override
  String get voiceHintModelBusy => 'It will continue automatically';

  @override
  String get voiceHintMicrophoneDenied => 'You can still type';

  @override
  String get voiceHintQuotaExceeded => 'Text chat still works';

  @override
  String get voiceHintEnded => 'Tap Start for a new conversation';

  @override
  String get voiceCaptionsEmpty => 'Captions of both sides appear here';

  @override
  String get voiceShowCaptions => 'Show captions';

  @override
  String get voiceHideCaptions => 'Hide captions';

  @override
  String get voiceCaptionsHidden => 'Captions are hidden';

  @override
  String get voicePartial => 'Partial';

  @override
  String get voiceFlagMuted => 'Mic muted';

  @override
  String get voiceFlagWeakNetwork => 'Weak network';

  @override
  String get assistantLiveVoice => 'Live voice';

  @override
  String get assistantLiveConversation => 'Live conversation';

  @override
  String get assistantNewConversation => 'New conversation';

  @override
  String get assistantNewConversationStarted => 'Started a new conversation';

  @override
  String get assistantSettings => 'Settings';

  @override
  String get assistantClose => 'Close';

  @override
  String get assistantStartChat => 'Start a chat';

  @override
  String get assistantStartVoice => 'Talk live';

  @override
  String get assistantHomeBody => 'Type your question, or talk to me live.';

  @override
  String get attachTitle => 'Add to conversation';

  @override
  String get attachButton => 'Attach';

  @override
  String get attachTakePhoto => 'Take a photo';

  @override
  String get attachChooseImage => 'Choose from library';

  @override
  String get attachShareLocation => 'Share my location';

  @override
  String get previewAdd => 'Add';

  @override
  String get cameraExplain =>
      'Point the camera at what you want to show. Nothing is shared until you tap Use photo.';

  @override
  String get cameraCapture => 'Take photo';

  @override
  String get cameraRetake => 'Retake';

  @override
  String get cameraUsePhoto => 'Use photo';

  @override
  String get cameraDenied =>
      'Camera access is off. Allow it in Settings to take a photo.';

  @override
  String get cameraUnavailable => 'The camera isn\'t available on this device.';

  @override
  String get cameraError => 'The camera couldn\'t start.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get toolAllow => 'Allow';

  @override
  String get toolNotNow => 'Not now';

  @override
  String get locationApproveTitle => 'Share your current location?';

  @override
  String get locationApproveBody =>
      'Your location is read once for this request and is not tracked.';

  @override
  String get cameraApproveTitle => 'Open the camera?';

  @override
  String get cameraApproveBody =>
      'Take one photo to show. You review it before it is shared.';

  @override
  String get locationResultTitle => 'Your location';

  @override
  String locationAccuracy(int meters) {
    return 'Accurate to about $meters m';
  }

  @override
  String get locationWorking => 'Getting your location…';

  @override
  String get locationDenied => 'Location access is off.';

  @override
  String get locationServiceOff => 'Location services are turned off.';

  @override
  String get locationTimeout => 'Couldn\'t get a location in time.';

  @override
  String get locationFailed => 'Couldn\'t get your location.';

  @override
  String get toolDeclined => 'Not shared.';

  @override
  String get toolNotDelivered =>
      'Not sent to the assistant: the server can\'t receive device results yet.';

  @override
  String get attachmentNotSent =>
      'On this device only: the server can\'t receive attachments yet.';

  @override
  String get attachmentUploading => 'Uploading…';

  @override
  String get attachmentFailed => 'Upload failed';

  @override
  String get attachmentCancelled => 'Cancelled';

  @override
  String get imageShare => 'Share';

  @override
  String get imageAskAbout => 'Ask about this image';

  @override
  String get imageReference => 'About this image';

  @override
  String get referenceNotSent =>
      'Image reference not sent: the server can\'t receive images yet.';

  @override
  String get voiceShowSomething => 'Show something';

  @override
  String get historyTitle => 'History';

  @override
  String get historyEmpty => 'No conversations saved on this device yet.';

  @override
  String get historyChat => 'Chat';

  @override
  String get historyVoice => 'Voice call';

  @override
  String get historyUntitled => 'Conversation';

  @override
  String historyMessages(int count) {
    return 'Messages: $count';
  }

  @override
  String get historyRename => 'Rename';

  @override
  String get historyResume => 'Continue conversation';

  @override
  String get historyResumeUnavailable =>
      'Continuing an earlier conversation needs server history, which isn\'t available yet.';

  @override
  String get deleteAction => 'Delete';

  @override
  String get deletionWorking => 'Deleting…';

  @override
  String get placesTitle => 'Nearby places';

  @override
  String get placesLoading => 'Searching nearby…';

  @override
  String get placesEmpty => 'No places found nearby.';

  @override
  String get placesLocationDenied => 'Searching nearby needs your location.';

  @override
  String get placesError => 'Couldn\'t load places.';

  @override
  String get placesDirections => 'Directions';

  @override
  String placesDistanceM(int meters) {
    return '$meters m away';
  }

  @override
  String placesDistanceKm(String km) {
    return '$km km away';
  }

  @override
  String get placesOpenNow => 'Open now';

  @override
  String get placesClosed => 'Closed';

  @override
  String get directionsFailed => 'Couldn\'t open maps.';

  @override
  String get dataPrivacyTitle => 'Data & privacy';

  @override
  String get retentionDefault =>
      'How long the service keeps conversations is set by the app\'s operator.';

  @override
  String get scopeConversation => 'Delete this conversation';

  @override
  String get scopeAllChats => 'Clear chat history';

  @override
  String get scopeAllVoice => 'Clear voice history';

  @override
  String get scopeAssets => 'Delete uploaded and generated files';

  @override
  String get scopeLocalCache => 'Clear local cache';

  @override
  String get scopeEverything => 'Request deletion of all my assistant data';

  @override
  String get scopeNoteLocalCache =>
      'Only data cached on this device. History on the server is not affected.';

  @override
  String get scopeNoteEverything =>
      'The request is sent to the service. Billing and security audit records are kept as its retention policy requires.';

  @override
  String get scopeNoteDefault =>
      'Items already shared outside the app are not recalled.';

  @override
  String get scopeServerUnavailable => 'On the server: not available yet';

  @override
  String get deletionLocalDone => 'Removed from this device';

  @override
  String get deletionServerUnavailable =>
      'Server deletion isn\'t available yet, so nothing was deleted on the server.';

  @override
  String get deletionRequested =>
      'Requested · waiting for the service to confirm';

  @override
  String get deletionConfirmed => 'Deleted on the server';

  @override
  String deletionPartial(int count) {
    return 'Partly deleted: $count items couldn\'t be removed.';
  }

  @override
  String get deletionServerFailed =>
      'The service didn\'t confirm the deletion.';

  @override
  String deletionRequestId(String id) {
    return 'Request $id';
  }

  @override
  String get deletionRetry => 'Retry';

  @override
  String get done => 'Done';

  @override
  String get historySearch => 'Search';

  @override
  String get historyLoadFailed => 'Couldn\'t load history.';

  @override
  String get historyCacheNote =>
      'Shown from this device\'s cache. The server doesn\'t offer conversation history yet.';

  @override
  String get historyRenameUnavailable =>
      'Renaming needs server history, which isn\'t available yet.';

  @override
  String get toolOriginDevice => 'DEVICE';

  @override
  String get toolOriginServer => 'SERVER';

  @override
  String get toolOriginCompany => 'COMPANY';

  @override
  String get toolStateApproval => 'Needs approval';

  @override
  String get toolStateDenied => 'Denied';

  @override
  String get toolStateRunning => 'Running';

  @override
  String get toolStateSuccess => 'Done';

  @override
  String get toolStateError => 'Failed';

  @override
  String get toolStateCancelled => 'Cancelled';

  @override
  String get toolStateUnavailable => 'Unavailable';

  @override
  String get toolStateSetup => 'Requires setup';

  @override
  String get toolAllowOnce => 'Allow once';

  @override
  String get toolRunAgain => 'Run again';

  @override
  String get toolDismiss => 'Dismiss';

  @override
  String get toolLocationName => 'Current location';

  @override
  String get toolCameraName => 'Camera capture';

  @override
  String get toolDirectionsName => 'Open navigation';

  @override
  String get toolWhereDevice => 'Runs on this device';

  @override
  String get toolWhereOtherApp => 'Opens another app';

  @override
  String get toolLocationApproval =>
      'Share your location once? Nothing is shared until you allow it.';

  @override
  String get toolCameraApproval =>
      'Take a photo to show? The camera opens only after you allow it.';

  @override
  String get toolCameraRunning => 'Waiting for the camera…';

  @override
  String get toolCameraSuccess => 'Photo captured and attached.';

  @override
  String get toolDirectionsSuccess => 'Opened directions.';

  @override
  String get toolDenied =>
      'Access was denied. You can continue without it or allow it in Settings.';

  @override
  String get toolUnavailable => 'This isn\'t available on this device.';

  @override
  String get toolSetup => 'The app hasn\'t enabled this.';

  @override
  String get toolError => 'It didn\'t complete. Nothing was changed.';

  @override
  String get toolRowCoordinates => 'Coordinates';

  @override
  String get toolRowAccuracy => 'Accuracy';

  @override
  String get toolRowShared => 'Shared';

  @override
  String get toolRowSharedOnce => 'Once, this request only';

  @override
  String get toolRowPhoto => 'Photo';

  @override
  String get toolRowSentAs => 'Sent as';

  @override
  String get toolRowDestination => 'Destination';

  @override
  String get toolRowOpenedIn => 'Opens in';

  @override
  String get toolOpenedApp => 'Maps app';

  @override
  String get toolOpenedBrowser => 'Browser';

  @override
  String toolAboutMeters(int meters) {
    return 'About $meters m';
  }

  @override
  String get cameraOn => 'Camera on';

  @override
  String get attachChooseFile => 'Choose a file';

  @override
  String get fileTooLarge => 'This file is larger than 10 MB.';

  @override
  String get fileUnsupported => 'This file type isn\'t supported.';

  @override
  String get imageGenerated => 'AI-generated';

  @override
  String get imageEdited => 'Edited · AI';

  @override
  String get attachmentCancel => 'Cancel upload';

  @override
  String get attachmentReady => 'Ready';

  @override
  String get toolNetworkName => 'Network status';

  @override
  String get toolWifiName => 'Wi-Fi network';

  @override
  String get toolBrowserName => 'Open website';

  @override
  String get toolAppName => 'Open app';

  @override
  String get toolAppsName => 'Supported apps';

  @override
  String get toolShareName => 'Share';

  @override
  String get toolFilesName => 'Pick a file';

  @override
  String get toolSettingsName => 'Open settings';

  @override
  String toolApprovalPersonal(String name) {
    return 'Allow the assistant to use “$name”? Nothing is shared until you allow it.';
  }

  @override
  String toolApprovalExternal(String name) {
    return 'Allow the assistant to “$name”? This opens outside the app.';
  }

  @override
  String get toolWorking => 'Working…';

  @override
  String get toolDoneGeneric => 'Done.';

  @override
  String get toolWhereServer => 'Runs on the server';

  @override
  String get toolRowNetwork => 'Network';

  @override
  String get toolRowWebsite => 'Website';

  @override
  String get toolRowApp => 'App';

  @override
  String get toolRowStatus => 'Status';

  @override
  String get toolRowFile => 'File';

  @override
  String get toolRowSsidHidden =>
      'Not available (the system doesn\'t allow it)';

  @override
  String get toolFileTooLarge => 'The file is larger than 10 MB.';

  @override
  String get toolFileUnsupported => 'This file type isn\'t supported.';

  @override
  String get duiDemo => 'DEMO DATA';

  @override
  String get duiLoading => 'Loading…';

  @override
  String get duiPartial => 'Loading more…';

  @override
  String get duiEmpty => 'Nothing to show here.';

  @override
  String get duiError => 'Something went wrong. Nothing was changed.';

  @override
  String get duiProviderUnavailable =>
      'The provider is unavailable, so no results are shown.';

  @override
  String get duiOffline => 'Offline · showing the last result';

  @override
  String get duiDisabled => 'Not available right now.';

  @override
  String get duiUnsupported =>
      'This content can\'t be shown in this app version.';

  @override
  String get duiActionUnsupported => 'Not available in this app version';

  @override
  String get duiHostUnavailable =>
      'This app doesn\'t allow changing its theme.';

  @override
  String get duiConfirmTitle => 'Confirm';

  @override
  String get duiConfirmBody => 'Do you want to continue?';

  @override
  String get duiConfirm => 'Confirm';

  @override
  String duiSource(String name) {
    return 'Source: $name';
  }

  @override
  String get duiOpen => 'Open';

  @override
  String get duiExpand => 'Expand';

  @override
  String get duiMinimize => 'Minimize';

  @override
  String get duiDismiss => 'Dismiss';

  @override
  String duiPosition(int position, int count, String label) {
    return '$position of $count, $label';
  }

  @override
  String get duiSelected => 'selected';

  @override
  String get duiPreviewing => 'Previewing';

  @override
  String get duiApplied => 'Applied';

  @override
  String get duiThemeApplied => 'Theme applied.';

  @override
  String get duiThemeReset => 'Original theme restored.';

  @override
  String get duiSelectionsLocal =>
      'Selections stay on this device until the assistant can receive them.';

  @override
  String get duiLive => 'Live';

  @override
  String get duiUpcoming => 'Upcoming';

  @override
  String get duiFinished => 'Finished';

  @override
  String get duiStepDone => 'Done';

  @override
  String get duiStepRunning => 'Running';

  @override
  String get duiStepWaiting => 'Waiting';

  @override
  String get duiStepFailed => 'Failed';

  @override
  String get duiStepCancelled => 'Cancelled';

  @override
  String get duiMapPreview => 'Map preview';

  @override
  String duiPages(int count) {
    return '$count pages';
  }

  @override
  String get duiCompare => 'Compare';

  @override
  String get duiOpenLinkTitle => 'Open this link in your browser?';

  @override
  String get duiStale =>
      'This choice is no longer current. Ask again for fresh options.';

  @override
  String get duiNotDelivered =>
      'Couldn\'t send that to the assistant. Try again.';

  @override
  String get duiSend => 'Send';

  @override
  String get tcAllow => 'Allow';

  @override
  String get tcNotNow => 'Not now';

  @override
  String get tcWaitingForYou => 'Waiting for your approval';

  @override
  String get tcRunning => 'Working…';

  @override
  String get tcSending => 'Sending the result…';

  @override
  String get tcDone => 'Done';

  @override
  String get tcFailed => 'Didn\'t complete';

  @override
  String get tcDenied => 'You said no';

  @override
  String get tcExpired => 'Expired: no answer in time';

  @override
  String get tcCancelled => 'Cancelled';

  @override
  String get tcClosed => 'This request is no longer open.';

  @override
  String get tcCancelJob => 'Stop';

  @override
  String get tcJobStarted => 'Started. You can keep chatting.';

  @override
  String get tcJobQueued => 'Waiting for a free slot…';

  @override
  String tcJobWaited(int seconds) {
    return 'Waiting ${seconds}s';
  }

  @override
  String tcUnavailable(String reason) {
    return 'Not available: $reason';
  }

  @override
  String tcErrorCode(String code) {
    return 'Error: $code';
  }

  @override
  String get tcThemePreview => 'Previewing the new colors';

  @override
  String get tcApplyTheme => 'Apply';

  @override
  String get tcToolLocation => 'Use your current location';

  @override
  String get tcToolCamera => 'Take a photo';

  @override
  String get tcToolPhoto => 'Choose a photo';

  @override
  String get tcToolFile => 'Choose a file';

  @override
  String get tcToolDirections => 'Open directions in Maps';

  @override
  String get tcToolOpenUrl => 'Open a link in your browser';

  @override
  String get tcToolNetwork => 'Check your connection';

  @override
  String get tcToolShare => 'Share';

  @override
  String get tcToolSettings => 'Open app settings';

  @override
  String get tcToolTheme => 'Change the app colors';

  @override
  String get tcToolThemeReset => 'Restore the original colors';

  @override
  String get tcToolPlaces => 'Searching places';

  @override
  String get tcToolVision => 'Looking at the image';

  @override
  String get tcToolImageGenerate => 'Creating an image';

  @override
  String get tcToolImageEdit => 'Editing the image';

  @override
  String get tcToolOcr => 'Reading text from the image';

  @override
  String get tcToolFileRead => 'Reading the file';

  @override
  String get tcToolFileCreate => 'Creating a file';

  @override
  String get tcToolWeb => 'Searching the web';

  @override
  String get tcToolNews => 'Searching the news';

  @override
  String get tcToolSports => 'Checking match results';

  @override
  String get tcToolVideo => 'Finding videos';

  @override
  String get tcToolPalettes => 'Listing color themes';

  @override
  String get tcToolJobs => 'Checking your tasks';

  @override
  String get tcToolOther => 'Assistant tool';

  @override
  String get tcProviderBlocked =>
      'This source isn\'t connected yet, so no results are shown.';

  @override
  String get tcRateLimited => 'The source is busy. Try again later.';

  @override
  String get tcGpuBlocked => 'The AI service can\'t run this right now.';

  @override
  String get tcEncyclopedia =>
      'Reference articles (encyclopedia), not live web results';

  @override
  String tcSeenAt(String time) {
    return 'First seen $time';
  }

  @override
  String get tcOpenLink => 'Open';

  @override
  String get tcGenerated => 'Generated image';

  @override
  String tcPurpose(String purpose) {
    return 'Why: $purpose';
  }

  @override
  String get tcUploadUnavailable =>
      'Attachments aren\'t enabled for this app yet.';

  @override
  String get tcGpuBusy =>
      'The image service is busy right now (it\'s kept free for live voice). Try again in a moment.';

  @override
  String get tcNotEnabled => 'This feature isn\'t enabled for this app yet.';

  @override
  String get tcTryAgain => 'Something went wrong. Try again.';

  @override
  String get tcDomainNotAllowed => 'That site isn\'t allowed for this app.';

  @override
  String get tcNotReadable => 'This file can\'t be read as text.';

  @override
  String get tcJobNotFound => 'This job no longer exists.';

  @override
  String get tcCouldNotRun => 'The assistant couldn\'t run this.';

  @override
  String get tcAssetDeleted => 'File deleted';

  @override
  String get tcDeleteAssetTitle => 'Delete this file?';

  @override
  String get tcDeleteAssetBody =>
      'It will be removed from the conversation for good.';

  @override
  String get tcShare => 'Share';

  @override
  String get tcDeleteFailed => 'The file couldn\'t be deleted.';

  @override
  String get recTitle => 'Record your voice';

  @override
  String get recIntro =>
      'Only what you record now is captured. It is used to create your private voice.';

  @override
  String recHint(int min, int max) {
    return 'Speak naturally for $min to $max seconds, then tap Finish.';
  }

  @override
  String get recStart => 'Start recording';

  @override
  String get recFinish => 'Finish';

  @override
  String get recRecording => 'Recording';

  @override
  String recMore(int seconds) {
    return 'Keep talking: $seconds s more';
  }

  @override
  String recElapsed(int seconds, int max) {
    return '$seconds of $max s';
  }

  @override
  String get recUploading => 'Sending the recording…';

  @override
  String get recMicDenied =>
      'Microphone access is off. Allow it in Settings to record.';

  @override
  String get audioPlay => 'Play';

  @override
  String get audioPause => 'Pause';

  @override
  String get audioFailed => 'The audio couldn\'t be played.';

  @override
  String get voiceIdentityApplied => 'Speaking in your voice';

  @override
  String get voiceIdentityNotApplied => 'Your voice isn\'t used in this call';

  @override
  String get voiceSwitching => 'Switching to the new voice…';

  @override
  String get panelExpand => 'Open full screen';

  @override
  String get panelClose => 'Close assistant';

  @override
  String get panelVoiceVerified => 'Your voice';

  @override
  String get panelWorking => 'Working on it…';

  @override
  String get panelNeedsApproval => 'Needs your OK';

  @override
  String get panelOpenToContinue => 'Open to continue';

  @override
  String get panelShowOptions => 'Show options';

  @override
  String get tcJiraNotConnected =>
      'Jira isn\'t connected for your organization yet.';

  @override
  String get tcJiraReconnect => 'Your administrator needs to reconnect Jira.';

  @override
  String get tcJiraForbidden => 'You don\'t have access to this in Jira.';

  @override
  String get tcJiraNotFound => 'Not found in Jira.';

  @override
  String get tcUnsupportedMedia => 'This file type can\'t be sent.';

  @override
  String get tcToolVoiceProfile => 'Your voice';

  @override
  String get tcToolJira => 'Jira';
}
