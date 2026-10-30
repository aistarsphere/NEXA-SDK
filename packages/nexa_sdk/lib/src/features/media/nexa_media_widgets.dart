import 'dart:io';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/media/nexa_device_actions.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// "Add to conversation": photo, library, location (each only when the
/// host enabled it).
Future<void> showNexaAttachSheet(
  BuildContext context,
  NexaDeviceActions actions, {
  NexaItemSurface surface = NexaItemSurface.chat,
}) async {
  final l10n = NexaLocalizations.of(context);
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (sheetContext) => nexaScoped(
      context,
      SafeArea(
        child: Column(
          key: const Key('nexa_attach_sheet'),
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                l10n.attachTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            if (actions.canTakePhoto)
              ListTile(
                key: const Key('nexa_attach_camera'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l10n.attachTakePhoto),
                onTap: () => Navigator.pop(sheetContext, 'camera'),
              ),
            if (actions.canChooseImage)
              ListTile(
                key: const Key('nexa_attach_library'),
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.attachChooseImage),
                onTap: () => Navigator.pop(sheetContext, 'library'),
              ),
            if (actions.canChooseFile)
              ListTile(
                key: const Key('nexa_attach_file'),
                leading: const Icon(Icons.attach_file_rounded),
                title: Text(l10n.attachChooseFile),
                onTap: () => Navigator.pop(sheetContext, 'file'),
              ),
            if (actions.canShareLocation)
              ListTile(
                key: const Key('nexa_attach_location'),
                leading: const Icon(Icons.my_location_rounded),
                title: Text(l10n.attachShareLocation),
                onTap: () => Navigator.pop(sheetContext, 'location'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'camera':
      await actions.takePhoto(context, surface: surface);
    case 'library':
      await actions.chooseImage(context, surface: surface);
    case 'location':
      await actions.shareLocation(context, surface: surface);
    case 'file':
      final messenger = ScaffoldMessenger.maybeOf(context);
      final problem = await actions.chooseFile(surface: surface);
      if (problem != null) {
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              problem == 'too_large' ? l10n.fileTooLarge : l10n.fileUnsupported,
            ),
          ),
        );
      }
  }
}

/// Opens [a] full-screen; "Ask about this image" sets the reference.
void openNexaImage(
  BuildContext context,
  NexaAttachment a,
  NexaDeviceActions? actions,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => nexaScoped(
      context,
      NexaImageViewer(
        attachment: a,
        onAskAbout: actions == null ? null : () => actions.askAbout(a),
      ),
    ),
  ),
);

/// An image or file in the conversation, with its delivery state: uploading
/// (progress + cancel), failed (retry), cancelled, or on this device only
/// while the service cannot receive attachments. Assistant images carry the
/// AI badge.
class NexaAttachmentBubble extends StatelessWidget {
  const NexaAttachmentBubble({
    required this.item,
    this.onOpen,
    this.onCancel,
    this.onRetry,
    super.key,
  });

