import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Why the camera could not open.
final class CameraOpenException implements Exception {
  const CameraOpenException(this.code);
  final ClientToolErrorCode code;
}

/// One camera use: open → preview → take picture → close.
abstract interface class NexaCameraSession {
  /// Throws [CameraOpenException]. Triggers the OS permission prompt.
  Future<void> open();
  Widget buildPreview(BuildContext context);

  /// Returns the path of the captured JPEG.
  Future<String> takePicture();
  Future<void> close();
}

typedef NexaCameraSessionFactory = NexaCameraSession Function();

/// The `camera` plugin: back camera, no audio (so a live voice call keeps
/// its audio session), JPEG.
final class PluginCameraSession implements NexaCameraSession {
  cam.CameraController? _controller;

  @override
  Future<void> open() async {
    final List<cam.CameraDescription> cameras;
    try {
      cameras = await cam.availableCameras();
    } on cam.CameraException catch (e) {
      throw CameraOpenException(_map(e.code));
    }
    if (cameras.isEmpty) {
      throw const CameraOpenException(ClientToolErrorCode.unsupported);
    }
    final back = cameras.firstWhere(
      (c) => c.lensDirection == cam.CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = cam.CameraController(
      back,
      cam.ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: cam.ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } on cam.CameraException catch (e) {
      await controller.dispose();
      throw CameraOpenException(_map(e.code));
    }
    _controller = controller;
  }

  static ClientToolErrorCode _map(String code) => switch (code) {
    'CameraAccessDenied' => ClientToolErrorCode.permissionDenied,
    'CameraAccessDeniedWithoutPrompt' ||
    'CameraAccessRestricted' => ClientToolErrorCode.permissionBlocked,
    'cameraNotFound' || 'noCamerasAvailable' => ClientToolErrorCode.unsupported,
    _ => ClientToolErrorCode.deviceError,
  };

  @override
  Widget buildPreview(BuildContext context) {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return const SizedBox.shrink();
    return cam.CameraPreview(c);
  }

  @override
  Future<String> takePicture() async {
    final c = _controller;
    if (c == null) throw StateError('camera not open');
    return (await c.takePicture()).path;
  }

  @override
  Future<void> close() async {
    final c = _controller;
    _controller = null;
    await c?.dispose();
  }
}

/// Result of [NexaCameraCaptureScreen].
sealed class CameraCaptureOutcome {
  const CameraCaptureOutcome();
}

final class CameraCaptured extends CameraCaptureOutcome {
  const CameraCaptured(this.path);
  final String path;
}

final class CameraCaptureCancelled extends CameraCaptureOutcome {
  const CameraCaptureCancelled();
}

final class CameraCaptureFailed extends CameraCaptureOutcome {
  const CameraCaptureFailed(this.code);
  final ClientToolErrorCode code;
}

/// Full-screen capture: live preview with an explanation, an explicit
/// capture button, then Retake / Use photo / Cancel. Nothing leaves the
/// screen unless the user taps Use photo. Pops with a
/// [CameraCaptureOutcome]. The camera closes when the app goes to the
/// background and on exit.
class NexaCameraCaptureScreen extends StatefulWidget {
  const NexaCameraCaptureScreen({
    required this.sessionFactory,
    this.onOpenSettings,
    super.key,
  });

  final NexaCameraSessionFactory sessionFactory;
  final VoidCallback? onOpenSettings;

