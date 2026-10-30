import 'package:meta/meta.dart';
import 'package:nexa_core/src/client_tools/client_tool.dart';
import 'package:nexa_core/src/labeeb/contract_tool_call.dart';
import 'package:nexa_core/src/places/places.dart';

enum NexaAttachmentKind { image, file }

/// Where an attachment came from.
enum NexaAttachmentOrigin {
  /// Chosen from the photo library / files.
  uploaded,

  /// Taken with the camera (incl. the `device.camera.capture` tool).
  captured,

  /// Produced by the assistant (backend image generation).
  generated,

  /// An edited version of another attachment (see [NexaAttachment.editOf]).
  edited,
}

/// Delivery state of an attachment to the backend.
enum NexaAttachmentStatus {
  /// On this device only, not yet offered for upload.
  local,

  /// Upload in progress ([NexaAttachment.progress]).
  uploading,

  /// Accepted by the backend ([NexaAttachment.remoteId] set).
  uploaded,

  /// Upload failed ([NexaAttachment.error]); can be retried.
  failed,

  /// The backend has no attachment API / did not grant `attachments`:
  /// kept on the device, never sent. Not an error.
  uploadUnavailable,

  /// The user cancelled.
  cancelled,
}

/// An image or file in the conversation. [toJson] carries metadata only
/// (never bytes or device paths), for the backend tool/attachment pipeline.
@immutable
final class NexaAttachment {
  const NexaAttachment({
    required this.id,
    required this.kind,
    required this.origin,
    required this.mimeType,
    required this.createdAt,
    this.byteLength,
    this.width,
    this.height,
    this.name,
    this.localPath,
    this.remoteId,
    this.remoteUrl,
    this.status = NexaAttachmentStatus.local,
    this.progress,
    this.error,
    this.editOf,
    this.toolCallId,
  });

  final String id;
  final NexaAttachmentKind kind;
  final NexaAttachmentOrigin origin;
  final String mimeType;
  final DateTime createdAt;
  final int? byteLength;
  final int? width;
  final int? height;

  /// File name shown for files.
  final String? name;

  /// Device file (app sandbox). Null for remote-only assets.
  final String? localPath;

  /// Backend asset id / URL once uploaded or generated.
  final String? remoteId;
  final Uri? remoteUrl;

  final NexaAttachmentStatus status;

  /// 0..1 while [NexaAttachmentStatus.uploading].
  final double? progress;
  final String? error;

  /// The attachment this one edits, or that an edit request refers to.
  final String? editOf;

  /// Client tool call that produced it (camera capture).
  final String? toolCallId;

  bool get isImage => kind == NexaAttachmentKind.image;

  /// A real asset exists to view / share.
  bool get hasAsset => localPath != null || remoteUrl != null;

  NexaAttachment copyWith({
    NexaAttachmentStatus? status,
    double? progress,
    String? error,
    String? remoteId,
    Uri? remoteUrl,
    bool clearError = false,
  }) => NexaAttachment(
    id: id,
    kind: kind,
    origin: origin,
    mimeType: mimeType,
    createdAt: createdAt,
    byteLength: byteLength,
    width: width,
    height: height,
    name: name,
    localPath: localPath,
    remoteId: remoteId ?? this.remoteId,
    remoteUrl: remoteUrl ?? this.remoteUrl,
    status: status ?? this.status,
    progress: progress,
    error: clearError ? null : error ?? this.error,
    editOf: editOf,
    toolCallId: toolCallId,
  );

  Map<String, Object?> toJson() => {
    'attachment_id': id,
    'kind': kind.name,
    'origin': origin.name,
    'mime_type': mimeType,
    if (byteLength != null) 'byte_length': byteLength,
    if (width != null) 'width': width,
    if (height != null) 'height': height,
    if (name != null) 'name': name,
    if (remoteId != null) 'asset_id': remoteId,
    if (editOf != null) 'edit_of': editOf,
    if (toolCallId != null) 'tool_call_id': toolCallId,
    'created_at': createdAt.toUtc().toIso8601String(),
  };
}

/// Where an item was produced.
enum NexaItemSurface { chat, voice }

/// Non-text conversation content shown by **both** the chat and the live
/// voice views (text messages come from the chat state, voice captions
/// from the voice state).
@immutable
sealed class NexaConversationItem {
  const NexaConversationItem({
    required this.id,
    required this.createdAt,
    this.surface = NexaItemSurface.chat,
  });

  final String id;
  final DateTime createdAt;
  final NexaItemSurface surface;
}

