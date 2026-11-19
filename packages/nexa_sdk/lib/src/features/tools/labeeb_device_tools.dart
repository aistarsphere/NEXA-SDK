import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_host_capabilities.dart';
import 'package:nexa_sdk/src/features/media/nexa_conversation_media.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_record_sample.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// What a device tool may use while it runs (all scoped to the current
/// conversation; nothing is uploaded except the user's chosen file).
final class LabeebToolRunContext {
  const LabeebToolRunContext({
    this.context,
    required this.upload,
    required this.download,
    this.theme,
    this.saveThemePreference,
  });

  /// The view presenting device UI; null when none is on screen (only
  /// tools with [LabeebDeviceTool.needsUi] require it).
  final BuildContext? context;

  /// `POST /conversations/{id}/assets`; returns the `ast_*` id.
  final Future<String> Function(Uint8List bytes, String mime, String? name)
  upload;

  /// `GET /assets/{id}/content`.
  final Future<Uint8List> Function(String assetId) download;
  final NexaHostThemeController? theme;

  /// Persists the applied theme with `PUT /me/preferences`.
  final Future<void> Function(String paletteId, NexaAppearance mode)?
  saveThemePreference;
}

/// A `labeeb.sdk/1` client tool, implemented exactly as the contract
/// declares it (arguments in, `result` schema out). Errors use the
/// contract's open code set.
abstract interface class LabeebDeviceTool {
  String get name;

  /// Whether it shows system UI (camera, pickers, share sheet) and so
  /// needs a view on screen.
  bool get needsUi;

  /// Whether this device can run it now (declared in `client_tools`).
  Future<bool> supported();

  Future<NexaToolCallAnswer> run(LabeebToolRunContext ctx, NexaToolCall call);
}

NexaToolCallAnswer _fail(
  String code, [
  String? message,
  bool retryable = false,
]) => NexaToolCallAnswer.failure(
  NexaToolCallError(code, message: message, retryable: retryable),
);

const _uploadMime = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'markdown': 'text/markdown',
  'csv': 'text/csv',
  'json': 'application/json',
};

/// The contract's upload media types by file extension (null: refused).
String? uploadMimeFor(String filename) {
  final dot = filename.lastIndexOf('.');
  return dot < 0
      ? null
      : _uploadMime[filename.substring(dot + 1).toLowerCase()];
}

/// 10 MB (contract `chat.attachments`).
const labeebMaxUploadBytes = 10 * 1024 * 1024;

Future<NexaToolCallAnswer> _uploadFile(
  LabeebToolRunContext ctx,
  String path,
  String name,
) async {
  final mime = uploadMimeFor(name);
  if (mime == null) return _fail('unsupported_media_type', name);
  final file = File(path);
  if (!file.existsSync()) return _fail(NexaDeviceErrorCodes.deviceError);
  if (file.lengthSync() > labeebMaxUploadBytes) {
    return _fail('asset_too_large');
  }
  final id = await ctx.upload(await file.readAsBytes(), mime, name);
  return NexaToolCallAnswer.success({'asset_id': id});
}

/// `device.location.get_current` → `{latitude, longitude, accuracy_m,
/// timestamp}`.
final class LabeebLocationTool implements LabeebDeviceTool {
  LabeebLocationTool(this.platform);
  final LocationPlatform platform;

  @override
  String get name => LabeebTools.location;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    if (!await platform.serviceEnabled()) {
      return _fail(NexaDeviceErrorCodes.unavailable, 'location services off');
    }
    var perm = await platform.permission();
    if (perm == LocationPermissionState.denied ||
        perm == LocationPermissionState.notDetermined) {
      perm = await platform.requestPermission();
    }
    if (perm != LocationPermissionState.granted) {
      return _fail(NexaDeviceErrorCodes.permissionDenied);
    }
    try {
      final fix = await platform.currentFix(
        highAccuracy: call.arguments['accuracy'] != 'coarse',
        timeout: const Duration(seconds: 20),
      );
      return NexaToolCallAnswer.success({
        'latitude': fix.latitude,
        'longitude': fix.longitude,
        'accuracy_m': fix.accuracyMeters,
        'timestamp': fix.timestamp.toUtc().toIso8601String(),
      });
    } on LocationFixException catch (e) {
      return _fail(NexaDeviceErrorCodes.unavailable, e.code.name, true);
    }
  }
}