  final NexaAttachmentItem item;
  final VoidCallback? onOpen;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = item.attachment;
    final isReference = item.caption != null;
    final status = switch (a.status) {
      NexaAttachmentStatus.uploadUnavailable =>
        isReference ? l10n.referenceNotSent : l10n.attachmentNotSent,
      NexaAttachmentStatus.uploading => l10n.attachmentUploading,
      NexaAttachmentStatus.failed => l10n.attachmentFailed,
      NexaAttachmentStatus.cancelled => l10n.attachmentCancelled,
      _ => null,
    };
    final path = a.localPath;
    final image = path != null && File(path).existsSync()
        ? Image.file(File(path), fit: BoxFit.cover)
        : a.remoteUrl != null
        ? Image.network(a.remoteUrl.toString(), fit: BoxFit.cover)
        : ColoredBox(
            color: scheme.surfaceContainerHigh,
            child: const Icon(Icons.image_not_supported_outlined),
          );
    final size = isReference ? 56.0 : 220.0;
    final ai =
        a.origin == NexaAttachmentOrigin.generated ||
        a.origin == NexaAttachmentOrigin.edited;
    return Align(
      alignment: item.fromUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          key: Key('nexa_attachment_${a.id}'),
          crossAxisAlignment: item.fromUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Semantics(
              image: true,
              button: onOpen != null,
              label: l10n.imageReference,
              child: GestureDetector(
                onTap: onOpen,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!a.isImage)
                      _FileCard(attachment: a)
                    else
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              isReference ? 12 : 20,
                            ),
                            child: SizedBox(
                              width: size,
                              height: isReference ? size : size * 0.75,
                              child: image,
                            ),
                          ),
                          if (ai)
                            PositionedDirectional(
                              top: 8,
                              start: 8,
                              child: Container(
                                key: const Key('nexa_ai_badge'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.inverseSurface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  a.origin == NexaAttachmentOrigin.edited
                                      ? l10n.imageEdited
                                      : l10n.imageGenerated,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.onInverseSurface,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    if (isReference) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          '${l10n.imageReference}: ${item.caption}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (a.status == NexaAttachmentStatus.uploading)
              SizedBox(
                width: 220,
                child: Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        key: const Key('nexa_attachment_progress'),
                        value: a.progress,
                      ),
                    ),
                    if (onCancel != null)
                      IconButton(
                        key: const Key('nexa_attachment_cancel'),
                        tooltip: l10n.attachmentCancel,
                        onPressed: onCancel,
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                  ],
                ),
              ),
            if (a.status == NexaAttachmentStatus.failed && onRetry != null)
              TextButton(
                key: const Key('nexa_attachment_retry'),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
            if (status != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      status,
                      key: const Key('nexa_attachment_status'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A client tool run on the shared [NexaToolCard]: inline approval
/// ("Allow once" / "Not now"), running, structured result rows, denied /
/// error / cancelled / unavailable / setup with the matching actions, and
/// whether the result reached the assistant.
class NexaToolRunCard extends StatelessWidget {
  const NexaToolRunCard({required this.item, this.actions, super.key});

  final NexaToolRunItem item;
  final NexaDeviceActions? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final a = actions;
    final tool = item.request.toolId;
    final result = item.result;
    final error = result?.error;
    final (icon, name, where) = switch (tool) {
      LocationTool.id => (
        Icons.my_location_rounded,
        l10n.toolLocationName,
        l10n.toolWhereDevice,
      ),
      CameraCaptureTool.id => (
        Icons.photo_camera_outlined,
        l10n.toolCameraName,
        l10n.toolWhereDevice,
      ),
      DirectionsTool.id => (
        Icons.navigation_outlined,
        l10n.toolDirectionsName,
        l10n.toolWhereOtherApp,
      ),
      NetworkStatusTool.id => (
        Icons.network_check_rounded,
        l10n.toolNetworkName,
        l10n.toolWhereDevice,
      ),
      WifiInfoTool.id => (
        Icons.wifi_rounded,
        l10n.toolWifiName,
        l10n.toolWhereDevice,
      ),
      BrowserOpenTool.id => (
        Icons.open_in_browser_rounded,
        l10n.toolBrowserName,
        l10n.toolWhereOtherApp,
      ),
      AppOpenTool.id => (
        Icons.launch_rounded,
        l10n.toolAppName,
        l10n.toolWhereOtherApp,
      ),
      AppsQueryTool.id => (
        Icons.apps_rounded,
        l10n.toolAppsName,
        l10n.toolWhereDevice,
      ),
      ShareTool.id => (
        Icons.ios_share_rounded,
        l10n.toolShareName,
        l10n.toolWhereOtherApp,
      ),
      FilesPickTool.id => (
        Icons.attach_file_rounded,
        l10n.toolFilesName,
        l10n.toolWhereDevice,
      ),
      SettingsOpenTool.id => (
        Icons.settings_outlined,
        l10n.toolSettingsName,
        l10n.toolWhereOtherApp,
      ),
      _ => (Icons.extension_outlined, item.title, l10n.toolWhereDevice),
    };
    final external = const {
      DirectionsTool.id,
      BrowserOpenTool.id,
      AppOpenTool.id,
      ShareTool.id,
      SettingsOpenTool.id,
    }.contains(tool);
    final waitingApproval =
        result == null &&
        (item.phase == ClientToolRunPhase.awaitingApproval ||
            item.phase == ClientToolRunPhase.requested);
    final state = switch ((result, error?.code)) {
      (null, _) when waitingApproval => NexaToolCardState.approval,
      (null, _) => NexaToolCardState.running,
      (final r?, _) when r.isSuccess => NexaToolCardState.success,
      (
        _,
        ClientToolErrorCode.permissionDenied ||
            ClientToolErrorCode.permissionBlocked ||
            ClientToolErrorCode.serviceDisabled,
      ) =>
        NexaToolCardState.denied,
      (_, ClientToolErrorCode.userDeclined || ClientToolErrorCode.cancelled) =>
        NexaToolCardState.cancelled,
      (_, ClientToolErrorCode.unsupported) => NexaToolCardState.unavailable,
      (
        _,
        ClientToolErrorCode.disabledByHost || ClientToolErrorCode.notGranted,
      ) =>
        NexaToolCardState.setup,
      _ => NexaToolCardState.error,
    };
    final message = switch (state) {
      NexaToolCardState.approval => switch (tool) {
        CameraCaptureTool.id => l10n.toolCameraApproval,
        LocationTool.id => l10n.toolLocationApproval,
        _ =>
          external
              ? l10n.toolApprovalExternal(name)
              : l10n.toolApprovalPersonal(name),
      },
      NexaToolCardState.running => switch (tool) {
        CameraCaptureTool.id => l10n.toolCameraRunning,
        LocationTool.id => l10n.locationWorking,
        _ => l10n.toolWorking,
      },
      NexaToolCardState.success => switch (tool) {
        CameraCaptureTool.id => l10n.toolCameraSuccess,
        DirectionsTool.id => l10n.toolDirectionsSuccess,
        LocationTool.id => l10n.locationResultTitle,
        _ => l10n.toolDoneGeneric,
      },
      NexaToolCardState.denied => switch (error?.code) {
        ClientToolErrorCode.serviceDisabled => l10n.locationServiceOff,
        _ => l10n.toolDenied,
      },
      NexaToolCardState.cancelled => l10n.toolCancelled,
      NexaToolCardState.unavailable =>
        tool == CameraCaptureTool.id
            ? l10n.cameraUnavailable
            : l10n.toolUnavailable,
      NexaToolCardState.setup => l10n.toolSetup,
      NexaToolCardState.error => switch (error?.code) {
        ClientToolErrorCode.timeout => l10n.locationTimeout,
        ClientToolErrorCode.fileTooLarge => l10n.toolFileTooLarge,
        ClientToolErrorCode.fileTypeUnsupported => l10n.toolFileUnsupported,
        _ => l10n.toolError,
      },
    };
    final rows = <(String, String)>[];
    final out = result?.output;
    if (state == NexaToolCardState.success && out != null) {
      switch (tool) {
        case LocationTool.id:
          rows
            ..add((
              l10n.toolRowCoordinates,
              '${(out['latitude']! as num).toStringAsFixed(5)}, '
                  '${(out['longitude']! as num).toStringAsFixed(5)}',
            ))
            ..add((
              l10n.toolRowAccuracy,
              l10n.toolAboutMeters((out['accuracy_m']! as num).round()),
            ))
            ..add((l10n.toolRowShared, l10n.toolRowSharedOnce));
        case CameraCaptureTool.id:
          final att = (out['attachment'] as Map?) ?? const {};
          final bytes = att['byte_length'] as int?;
          rows
            ..add((
              l10n.toolRowPhoto,
              bytes == null
                  ? '1'
                  : '1 · ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB',
            ))
            ..add((l10n.toolRowSentAs, l10n.attachmentNotSent));
        case DirectionsTool.id:
          rows
            ..add((
              l10n.toolRowDestination,
              '${item.request.arguments['name'] ?? ''}',
            ))
            ..add((
              l10n.toolRowOpenedIn,
              out['opened_in'] == 'app'
                  ? l10n.toolOpenedApp
                  : l10n.toolOpenedBrowser,
            ));
        case NetworkStatusTool.id:
          final types = (out['types'] as List?)?.join(', ') ?? '';
          rows.add((l10n.toolRowNetwork, types.isEmpty ? '—' : types));
        case WifiInfoTool.id:
          rows.add((
            l10n.toolWifiName,
            out['ssid'] as String? ??
                (out['on_wifi'] == true ? l10n.toolRowSsidHidden : '—'),
          ));
        case BrowserOpenTool.id:
          rows.add((l10n.toolRowWebsite, '${out['url']}'));
        case AppOpenTool.id:
          rows
            ..add((l10n.toolRowApp, '${out['app_id']}'))
            ..add((
              l10n.toolRowOpenedIn,
              out['opened_in'] == 'app'
                  ? l10n.toolOpenedApp
                  : l10n.toolOpenedBrowser,
            ));
        case ShareTool.id:
          rows.add((l10n.toolRowStatus, '${out['status']}'));
        case FilesPickTool.id:
          final att = (out['attachment'] as Map?) ?? const {};
          rows.add((l10n.toolRowFile, '${att['name'] ?? ''}'));
        case AppsQueryTool.id:
          for (final a in (out['apps'] as List?) ?? const []) {
            if (a is Map) rows.add(('${a['name']}', '${a['installed']}'));
          }
      }
    }
    final List<NexaToolCardAction> buttons;
    switch (state) {
      case NexaToolCardState.approval:
        final pending = a?.isAwaitingApproval(item.id) ?? false;
        buttons = [
          NexaToolCardAction(
            l10n.toolNotNow,
            pending ? () => a!.answerApproval(item.id, allow: false) : null,
            key: const Key('nexa_tool_decline'),
          ),
          NexaToolCardAction(
            l10n.toolAllowOnce,
            pending ? () => a!.answerApproval(item.id, allow: true) : null,
            primary: true,
            key: const Key('nexa_tool_allow'),
          ),
        ];
      case NexaToolCardState.running:
        buttons = const [];
      case NexaToolCardState.denied:
        buttons = [
          if (error?.retryable ?? false)
            NexaToolCardAction(
              l10n.retry,
              a == null ? null : () => a.rerun(context, item),
              key: const Key('nexa_tool_retry'),
            ),
          if ((error?.canOpenSettings ?? false) &&
              a?.options.onOpenSettings != null)
            NexaToolCardAction(
              l10n.openSettings,
              a!.options.onOpenSettings,
              primary: true,
              key: const Key('nexa_tool_settings'),
            ),
        ];
      case NexaToolCardState.error:
        buttons = [
          if (error?.retryable ?? true)
            NexaToolCardAction(
              l10n.retry,
              a == null ? null : () => a.rerun(context, item),
              primary: true,
              key: const Key('nexa_tool_retry'),
            ),
        ];
      case NexaToolCardState.cancelled:
        buttons = [
          NexaToolCardAction(
            l10n.toolRunAgain,
            a == null ? null : () => a.rerun(context, item),
            key: const Key('nexa_tool_retry'),
          ),
        ];
      case NexaToolCardState.success ||
          NexaToolCardState.unavailable ||
          NexaToolCardState.setup:
        buttons = const [];
    }
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          key: Key('nexa_tool_run_${item.id}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NexaToolCard(
              icon: icon,
              name: name,
              where: where,
              origin: NexaToolOrigin.device,
              state: state,
              message: message,
              rows: rows,
              actions: buttons,
            ),
            if (state == NexaToolCardState.success &&
                tool == LocationTool.id &&
                !item.delivered)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
                child: Text(
                  l10n.toolNotDelivered,
                  key: const Key('nexa_tool_not_delivered'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  const _FileCard({required this.attachment});
  final NexaAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = attachment;
    final name = a.name ?? a.id;
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    final icon = switch (ext) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'xlsx' || 'csv' => Icons.table_chart_outlined,
      'docx' || 'txt' => Icons.description_outlined,
      'pptx' => Icons.slideshow_outlined,
      _ => Icons.insert_drive_file_outlined,
    };
    final bytes = a.byteLength;
    final size = bytes == null
        ? ''
        : bytes >= 1024 * 1024
        ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '${(bytes / 1024).ceil()} KB';
    return Container(
      key: Key('nexa_file_${a.id}'),
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: nexaTextDirectionOf(name),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  size,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The image the next message will refer to, above the composer.
class NexaReferenceChip extends StatelessWidget {
  const NexaReferenceChip({
    required this.attachment,
    required this.onClear,
    super.key,
  });

  final NexaAttachment attachment;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final path = attachment.localPath;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 14, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: InputChip(
          key: const Key('nexa_reference_chip'),
          avatar: path == null
              ? const Icon(Icons.image_outlined)
              : ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    File(path),
                    width: 24,
                    height: 24,
                    fit: BoxFit.cover,
                  ),
                ),
          label: Text(l10n.imageReference),
          onDeleted: onClear,
          deleteButtonTooltipMessage: l10n.cancel,
        ),
      ),
    );
  }
}

/// Attachments of the conversation as a strip (live voice), so content
/// shown during a call is visible there too.
class NexaMediaTray extends StatelessWidget {
  const NexaMediaTray({required this.items, required this.onOpen, super.key});

  final List<NexaAttachmentItem> items;
  final ValueChanged<NexaAttachment> onOpen;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 72,
      child: ListView.separated(
        key: const Key('nexa_media_tray'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = items[i].attachment;
          final path = a.localPath;
          return GestureDetector(
            onTap: () => onOpen(a),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox.square(
                dimension: 64,
                child: path != null && File(path).existsSync()
                    ? Image.file(File(path), fit: BoxFit.cover)
                    : const Icon(Icons.image_outlined),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Nearby places from the backend's `places.search_nearby`: numbered
/// cards (the number is what "the second one" refers to) with name,
/// category, rating, distance and address when the provider gave them,
/// and Directions. Loading / empty / location-denied / error states.
class NexaPlacesCard extends StatelessWidget {
  const NexaPlacesCard({
    required this.item,
    this.onDirections,
    this.onRetry,
    this.onOpenSettings,
    this.onSelect,
    this.selectedPlaceId,
    this.compact = false,
    super.key,
  });

  /// Tapping a place selects it as conversation context.
  final ValueChanged<NexaPlace>? onSelect;
  final String? selectedPlaceId;

  final NexaPlacesItem item;
  final ValueChanged<NexaPlace>? onDirections;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenSettings;

  /// Live voice: a horizontal strip instead of a list.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = item.result;
    Widget message(String text, {List<Widget> actions = const []}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, key: const Key('nexa_places_message')),
        if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
      ],
    );
    final Widget body = switch (r.status) {
      NexaPlacesStatus.loading => Row(
        key: const Key('nexa_places_loading'),
        children: [
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text(l10n.placesLoading),
        ],
      ),
      NexaPlacesStatus.zeroResults => message(l10n.placesEmpty),
      NexaPlacesStatus.locationDenied => message(
        l10n.placesLocationDenied,
        actions: [
          if (onRetry != null)
            TextButton(
              key: const Key('nexa_places_retry'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          if (onOpenSettings != null)
            TextButton(
              key: const Key('nexa_places_settings'),
              onPressed: onOpenSettings,
              child: Text(l10n.openSettings),
            ),
        ],
      ),
      NexaPlacesStatus.error => message(
        l10n.placesError,
        actions: [
          if (r.retryable && onRetry != null)
            TextButton(
              key: const Key('nexa_places_retry'),
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
        ],
      ),
      NexaPlacesStatus.ok =>
        compact
            ? SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: r.places.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => SizedBox(
                    width: 240,
                    child: _PlaceTile(
                      ordinal: i + 1,
                      place: r.places[i],
                      onDirections: onDirections,
                      onSelect: onSelect,
                      selected: r.places[i].placeId == selectedPlaceId,
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  for (final (i, p) in r.places.indexed) ...[
                    if (i > 0) const Divider(height: 16),
                    _PlaceTile(
                      ordinal: i + 1,
                      place: p,
                      onDirections: onDirections,
                      onSelect: onSelect,
                      selected: p.placeId == selectedPlaceId,
                    ),
                  ],
                ],
              ),
    };
    return Container(
      key: Key('nexa_places_${r.resultId}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.query ?? l10n.placesTitle,
                  style: theme.textTheme.labelLarge,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
          if (r.attribution != null && r.status == NexaPlacesStatus.ok) ...[
            const SizedBox(height: 8),
            Text(
              r.attribution!,
              key: const Key('nexa_places_attribution'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.ordinal,
    required this.place,
    this.onDirections,
    this.onSelect,
    this.selected = false,
  });

  final int ordinal;
  final NexaPlace place;
  final ValueChanged<NexaPlace>? onDirections;
  final ValueChanged<NexaPlace>? onSelect;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = NexaColors.of(context);
    final d = place.distanceMeters;
    final distance = d == null
        ? null
        : d < 1000
        ? l10n.placesDistanceM(d.round())
        : l10n.placesDistanceKm((d / 1000).toStringAsFixed(1));
    final meta = [
      ?place.category,
      ?distance,
      if (place.openNow != null)
        place.openNow! ? l10n.placesOpenNow : l10n.placesClosed,
    ].join(' · ');
    return InkWell(
      key: Key('nexa_place_${place.placeId}'),
      borderRadius: BorderRadius.circular(12),
      onTap: onSelect == null ? null : () => onSelect!(place),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 13,
              backgroundColor: scheme.primaryContainer,
              child: Text(
                '$ordinal',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: nexaTextDirectionOf(place.name),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (place.rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: colors.warning,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          place.rating!.toStringAsFixed(1) +
                              (place.ratingCount == null
                                  ? ''
                                  : ' (${place.ratingCount})'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  if (meta.isNotEmpty)
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  if (place.address != null)
                    Text(
                      place.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: nexaTextDirectionOf(place.address!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (onDirections != null)
              IconButton(
                key: Key('nexa_place_directions_$ordinal'),
                tooltip: l10n.placesDirections,
                onPressed: () => onDirections!(place),
                icon: const Icon(Icons.directions_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
