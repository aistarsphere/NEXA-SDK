/// NEXA embeddable chat SDK.
///
/// Public surface:
/// * [Nexa] / [NexaClient] - initialise, sessions, open or embed chat, dispose.
/// * Configuration and auth contracts from `nexa_core` (re-exported).
/// * [NexaOverrides] - test/demo injection points.
/// * [NexaPermissionHandler] - host-side permission bridge.
/// * [NexaThemeOverrides] - approved branding knobs.
/// * [NexaVoiceController] / [NexaVoiceState] / [NexaVoiceOptions] - live voice.
library;

export 'package:nexa_core/nexa_core.dart';
export 'package:nexa_ui/nexa_ui.dart' show NexaLocale, NexaThemeOverrides;

export 'src/features/voice/nexa_voice_controller.dart';
export 'src/features/voice/nexa_voice_state.dart';
export 'src/nexa.dart';
export 'src/nexa_overrides.dart';
export 'src/nexa_ui_settings.dart';
export 'src/permissions/nexa_permission_handler.dart';
export 'src/version.dart';