/// `device.camera.capture` → upload → `{asset_id}`.
final class LabeebCameraTool implements LabeebDeviceTool {
  LabeebCameraTool({this.sessionFactory, this.onOpenSettings});
  final NexaCameraSessionFactory? sessionFactory;
  final VoidCallback? onOpenSettings;

  @override
  String get name => LabeebTools.camera;

  @override
  bool get needsUi => true;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final context = ctx.context;
    if (context == null || !context.mounted) {
      return _fail(NexaDeviceErrorCodes.cancelled);
    }
    final outcome = await Navigator.of(context).push<CameraCaptureOutcome>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => nexaScoped(
          context,
          NexaCameraCaptureScreen(
            sessionFactory: sessionFactory ?? PluginCameraSession.new,
            onOpenSettings: onOpenSettings,
          ),
        ),
      ),
    );
    return switch (outcome) {
      CameraCaptured(:final path) => _uploadFile(
        ctx,
        path,
        'photo-${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
      CameraCaptureFailed(:final code) => _fail(
        code == ClientToolErrorCode.permissionDenied ||
                code == ClientToolErrorCode.permissionBlocked
            ? NexaDeviceErrorCodes.permissionDenied
            : NexaDeviceErrorCodes.unavailable,
      ),
      _ => _fail(NexaDeviceErrorCodes.cancelled),
    };
  }
}

/// `device.photo.pick` → upload → `{asset_id}`.
final class LabeebPhotoPickTool implements LabeebDeviceTool {
  LabeebPhotoPickTool(this.picker);
  final NexaImagePicker picker;

  @override
  String get name => LabeebTools.photoPick;

  @override
  bool get needsUi => true;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final path = await picker.pickFromLibrary();
    if (path == null) return _fail(NexaDeviceErrorCodes.cancelled);
    final name = path.split(Platform.pathSeparator).last;
    return _uploadFile(
      ctx,
      path,
      uploadMimeFor(name) == null ? '$name.jpg' : name,
    );
  }
}

/// `device.file.pick` → upload → `{asset_id}`.
final class LabeebFilePickTool implements LabeebDeviceTool {
  LabeebFilePickTool(this.picker);
  final NexaFilePicker picker;

  @override
  String get name => LabeebTools.filePick;

  @override
  bool get needsUi => true;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final f = await picker.pickFile();
    if (f == null) return _fail(NexaDeviceErrorCodes.cancelled);
    return _uploadFile(ctx, f.path, f.name);
  }
}

/// `maps.open_directions` → `{opened}`. The gateway resolves
/// `destination.place_id` to that exact place's coordinates.
final class LabeebDirectionsTool implements LabeebDeviceTool {
  LabeebDirectionsTool(this.opener);
  final UrlOpener opener;

  @override
  String get name => LabeebTools.directions;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final d = call.arguments['destination'];
    if (d is! Map) return _fail(NexaDeviceErrorCodes.invalidArguments);
    Uri? build({required bool withPlaceId}) => googleMapsDirectionsUrl(
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      placeId: withPlaceId ? d['place_id'] as String? : null,
      name: d['name'] as String?,
      travelMode: call.arguments['mode'] as String?,
    );
    // A gateway-internal place id is not a Google Place ID: fall back to
    // the resolved coordinates (and name).
    final url = build(withPlaceId: true) ?? build(withPlaceId: false);
    if (url == null) return _fail(NexaDeviceErrorCodes.invalidArguments);
    final opened =
        await opener.openInApp(url) || await opener.openInBrowser(url);
    return NexaToolCallAnswer.success({'opened': opened});
  }
}

