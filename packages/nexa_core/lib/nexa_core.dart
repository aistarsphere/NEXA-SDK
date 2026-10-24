/// NEXA shared contracts: configuration, conversation events and state,
/// tool contracts, errors, transport interfaces and the voice state machine.
///
/// Pure Dart. Depends on nothing platform-specific so it can be unit-tested
/// on the VM and reused by a future portal/web client.
library;

export 'src/auth/credential_manager.dart';
export 'src/auth/session_credential.dart';
export 'src/config/nexa_capability.dart';
export 'src/config/nexa_config.dart';
export 'src/config/nexa_environment.dart';
export 'src/config/nexa_event_delivery.dart';
export 'src/conversation/chat_message.dart';
export 'src/conversation/conversation_event.dart';
export 'src/conversation/conversation_reducer.dart';
export 'src/conversation/conversation_state.dart';
export 'src/conversation/event_sequencer.dart';
export 'src/errors/nexa_exception.dart';
export 'src/ids/ids.dart';
export 'src/logging/nexa_lifecycle_event.dart';
export 'src/logging/nexa_logger.dart';
export 'src/session/session_handle.dart';
export 'src/tools/tool_action.dart';
export 'src/tools/tool_call.dart';
export 'src/tools/tool_result.dart';
export 'src/tools/tool_result_validator.dart';
export 'src/transport/chat_transport.dart';
export 'src/transport/realtime_voice_transport.dart';
export 'src/transport/voice_provisioner.dart';
export 'src/voice/voice_command.dart';
export 'src/voice/voice_event.dart';
export 'src/voice/voice_event_pipeline.dart';
export 'src/voice/voice_events_v1.dart';
export 'src/voice/voice_grant.dart';
export 'src/voice/voice_session_machine.dart';
export 'src/voice/voice_state.dart';
export 'src/voice/voice_transcript.dart';
