import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/media/nexa_conversation_media.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// User- and assistant-initiated device actions for the chat and live voice
/// views: take a photo, choose an image, share the current location. Every
/// run goes through the [ClientToolRegistry] (allow-list, argument
/// validation, user approval) and its outcome lands in
/// [NexaConversationMedia]. Nothing is uploaded while the backend has no
/// client-tool / attachment API ([ClientToolResultSink]).
final class NexaDeviceActions {
  NexaDeviceActions({
    required this.options,
    required this.media,
    List<ClientToolExecutor> hostTools = const [],
  }) : store = options.mediaStore ?? NexaMediaStore(),
       sink = options.resultSink ?? const UnavailableClientToolResultSink() {
    final loc = options.locationPlatform ?? const GeolocatorLocationPlatform();
    final net = options.networkPlatform ?? const PluginNetworkPlatform();
    final opener = options.urlOpener ?? const PluginUrlOpener();
    location = LocationTool(platform: loc);
    camera = CameraCaptureTool(media: store, onAttachment: _onCaptured);
    directions = DirectionsTool(opener: opener);
    final tools = <ClientToolExecutor>[
      location,
      camera,
      directions,
      NetworkStatusTool(network: net),
      WifiInfoTool(network: net, location: loc),
      BrowserOpenTool(
        opener: opener,
        allowedHosts: options.browserAllowedHosts,
      ),
      AppOpenTool(apps: options.apps, opener: opener),
      AppsQueryTool(apps: options.apps, opener: opener),
      ShareTool(
        resolveAttachment: _attachmentPath,
        sheet: options.shareSheet ?? const PluginShareSheet(),
      ),
      FilesPickTool(
        media: store,
        picker: options.filePicker ?? const PluginFilePicker(),
        onAttachment: _onCaptured,
      ),
      SettingsOpenTool(location: loc),
      ...options.extraTools,
      ...hostTools,
    ];
    registry = ClientToolRegistry(
      platform: currentToolPlatform,
      enabledToolIds: {
        if (options.location) LocationTool.id,
        if (options.camera) CameraCaptureTool.id,
        if (options.directions) DirectionsTool.id,
        if (options.network) NetworkStatusTool.id,
        if (options.wifi) WifiInfoTool.id,
        if (options.browser) BrowserOpenTool.id,
        if (options.apps.isNotEmpty) ...{AppOpenTool.id, AppsQueryTool.id},
        if (options.share) ShareTool.id,
        if (options.files) FilesPickTool.id,
        if (options.settings) SettingsOpenTool.id,
        for (final t in options.extraTools) t.descriptor.id,
        for (final t in hostTools) t.descriptor.id,
      },
    );
    for (final t in tools) {
      registry.register(t);
    }
    options.toolOverrides.forEach(registry.override);
  }

  String? _attachmentPath(String attachmentId) => media.attachments
      .where((i) => i.attachment.id == attachmentId)
      .firstOrNull
      ?.attachment
      .localPath;

  final NexaClientToolOptions options;
  final NexaConversationMedia media;
  final NexaMediaStore store;
  final ClientToolResultSink sink;
  late final LocationTool location;
  late final CameraCaptureTool camera;
  late final DirectionsTool directions;
  late final ClientToolRegistry registry;
  int _seq = 0;

  bool get canTakePhoto => options.camera;
  bool get canChooseImage => options.photoLibrary;
  bool get canShareLocation => options.location;
  bool get canChooseFile => options.files;
  bool get anyEnabled =>
      canTakePhoto || canChooseImage || canShareLocation || canChooseFile;

  /// File picker → type/size check → attach. Returns an error code
  /// (`unsupported_type`, `too_large`) or null.
  Future<String?> chooseFile({
    NexaItemSurface surface = NexaItemSurface.chat,
  }) async {
    if (!canChooseFile) return null;
    final picked = await (options.filePicker ?? const PluginFilePicker())
        .pickFile();
    if (picked == null) return null;
    final problem = NexaMediaStore.checkFile(picked.name, picked.size);
    if (problem != null) return problem;
    final a = _deliverable(await store.importFile(picked.path, picked.name));
    media.add(
      NexaAttachmentItem(
        id: _id('item'),
        createdAt: a.createdAt,
        attachment: a,
        surface: surface,
      ),
    );
    return null;
  }

  bool get canOpenDirections => options.directions;

