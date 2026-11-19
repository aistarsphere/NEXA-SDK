import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_realtime/nexa_realtime.dart';
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart';

/// Optional injection points for `Nexa.initialize`.
///
/// * [chatTransport] / [voiceTransport] / [voiceProvisioner] replace the
///   gateway transports. Intended for tests and demos (`MockChatTransport`,
///   `MockRealtimeVoiceTransport`, `MockVoiceProvisioner`). Supplying a mock
///   in a production build is a host bug; the SDK logs a warning when an
///   override is used outside `NexaEnvironment.development`.
/// * [permissionHandler] lets the host obtain OS permissions its own way.
/// * [callAudio] replaces the platform call-audio reader (tests).
/// * [logger] receives SDK log lines.
/// * [diagnostics] receives structured, timestamped QA records (session,
///   requests, chat timing, voice media). Development builds only: pass
///   nothing in production.
final class NexaOverrides {
  const NexaOverrides({
    this.chatTransport,
    this.voiceTransport,
    this.voiceProvisioner,
    this.permissionHandler,
    this.logger,
    this.diagnostics,
    this.callAudio,
  });

  final ChatTransport? chatTransport;
  final RealtimeVoiceTransport? voiceTransport;
  final VoiceProvisioner? voiceProvisioner;
  final NexaPermissionHandler? permissionHandler;
  final NexaLogger? logger;
  final NexaDiagnostics? diagnostics;
  final NexaCallAudio? callAudio;
}