  @override
  State<NexaCameraCaptureScreen> createState() =>
      _NexaCameraCaptureScreenState();
}

enum _Stage { opening, preview, capturing, review, error }

class _NexaCameraCaptureScreenState extends State<NexaCameraCaptureScreen>
    with WidgetsBindingObserver {
  NexaCameraSession? _session;
  _Stage _stage = _Stage.opening;
  ClientToolErrorCode? _error;
  String? _captured;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_session?.close());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final s = _session;
      _session = null;
      unawaited(s?.close());
    } else if (state == AppLifecycleState.resumed &&
        _session == null &&
        _stage != _Stage.review &&
        mounted) {
      unawaited(_open());
    }
  }

  Future<void> _open() async {
    setState(() {
      _stage = _Stage.opening;
      _error = null;
    });
    final session = widget.sessionFactory();
    try {
      await session.open();
    } on CameraOpenException catch (e) {
      await session.close();
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = e.code;
      });
      return;
    }
    if (!mounted) {
      await session.close();
      return;
    }
    setState(() {
      _session = session;
      _stage = _captured == null ? _Stage.preview : _Stage.review;
    });
  }

  Future<void> _capture() async {
    final s = _session;
    if (s == null || _stage != _Stage.preview) return;
    setState(() => _stage = _Stage.capturing);
    try {
      final path = await s.takePicture();
      if (!mounted) return;
      setState(() {
        _captured = path;
        _stage = _Stage.review;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _stage = _Stage.error;
        _error = ClientToolErrorCode.deviceError;
      });
    }
  }

  void _finish(CameraCaptureOutcome outcome) =>
      Navigator.of(context).pop(outcome);

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finish(
            _error != null
                ? CameraCaptureFailed(_error!)
                : const CameraCaptureCancelled(),
          );
        }
      },
      child: Scaffold(
        key: const Key('nexa_camera_screen'),
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          // Visible the whole time the camera is open (design B2).
          title: _stage == _Stage.error || _stage == _Stage.review
              ? null
              : Container(
                  key: const Key('nexa_camera_on'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3261E),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    l10n.cameraOn,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
          centerTitle: true,
          leading: IconButton(
            key: const Key('nexa_camera_cancel'),
            tooltip: l10n.cancel,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _finish(
              _error != null
                  ? CameraCaptureFailed(_error!)
                  : const CameraCaptureCancelled(),
            ),
          ),
        ),
        body: SafeArea(
          child: switch (_stage) {
            _Stage.error => _ErrorBody(
              code: _error ?? ClientToolErrorCode.deviceError,
              onRetry: _open,
              onOpenSettings: widget.onOpenSettings,
            ),
            _ => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    l10n.cameraExplain,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: _stage == _Stage.review && _captured != null
                        ? Image.file(
                            File(_captured!),
                            key: const Key('nexa_camera_review'),
                            fit: BoxFit.contain,
                          )
                        : _session == null
                        ? const Center(child: CircularProgressIndicator())
                        : _session!.buildPreview(context),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _stage == _Stage.review
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                key: const Key('nexa_camera_retake'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                ),
                                onPressed: () => setState(() {
                                  _captured = null;
                                  _stage = _session == null
                                      ? _Stage.opening
                                      : _Stage.preview;
                                  if (_session == null) unawaited(_open());
                                }),
                                child: Text(l10n.cameraRetake),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                key: const Key('nexa_camera_use'),
                                onPressed: () =>
                                    _finish(CameraCaptured(_captured!)),
                                child: Text(l10n.cameraUsePhoto),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Semantics(
                            button: true,
                            label: l10n.cameraCapture,
                            child: InkWell(
                              key: const Key('nexa_camera_shutter'),
                              customBorder: const CircleBorder(),
                              onTap: _stage == _Stage.preview ? _capture : null,
                              child: Container(
                                width: 76,
                                height: 76,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _stage == _Stage.preview
                                        ? Colors.white
                                        : Colors.white38,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({
    required this.code,
    required this.onRetry,
    this.onOpenSettings,
  });

  final ClientToolErrorCode code;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final blocked =
        code == ClientToolErrorCode.permissionBlocked ||
        code == ClientToolErrorCode.permissionDenied;
    final text = switch (code) {
      ClientToolErrorCode.permissionBlocked ||
      ClientToolErrorCode.permissionDenied => l10n.cameraDenied,
      ClientToolErrorCode.unsupported => l10n.cameraUnavailable,
      _ => l10n.cameraError,
    };
    return Center(
      key: const Key('nexa_camera_error'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 20),
            if (blocked && onOpenSettings != null)
              FilledButton(
                key: const Key('nexa_camera_settings'),
                onPressed: onOpenSettings,
                child: Text(l10n.openSettings),
              )
            else if (code != ClientToolErrorCode.unsupported)
              FilledButton(
                key: const Key('nexa_camera_retry'),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
          ],
        ),
      ),
    );
  }
}
