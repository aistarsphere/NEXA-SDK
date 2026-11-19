import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/src/camera_capture.dart';
import 'package:nexa_device/src/media_store.dart';

/// Shows the capture UI for one request (set by the SDK view that is on
/// screen: chat or live voice).
typedef CameraCapturePresenter =
    Future<CameraCaptureOutcome> Function(ClientToolRequest request);

/// `device.camera.capture` v1: one photo the user takes, reviews and
/// approves ("Use photo"). The image is stored on the device and attached
/// to the conversation via [onAttachment]; the result carries attachment
/// metadata only. No continuous capture, no automatic upload, no claim of
/// vision analysis.
final class CameraCaptureTool implements ClientToolExecutor {
  CameraCaptureTool({required this.media, this.onAttachment});

  static const id = 'device.camera.capture';

  final NexaMediaStore media;

  /// Called with the approved photo (before the result is returned).
  void Function(NexaAttachment attachment, ClientToolRequest request)?
  onAttachment;

  /// Null while no SDK view can present the camera.
  CameraCapturePresenter? presenter;

  @override
  final ClientToolDescriptor descriptor = const ClientToolDescriptor(
    id: id,
    version: 1,
    title: 'Take a photo',
    requiredPermissions: {ClientToolPermission.camera},
    inputSchema: {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'reason': {'type': 'string'},
        'facing': {
          'type': 'string',
          'enum': ['back'],
        },
      },
    },
    outputSchema: {
      'type': 'object',
      'required': ['attachment'],
      'properties': {
        'attachment': {
          'type': 'object',
          'description': 'NexaAttachment metadata (no bytes, no paths)',
        },
      },
    },
  );

  @override
  /// Available: the SDK view that runs the tool attaches the camera UI
  /// ([presenter]) for each run; a run without one fails as unsupported.
  Future<ClientToolAvailability> availability() async =>
      ClientToolAvailability.available;

  @override
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  }) async {
    final present = presenter;
    if (present == null) {
      return ClientToolResult.failure(
        request,
        const ClientToolError(
          ClientToolErrorCode.unsupported,
          'no camera UI on screen',
        ),
      );
    }
    onPhase(ClientToolRunPhase.awaitingPermission);
    final outcome = await present(request);
    onPhase(ClientToolRunPhase.running);
    switch (outcome) {
      case CameraCaptureCancelled():
        return ClientToolResult.failure(
          request,
          const ClientToolError(ClientToolErrorCode.cancelled, 'cancelled'),
        );
      case CameraCaptureFailed(:final code):
        return ClientToolResult.failure(
          request,
          ClientToolError(
            code,
            code.name,
            retryable: code != ClientToolErrorCode.unsupported,
            canOpenSettings:
                code == ClientToolErrorCode.permissionBlocked ||
                code == ClientToolErrorCode.permissionDenied,
          ),
        );
      case CameraCaptured(:final path):
        final attachment = await media.importImage(
          path,
          origin: NexaAttachmentOrigin.captured,
          toolCallId: request.callId,
        );
        onAttachment?.call(attachment, request);
        return ClientToolResult.success(request, {
          'attachment': attachment.toJson(),
        });
    }
  }
}
