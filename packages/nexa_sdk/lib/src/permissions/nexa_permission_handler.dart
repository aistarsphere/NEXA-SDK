import 'package:nexa_core/nexa_core.dart';

/// Implemented by the host application. The SDK never calls platform
/// permission APIs itself; the host decides how and when to ask (this keeps
/// `permission_handler`-style dependencies out of the SDK and lets the host
/// reuse its own rationale flows).
///
/// Return `true` only if the OS permission is actually granted.
abstract interface class NexaPermissionHandler {
  Future<bool> request(NexaPermission permission);
}

/// Default: denies everything. Hosts that enable voice must supply a handler.
final class DenyAllPermissionHandler implements NexaPermissionHandler {
  const DenyAllPermissionHandler();

  @override
  Future<bool> request(NexaPermission permission) async => false;
}
