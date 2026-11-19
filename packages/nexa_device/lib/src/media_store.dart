import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:nexa_core/nexa_core.dart';
import 'package:path_provider/path_provider.dart';

/// Images the user captured or attached, kept in the app's private support
/// directory (`nexa_media/`) so "Clear all data" can remove them. Nothing
/// here is uploaded.
final class NexaMediaStore {
  NexaMediaStore({Directory? root}) : _root = root;

  Directory? _root;

  Future<Directory> _dir() async {
    final dir = _root ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/nexa_media',
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copies [sourcePath] into the store and returns its attachment.
  Future<NexaAttachment> importImage(
    String sourcePath, {
    required NexaAttachmentOrigin origin,
    String? toolCallId,
    String? editOf,
  }) async {
    final src = File(sourcePath);
    final bytes = await src.readAsBytes();
    final ext = sourcePath.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final id = 'att_${DateTime.now().microsecondsSinceEpoch}_${_hex()}';
    final file = File('${(await _dir()).path}/$id.$ext');
    await file.writeAsBytes(bytes, flush: true);
    int? width;
    int? height;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      width = frame.image.width;
      height = frame.image.height;
      frame.image.dispose();
      codec.dispose();
    } on Object {
      // Unknown size is fine.
    }
    return NexaAttachment(
      id: id,
      kind: NexaAttachmentKind.image,
      origin: origin,
      mimeType: ext == 'png' ? 'image/png' : 'image/jpeg',
      createdAt: DateTime.now().toUtc(),
      byteLength: bytes.length,
      width: width,
      height: height,
      localPath: file.path,
      toolCallId: toolCallId,
      editOf: editOf,
    );
  }

  /// Largest file accepted (the proposed upload contract allows 10 MB).
  static const maxFileBytes = 10 * 1024 * 1024;

  /// File types accepted as attachments, by extension.
  static const fileTypes = {
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'csv': 'text/csv',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  };

  /// Checks type and size before anything is copied. Returns an error code
  /// (`unsupported_type`, `too_large`) or null when acceptable.
  static String? checkFile(String name, int size) {
    final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (!fileTypes.containsKey(ext)) return 'unsupported_type';
    if (size > maxFileBytes) return 'too_large';
    return null;
  }

  /// Copies an accepted file into the store (call [checkFile] first).
  Future<NexaAttachment> importFile(String sourcePath, String name) async {
    final ext = name.split('.').last.toLowerCase();
    final id = 'att_${DateTime.now().microsecondsSinceEpoch}_${_hex()}';
    final file = File('${(await _dir()).path}/$id.$ext');
    await File(sourcePath).copy(file.path);
    return NexaAttachment(
      id: id,
      kind: NexaAttachmentKind.file,
      origin: NexaAttachmentOrigin.uploaded,
      mimeType: fileTypes[ext] ?? 'application/octet-stream',
      createdAt: DateTime.now().toUtc(),
      byteLength: file.lengthSync(),
      name: name,
      localPath: file.path,
    );
  }

  /// Deletes one stored file (ignores files outside the store).
  Future<void> delete(NexaAttachment a) async {
    final path = a.localPath;
    if (path == null) return;
    final dir = await _dir();
    if (!path.startsWith(dir.path)) return;
    final f = File(path);
    if (f.existsSync()) await f.delete();
  }

  /// Deletes every stored file; returns how many were removed.
  Future<int> deleteAll() async {
    final dir = await _dir();
    var n = 0;
    for (final f in dir.listSync().whereType<File>()) {
      await f.delete();
      n++;
    }
    return n;
  }

  /// Number of stored files.
  Future<int> count() async =>
      (await _dir()).listSync().whereType<File>().length;

  static String _hex() =>
      Random().nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
}