  /// Opens directions to [place] (the user tapped "Directions": that tap is
  /// the approval). Uses the Place ID and coordinates the backend returned.
  Future<ClientToolResult> openDirections(
    BuildContext context,
    NexaPlace place, {
    String? travelMode,
    NexaItemSurface surface = NexaItemSurface.chat,
  }) => _run(
    context,
    ClientToolRequest(
      callId: _id('local'),
      toolId: DirectionsTool.id,
      version: 1,
      origin: ClientToolOrigin.user,
      arguments: {
        'place_id': place.placeId,
        'name': place.name,
        'latitude': place.latitude,
        'longitude': place.longitude,
        'travel_mode': ?travelMode,
      },
    ),
    surface: surface,
    preApproved: true,
  );

  /// Shows a backend `places.search_nearby` result (contract
  /// `nexa.places.v1`). Returns false (and shows nothing) when malformed.
  bool showPlaces(
    Map<String, Object?> json, {
    NexaItemSurface surface = NexaItemSurface.chat,
  }) {
    try {
      media.putPlaces(NexaPlacesResult.fromJson(json), surface: surface);
      return true;
    } on FormatException {
      return false;
    }
  }

  NexaItemSurface _surface = NexaItemSurface.chat;

  String _id(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  // ------------------------------------------------------------ actions

  /// Opens the camera (approval → capture → review → attach).
  Future<ClientToolResult> takePhoto(
    BuildContext context, {
    NexaItemSurface surface = NexaItemSurface.chat,
  }) => _run(
    context,
    ClientToolRequest(
      callId: _id('local'),
      toolId: CameraCaptureTool.id,
      version: 1,
      origin: ClientToolOrigin.user,
    ),
    surface: surface,
  );

  /// Runs any registered tool for the user (tool card + inline approval).
  Future<ClientToolResult> runTool(
    BuildContext context,
    String toolId,
    Map<String, Object?> arguments, {
    NexaItemSurface surface = NexaItemSurface.chat,
  }) => _run(
    context,
    ClientToolRequest(
      callId: _id('local'),
      toolId: toolId,
      version: 1,
      arguments: arguments,
      origin: ClientToolOrigin.user,
    ),
    surface: surface,
  );

  /// Reads the current location once (approval → permission → fix).
  Future<ClientToolResult> shareLocation(
    BuildContext context, {
    NexaItemSurface surface = NexaItemSurface.chat,
  }) => _run(
    context,
    ClientToolRequest(
      callId: _id('local'),
      toolId: LocationTool.id,
      version: 1,
      origin: ClientToolOrigin.user,
    ),
    surface: surface,
  );

  /// Runs a backend `client_tool_call` payload (contract
  /// `nexa.client_tool.v1`). Malformed or unknown requests are rejected
  /// without executing anything. Not wired to a transport yet: the backend
  /// sends no such events today.
  Future<ClientToolResult> handleAssistantRequest(
    BuildContext context,
    Map<String, Object?> json, {
    NexaItemSurface surface = NexaItemSurface.chat,
    Future<bool> Function(ClientToolResult result)? deliver,
  }) async {
    final ClientToolRequest request;
    try {
      request = ClientToolRequest.fromJson(json);
    } on FormatException catch (e) {
      final placeholder = ClientToolRequest(
        callId: '${json['call_id'] ?? 'invalid'}',
        toolId: '${json['tool_id'] ?? 'unknown'}',
        version: json['tool_version'] is int ? json['tool_version']! as int : 0,
      );
      final r = ClientToolResult.failure(
        placeholder,
        ClientToolError(ClientToolErrorCode.invalidArguments, e.message),
      );
      await (deliver ?? sink.deliver)(r);
      return r;
    }
    if (!context.mounted) {
      return ClientToolResult.failure(
        request,
        const ClientToolError(ClientToolErrorCode.cancelled, 'no UI'),
      );
    }
    return _run(context, request, surface: surface, deliver: deliver);
  }

  /// Library → preview → attach. Returns the attachment or null.
  Future<NexaAttachment?> chooseImage(
    BuildContext context, {
    NexaItemSurface surface = NexaItemSurface.chat,
  }) async {
    if (!canChooseImage) return null;
    final picker = options.imagePicker ?? const PluginImagePicker();
    final path = await picker.pickFromLibrary();
    if (path == null || !context.mounted) return null;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => nexaScoped(context, _PreviewSheet(path: path)),
    );
    if (ok != true) return null;
    final a = await store.importImage(
      path,
      origin: NexaAttachmentOrigin.uploaded,
    );
    final att = _deliverable(a);
    media.add(
      NexaAttachmentItem(
        id: _id('item'),
        createdAt: att.createdAt,
        attachment: att,
        surface: surface,
      ),
    );
    return att;
  }

