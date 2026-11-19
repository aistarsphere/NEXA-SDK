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
export 'package:nexa_device/nexa_device.dart';
export 'package:nexa_realtime/nexa_realtime.dart'
    show
        MethodChannelCallAudioPlatform,
        NexaAudioRoute,
        NexaCallAudio,
        NexaCallAudioPlatform,
        NexaCallHold,
        NexaCallAudioState;
export 'package:nexa_ui/nexa_ui.dart'
    show
        NexaColors,
        NexaLocale,
        NexaMotion,
        NexaTheme,
        NexaThemeOverrides,
        NexaVoiceHold,
        NexaVoiceOutput;

export 'src/data/labeeb/labeeb_sdk_client.dart';
export 'src/data/network/error_mapper.dart'
    show gatewayErrorCode, gatewayStatus;
export 'src/features/assistant/nexa_assistant_options.dart';
export 'src/features/assistant/nexa_assistant_view.dart' show NexaAssistantView;
export 'src/features/conversation/conversation_coordinator.dart';
export 'src/features/dynamic_ui/nexa_host_capabilities.dart';
export 'src/features/dynamic_ui/nexa_surface_controller.dart';
export 'src/features/dynamic_ui/nexa_surface_presentation.dart';
export 'src/features/dynamic_ui/nexa_surface_view.dart';
export 'src/features/dynamic_ui/nexa_ui_view.dart';
export 'src/features/history/labeeb_conversations_api.dart';
export 'src/features/history/nexa_conversation_list_page.dart';
export 'src/features/history/nexa_history.dart';
export 'src/features/history/nexa_history_view.dart';
export 'src/features/media/nexa_conversation_media.dart';
export 'src/features/media/nexa_device_actions.dart';
export 'src/features/media/nexa_media_widgets.dart';
export 'src/features/tools/labeeb_audio_player.dart';
export 'src/features/tools/labeeb_device_tools.dart';
export 'src/features/tools/labeeb_pending_store.dart';
export 'src/features/tools/labeeb_record_sample.dart';
export 'src/features/tools/labeeb_tool_call_card.dart';
export 'src/features/tools/labeeb_tool_calls.dart';
export 'src/features/tools/labeeb_voice_companion.dart';
export 'src/features/voice/nexa_voice_controller.dart';
export 'src/features/voice/nexa_voice_idle_timeout.dart';
export 'src/features/voice/nexa_voice_state.dart';
export 'src/features/voice/presentation/nexa_compact_voice_panel.dart';
export 'src/features/voice/presentation/nexa_voice_identity_note.dart';
export 'src/features/voice/presentation/nexa_voice_orb.dart';
export 'src/identity/nexa_installation.dart';
export 'src/nexa.dart';
export 'src/nexa_overrides.dart';
export 'src/nexa_ui_settings.dart';
export 'src/permissions/nexa_permission_handler.dart';
export 'src/version.dart';
