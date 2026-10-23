import 'package:nexa_sdk/nexa_sdk.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// How a host obtains OS permissions for the SDK.
///
/// The SDK never calls platform permission APIs itself: it shows its own
/// rationale sheet and then asks the host through this interface, so the
/// host keeps control over timing and can reuse its own permission flow.
/// This example uses `permission_handler`; any mechanism works as long as
/// `true` is returned only when the permission is actually granted.
final class HostPermissionHandler implements NexaPermissionHandler {
  const HostPermissionHandler();

  @override
  Future<bool> request(NexaPermission permission) async {
    final target = switch (permission) {
      NexaPermission.microphone => ph.Permission.microphone,
      NexaPermission.camera => ph.Permission.camera,
      NexaPermission.location => ph.Permission.locationWhenInUse,
      NexaPermission.notifications => ph.Permission.notification,
    };
    final status = await target.request();
    return status.isGranted || status.isLimited;
  }

  /// Opens the OS settings page so the user can re-enable a denied
  /// permission (wired to the capsule's "Open settings" action).
  static Future<void> openSettings() => ph.openAppSettings();
}