/// An image/file in the conversation, sent by the user ([fromUser]) or the
/// assistant (generated/edited images).
final class NexaAttachmentItem extends NexaConversationItem {
  const NexaAttachmentItem({
    required super.id,
    required super.createdAt,
    required this.attachment,
    this.fromUser = true,
    this.caption,
    super.surface,
  });

  final NexaAttachment attachment;
  final bool fromUser;
  final String? caption;

  NexaAttachmentItem withAttachment(NexaAttachment a) => NexaAttachmentItem(
    id: id,
    createdAt: createdAt,
    attachment: a,
    fromUser: fromUser,
    caption: caption,
    surface: surface,
  );
}

/// A client tool run (request → approval → result) in the conversation.
final class NexaToolRunItem extends NexaConversationItem {
  const NexaToolRunItem({
    required super.id,
    required super.createdAt,
    required this.request,
    required this.title,
    this.phase = ClientToolRunPhase.requested,
    this.result,
    this.delivered = false,
    super.surface,
  });

  final ClientToolRequest request;
  final String title;
  final ClientToolRunPhase phase;
  final ClientToolResult? result;

  /// Whether the result reached the backend (false while the backend has
  /// no client-tool result API).
  final bool delivered;

  NexaToolRunItem copyWith({
    ClientToolRunPhase? phase,
    ClientToolResult? result,
    bool? delivered,
  }) => NexaToolRunItem(
    id: id,
    createdAt: createdAt,
    request: request,
    title: title,
    phase: phase ?? this.phase,
    result: result ?? this.result,
    delivered: delivered ?? this.delivered,
    surface: surface,
  );
}

/// A reference to a live voice turn (transcript kept by the voice call).
final class NexaTranscriptRefItem extends NexaConversationItem {
  const NexaTranscriptRefItem({
    required super.id,
    required super.createdAt,
    required this.voiceSessionId,
    this.turnId,
    this.fromUser = true,
    this.text,
  }) : super(surface: NexaItemSurface.voice);

  final String voiceSessionId;
  final String? turnId;
  final bool fromUser;

  /// Final transcript text when the host keeps transcripts.
  final String? text;
}

/// A places result in the conversation. Places keep their 1-based
/// [ordinals] so "the second restaurant" resolves to the right place id.
final class NexaPlacesItem extends NexaConversationItem {
  const NexaPlacesItem({
    required super.id,
    required super.createdAt,
    required this.result,
    super.surface,
  });

  final NexaPlacesResult result;

  /// The place shown as number [ordinal] (1-based), or null.
  NexaPlace? placeAt(int ordinal) =>
      ordinal >= 1 && ordinal <= result.places.length
      ? result.places[ordinal - 1]
      : null;

  /// What the client sends back as conversation context (no coordinates
  /// beyond what the backend already returned).
  List<Map<String, Object?>> get ordinals => [
    for (final (i, p) in result.places.indexed)
      {'ordinal': i + 1, 'place_id': p.placeId, 'name': p.name},
  ];
}

/// A Dynamic UI surface in the conversation (rendered by the SDK's closed
/// component library; state lives in the surface controller by id).
final class NexaSurfaceItem extends NexaConversationItem {
  const NexaSurfaceItem({
    required super.id,
    required super.createdAt,
    required this.surfaceId,
    super.surface,
  });

  final String surfaceId;
}

/// A `labeeb.sdk/1` tool call in the conversation (device action, server
/// tool or long job). Live state lives in the SDK's tool-call controller,
/// keyed by [toolCallId].
final class NexaToolCallItem extends NexaConversationItem {
  const NexaToolCallItem({
    required super.id,
    required super.createdAt,
    required this.toolCallId,
    super.surface,
  });

  final String toolCallId;
}

/// A `nexa.ui/1` document presented by the assistant ([uiId] keys the
/// parsed document in the tool-call controller).
final class NexaUiDocumentItem extends NexaConversationItem {
  const NexaUiDocumentItem({
    required super.id,
    required super.createdAt,
    required this.uiId,
    super.surface,
  });

  final String uiId;
}

/// A server asset produced in the conversation (generated/edited image,
/// created file); bytes are fetched on demand, owner only.
final class NexaAssetItem extends NexaConversationItem {
  const NexaAssetItem({
    required super.id,
    required super.createdAt,
    required this.asset,
    this.toolCallId,
    super.surface,
  });

  final NexaAssetRef asset;
  final String? toolCallId;
}