/// `browser.open_url` → `{opened}`. Opens only the gateway-validated
/// `arguments.url` (https), after the user's approval; never a URL the
/// model wrote into text.
final class LabeebOpenUrlTool implements LabeebDeviceTool {
  LabeebOpenUrlTool(this.opener);
  final UrlOpener opener;

  @override
  String get name => LabeebTools.openUrl;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final raw = call.arguments['url'];
    if (raw is! String || !isHttpsUrl(raw)) {
      return _fail(NexaDeviceErrorCodes.invalidArguments, 'no validated url');
    }
    final opened = await opener.openInBrowser(Uri.parse(raw));
    return NexaToolCallAnswer.success({'opened': opened});
  }
}

/// `device.network.get_status` → `{online, type}` (never network names).
final class LabeebNetworkTool implements LabeebDeviceTool {
  LabeebNetworkTool(this.network);
  final NexaNetworkPlatform network;

  @override
  String get name => LabeebTools.network;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final types = await network.connectionTypes();
    final type = types.contains('wifi')
        ? 'wifi'
        : types.contains('mobile') || types.contains('cellular')
        ? 'cellular'
        : types.contains('ethernet')
        ? 'ethernet'
        : types.isEmpty || types.every((t) => t == 'none')
        ? 'none'
        : 'unknown';
    return NexaToolCallAnswer.success({'online': type != 'none', 'type': type});
  }
}

/// `device.share.content` → `{shared}` (the user picks the target).
final class LabeebShareTool implements LabeebDeviceTool {
  LabeebShareTool(this.sheet);
  final NexaShareSheet sheet;

  @override
  String get name => LabeebTools.share;

  @override
  bool get needsUi => true;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final a = call.arguments;
    final text = [
      if (a['title'] is String) a['title']! as String,
      if (a['text'] is String) a['text']! as String,
    ].join('\n');
    final files = <String>[];
    if (a['asset_id'] case final String assetId) {
      final bytes = await ctx.download(assetId);
      final f = File('${Directory.systemTemp.path}/nexa_share_$assetId');
      await f.writeAsBytes(bytes, flush: true);
      files.add(f.path);
    }
    if (text.isEmpty && files.isEmpty) {
      return _fail(NexaDeviceErrorCodes.invalidArguments);
    }
    final status = await sheet.share(
      text: text.isEmpty ? null : text,
      filePaths: files,
    );
    for (final p in files) {
      final f = File(p);
      if (f.existsSync()) await f.delete();
    }
    return NexaToolCallAnswer.success({'shared': status == 'success'});
  }
}

/// `device.app.open_settings` → `{opened}`.
final class LabeebSettingsTool implements LabeebDeviceTool {
  LabeebSettingsTool(this.location, {this.onOpenSettings});
  final LocationPlatform location;
  final Future<bool> Function()? onOpenSettings;

  @override
  String get name => LabeebTools.openSettings;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final section = call.arguments['section'] as String? ?? 'app';
    final opened = section == 'location' && !Platform.isIOS
        ? await location.openLocationSettings()
        : await (onOpenSettings?.call() ?? location.openAppSettings());
    return NexaToolCallAnswer.success({'opened': opened});
  }
}

/// Converts `#RRGGBB` (contract palette colors) to a [Color].
Color? colorFromHex(Object? v) {
  if (v is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v)) return null;
  return Color(int.parse('FF${v.substring(1)}', radix: 16));
}

/// The theme a server-resolved `app.theme.apply` call asks for.
NexaThemeSpec? themeSpecOf(NexaToolCall call) {
  final id = call.arguments['palette_id'];
  if (id is! String) return null;
  final colors = <String, Color>{};
  if (call.arguments['colors'] case final Map<Object?, Object?> c) {
    for (final MapEntry(:key, :value) in c.entries) {
      final color = colorFromHex(value);
      if (key is String && color != null) colors[key] = color;
    }
  }
  return NexaThemeSpec(
    paletteId: id,
    colors: colors,
    appearance:
        appearanceFromWire(call.arguments['mode']) ?? NexaAppearance.system,
  );
}

