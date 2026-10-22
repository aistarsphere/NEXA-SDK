import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/permissions/nexa_permission_handler.dart';

/// Optional injection points for `Nexa.initialize`.
///
/// * [chatTransport] / [realtimeTransport] replace the gateway transports.
///   Intended for tests and demos (`MockChatTransport`). Supplying a mock in a
///   production build is a host bug; the SDK logs a warning when a transport
///   override is used outside `NexaEnvironment.development`.
/// * [permissionHandler] lets the host obtain OS permissions its own way.
/// * [logger] receives SDK diagnostics.
final class NexaOverrides {
  const NexaOverrides({
    this.chatTransport,
    this.realtimeTransport,
    this.permissionHandler,
    this.logger,
  });

  final ChatTransport? chatTransport;
  final RealtimeVoiceTransport? realtimeTransport;
  final NexaPermissionHandler? permissionHandler;
  final NexaLogger? logger;
}