  /// "Ask about this image": the next message refers to [attachment].
  void askAbout(NexaAttachment attachment) =>
      media.reference.value = attachment;

  /// Called by the chat when a message is sent: records the image reference
  /// the message carried (not transmitted while the backend cannot).
  void onMessageSent(String text) {
    final ref = media.reference.value;
    if (ref == null) return;
    media
      ..reference.value = null
      ..add(
        NexaAttachmentItem(
          id: _id('ref'),
          createdAt: DateTime.now().toUtc(),
          attachment: _deliverable(ref),
          caption: text,
        ),
      );
  }

  /// Deletes every captured/attached image on this device.
  Future<int> deleteLocalMedia() async {
    final n = await store.deleteAll();
    media.clear();
    return n;
  }

  // ----------------------------------------------------------- internals

  NexaAttachment _deliverable(NexaAttachment a) =>
      sink.acceptsAttachments || a.status == NexaAttachmentStatus.uploaded
      ? a
      : a.copyWith(status: NexaAttachmentStatus.uploadUnavailable);

  void _onCaptured(NexaAttachment a, ClientToolRequest request) {
    final att = _deliverable(a);
    media.add(
      NexaAttachmentItem(
        id: _id('item'),
        createdAt: att.createdAt,
        attachment: att,
        surface: _surface,
      ),
    );
  }

  final Map<String, Completer<bool>> _approvals = {};

  /// Answers the inline approval of tool card [itemId] ("Allow once" /
  /// "Not now"). Ignored when no approval is pending.
  void answerApproval(String itemId, {required bool allow}) {
    final c = _approvals.remove(itemId);
    if (c != null && !c.isCompleted) c.complete(allow);
  }

  bool isAwaitingApproval(String itemId) => _approvals.containsKey(itemId);

  Future<ClientToolResult> _run(
    BuildContext context,
    ClientToolRequest request, {
    required NexaItemSurface surface,
    bool preApproved = false,
    Future<bool> Function(ClientToolResult result)? deliver,
  }) async {
    _surface = surface;
    final descriptor = registry.executorFor(request.toolId)?.descriptor;
    // Every run gets one tool card; approval happens inside it.
    var current = NexaToolRunItem(
      id: _id('tool'),
      createdAt: DateTime.now().toUtc(),
      request: request,
      title: descriptor?.title ?? request.toolId,
      surface: surface,
    );
    media.add(current);

    camera.presenter = (req) async {
      if (!context.mounted) return const CameraCaptureCancelled();
      final outcome = await Navigator.of(context).push<CameraCaptureOutcome>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => nexaScoped(
            context,
            NexaCameraCaptureScreen(
              sessionFactory:
                  options.cameraSessionFactory ?? PluginCameraSession.new,
              onOpenSettings: options.onOpenSettings,
            ),
          ),
        ),
      );
      return outcome ?? const CameraCaptureCancelled();
    };

    final result = await registry.run(
      request,
      approve: (d, r) async {
        if (preApproved) return true;
        final host = options.onApproval;
        if (host != null) return host(d, r);
        final c = Completer<bool>();
        _approvals[current.id] = c;
        media.replace(current); // card now shows Allow once / Not now
        return c.future;
      },
      onPhase: (phase) {
        current = current.copyWith(phase: phase);
        media.replace(current);
      },
    );
    camera.presenter = null;
    _approvals.remove(current.id);
    final delivered = deliver != null
        ? await deliver(result)
        : sink.acceptsResults && await sink.deliver(result);
    media.replace(current.copyWith(result: result, delivered: delivered));
    return result;
  }

  /// Runs [request] again (card "Retry" / "Run again"): replaces the old
  /// card with a new run.
  Future<ClientToolResult> rerun(BuildContext context, NexaToolRunItem item) {
    media.remove(item.id);
    return _run(
      context,
      ClientToolRequest(
        callId: _id('local'),
        toolId: item.request.toolId,
        version: item.request.version,
        arguments: item.request.arguments,
        origin: ClientToolOrigin.user,
      ),
      surface: item.surface,
      preApproved: item.request.toolId == DirectionsTool.id,
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    return SafeArea(
      child: Padding(
        key: const Key('nexa_image_preview'),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.55,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(File(path), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('nexa_image_preview_cancel'),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l10n.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('nexa_image_preview_add'),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l10n.previewAdd),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