/// `app.theme.apply` → `{status: applied|cancelled, palette_id?, mode?}`.
/// Registered only when the host provides a theme controller. The host
/// previews; nothing is applied without the user's confirmation, which is
/// the approval step (see the tool-call controller).
final class LabeebThemeApplyTool implements LabeebDeviceTool {
  const LabeebThemeApplyTool();

  @override
  String get name => LabeebTools.themeApply;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final theme = ctx.theme;
    final spec = themeSpecOf(call);
    if (theme == null) return _fail(NexaDeviceErrorCodes.unsupported);
    if (spec == null) return _fail(NexaDeviceErrorCodes.invalidArguments);
    if (!await theme.applySpec(spec)) {
      await theme.cancelPreview();
      return const NexaToolCallAnswer.success({'status': 'cancelled'});
    }
    await ctx.saveThemePreference?.call(spec.paletteId, spec.appearance);
    return NexaToolCallAnswer.success({
      'status': 'applied',
      'palette_id': spec.paletteId,
      'mode': spec.appearance.name,
    });
  }
}

/// `app.theme.reset` → `{status: reset|cancelled}`.
final class LabeebThemeResetTool implements LabeebDeviceTool {
  const LabeebThemeResetTool();

  @override
  String get name => LabeebTools.themeReset;

  @override
  bool get needsUi => false;

  @override
  Future<bool> supported() async => true;

  @override
  Future<NexaToolCallAnswer> run(
    LabeebToolRunContext ctx,
    NexaToolCall call,
  ) async {
    final theme = ctx.theme;
    if (theme == null) return _fail(NexaDeviceErrorCodes.unsupported);
    final ok = await theme.reset();
    if (ok) {
      await ctx.saveThemePreference?.call(
        theme.appliedPaletteId,
        theme.appliedAppearance,
      );
    }
    return NexaToolCallAnswer.success({'status': ok ? 'reset' : 'cancelled'});
  }
}

/// The device tools this client offers, from the host's options.
List<LabeebDeviceTool> labeebDeviceTools(
  NexaClientToolOptions o, {
  NexaHostThemeController? theme,
}) {
  final loc = o.locationPlatform ?? const GeolocatorLocationPlatform();
  final opener = o.urlOpener ?? const PluginUrlOpener();
  return [
    if (o.location) LabeebLocationTool(loc),
    if (o.camera)
      LabeebCameraTool(
        sessionFactory: o.cameraSessionFactory,
        onOpenSettings: o.onOpenSettings,
      ),
    if (o.photoLibrary)
      LabeebPhotoPickTool(o.imagePicker ?? const PluginImagePicker()),
    if (o.files) LabeebFilePickTool(o.filePicker ?? const PluginFilePicker()),
    if (o.directions) LabeebDirectionsTool(opener),
    if (o.browser) LabeebOpenUrlTool(opener),
    if (o.network)
      LabeebNetworkTool(o.networkPlatform ?? const PluginNetworkPlatform()),
    if (o.share) LabeebShareTool(o.shareSheet ?? const PluginShareSheet()),
    if (o.settings)
      LabeebSettingsTool(
        loc,
        onOpenSettings: o.onOpenSettings == null
            ? null
            : () async {
                o.onOpenSettings!();
                return true;
              },
      ),
    if (o.microphoneSample)
      LabeebRecordSampleTool(
        recorder: o.microphoneRecorder,
        onOpenSettings: o.onOpenSettings,
      ),
    // Theme tools only with a host theme callback (contract `theme`).
    if (theme != null) ...const [
      LabeebThemeApplyTool(),
      LabeebThemeResetTool(),
    ],
  ];
}
