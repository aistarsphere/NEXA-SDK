import 'package:nexa_sdk/nexa_sdk.dart';

/// Bridges SDK permission requests to the host's permission flow.
///
/// A real host would call `permission_handler` (or its own wrapper) here.
/// The example has no microphone feature, so it reports "denied" honestly.
final class HostPermissionHandler implements NexaPermissionHandler {
  const HostPermissionHandler();

  @override
  Future<bool> request(NexaPermission permission) async {
    // e.g. return (await Permission.microphone.request()).isGranted;
    return false;
  }
}
