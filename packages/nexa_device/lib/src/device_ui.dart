import 'dart:io';

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';
import 'package:share_plus/share_plus.dart';

/// Picks one image from the photo library (the system picker handles its
/// own permission). Returns the picked file path or null when cancelled.
abstract interface class NexaImagePicker {
  Future<String?> pickFromLibrary();
}

final class PluginImagePicker implements NexaImagePicker {
  const PluginImagePicker();

  @override
  Future<String?> pickFromLibrary() async => (await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2560,
    maxHeight: 2560,
    imageQuality: 90,
  ))?.path;
}

/// A file the user picked (not yet imported).
typedef PickedFile = ({String path, String name, int size});

/// Picks one document/file with the system picker. Null when cancelled.
abstract interface class NexaFilePicker {
  Future<PickedFile?> pickFile();
}

final class PluginFilePicker implements NexaFilePicker {
  const PluginFilePicker();

  @override
  Future<PickedFile?> pickFile() async {
    final f = await fp.FilePicker.pickFile();
    final path = f?.path;
    if (f == null || path == null) return null;
    return (path: path, name: f.name, size: File(path).lengthSync());
  }
}

/// Asks the user to approve a client tool run (explains what happens).
Future<bool> showClientToolApproval(
  BuildContext context,
  ClientToolDescriptor descriptor,
) async {
  final l10n = NexaLocalizations.of(context);
  final (title, body, icon) = switch (descriptor.id) {
    'device.location.get_current' => (
      l10n.locationApproveTitle,
      l10n.locationApproveBody,
      Icons.my_location_rounded,
    ),
    _ => (l10n.cameraApproveTitle, l10n.cameraApproveBody, Icons.photo_camera),
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => nexaScoped(
      context,
      AlertDialog(
        key: const Key('nexa_tool_approval'),
        icon: Icon(icon),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: const Key('nexa_tool_decline'),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.toolNotNow),
          ),
          FilledButton(
            key: const Key('nexa_tool_allow'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.toolAllow),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}

/// Full-screen image viewer: pinch-zoom, share (only when the asset exists
/// on the device) and "Ask about this image".
class NexaImageViewer extends StatelessWidget {
  const NexaImageViewer({required this.attachment, this.onAskAbout, super.key});

  final NexaAttachment attachment;
  final VoidCallback? onAskAbout;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final path = attachment.localPath;
    final exists = path != null && File(path).existsSync();
    return Scaffold(
      key: const Key('nexa_image_viewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (exists)
            IconButton(
              key: const Key('nexa_image_share'),
              tooltip: l10n.imageShare,
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  files: [XFile(path, mimeType: attachment.mimeType)],
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: exists
            ? InteractiveViewer(maxScale: 5, child: Image.file(File(path)))
            : attachment.remoteUrl != null
            ? InteractiveViewer(
                maxScale: 5,
                child: Image.network(attachment.remoteUrl.toString()),
              )
            : const Icon(Icons.broken_image_outlined, color: Colors.white54),
      ),
      bottomNavigationBar: onAskAbout == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.tonalIcon(
                  key: const Key('nexa_image_ask'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAskAbout!();
                  },
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: Text(l10n.imageAskAbout),
                ),
              ),
            ),
    );
  }
}
