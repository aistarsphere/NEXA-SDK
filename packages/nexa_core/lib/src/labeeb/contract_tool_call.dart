import 'package:meta/meta.dart';

/// Contract `labeeb.sdk/1` (`GET /v1/sdk/contract`), the AWS-published
/// source of truth for the SDK. Snapshot: docs/contracts/labeeb-sdk-1/.
const labeebContractId = 'labeeb.sdk/1';

/// Tool names of contract `labeeb.sdk/1` `tools` (an open set: unknown
/// names are shown generically and never executed on the device).
abstract final class LabeebTools {
  // Client (device) tools.
  static const location = 'device.location.get_current';
  static const camera = 'device.camera.capture';
  static const directions = 'maps.open_directions';
  static const openUrl = 'browser.open_url';
  static const network = 'device.network.get_status';
  static const photoPick = 'device.photo.pick';
  static const filePick = 'device.file.pick';
  static const share = 'device.share.content';
  static const openSettings = 'device.app.open_settings';
  static const themeApply = 'app.theme.apply';
  static const themeReset = 'app.theme.reset';
  static const recordSample = 'device.microphone.record_sample';

  // Server tools.
  static const voiceProfileList = 'voice.profile.list';
  static const voiceProfileCreate = 'voice.profile.create';
  static const voiceProfilePreview = 'voice.profile.preview';
  static const voiceProfileActivate = 'voice.profile.activate';
  static const voiceProfileDelete = 'voice.profile.delete';
  static const placesNearby = 'places.search_nearby';
  static const placesText = 'places.search_text';
  static const vision = 'vision.analyze';
  static const imageGenerate = 'image.generate';
  static const imageEdit = 'image.edit';
  static const ocr = 'ocr.extract';
  static const fileRead = 'file.read';
  static const fileCreate = 'file.create';
  static const webSearch = 'web.search';
  static const news = 'news.search';
  static const sports = 'sports.matches';
  static const video = 'video.search';
  static const themePalettes = 'app.theme.list_palettes';
  static const jobsStatus = 'jobs.status';
  static const jobsCancel = 'jobs.cancel';

  /// Device tools the contract defines (what `client_tools` may declare).
  static const client = {
    location,
    camera,
    directions,
    openUrl,
    network,
    photoPick,
    filePick,
    share,
    openSettings,
    themeApply,
    themeReset,
  };
}

/// `tool_call.statuses` (a closed set; [unknown] guards future values).
enum NexaToolCallStatus {
  awaitingApproval('awaiting_approval'),
  awaitingClient('awaiting_client'),
  running('running'),
  succeeded('succeeded'),
  failed('failed'),
  cancelled('cancelled'),
  expired('expired'),
  denied('denied'),
  unknown('unknown');

  const NexaToolCallStatus(this.wire);
  final String wire;

  static NexaToolCallStatus fromWire(Object? v) =>
      values.where((s) => s.wire == v).firstOrNull ?? unknown;

  bool get terminal =>
      this == succeeded ||
      this == failed ||
      this == cancelled ||
      this == expired ||
      this == denied;
}

/// `{code, message?, retryable}` of a tool call or a device answer.
@immutable
final class NexaToolCallError {
  const NexaToolCallError(this.code, {this.message, this.retryable = false});

  /// An open set (`tool_call.error_codes`): switch on it, never on [message].
  final String code;
  final String? message;
  final bool retryable;

  static NexaToolCallError? fromJson(Object? v) {
    if (v is! Map || v['code'] is! String) return null;
    return NexaToolCallError(
      v['code']! as String,
      message: v['message'] as String?,
      retryable: v['retryable'] == true,
    );
  }

  Map<String, Object?> toJson() => {
    'code': code,
    'message': ?message,
    'retryable': retryable,
  };
}

/// One tool call as the gateway reports it in `tool_call_*` events and
/// `GET .../tool-calls/{id}`. Unknown fields are ignored.
@immutable
final class NexaToolCall {
  const NexaToolCall({
    required this.id,
    required this.tool,
    required this.status,
    this.side = NexaToolSide.server,
    this.arguments = const {},
    this.approvalRequired = false,
    this.deadlineAt,
    this.result,
    this.error,
    this.asynchronous = false,
  });

  /// `tc_*`, also the stable job id of a long-running call.
  final String id;
  final String tool;
  final NexaToolSide side;
  final Map<String, Object?> arguments;
  final NexaToolCallStatus status;
  final bool approvalRequired;
  final DateTime? deadlineAt;
  final Map<String, Object?>? result;
  final NexaToolCallError? error;
  final bool asynchronous;

  bool get isClient => side == NexaToolSide.client;

  /// Null when the payload has no usable `tool_call_id` / `tool`.
  static NexaToolCall? fromJson(Map<String, Object?> j) {
    final id = j['tool_call_id'] ?? j['id'];
    final tool = j['tool'] ?? j['name'];
    if (id is! String || tool is! String) return null;
    return NexaToolCall(
      id: id,
      tool: tool,
      side: j['side'] == 'client' ? NexaToolSide.client : NexaToolSide.server,
      arguments: (j['arguments'] is Map)
          ? (j['arguments']! as Map).cast<String, Object?>()
          : const {},
      status: NexaToolCallStatus.fromWire(j['status']),
      approvalRequired: j['approval_required'] == true,
      deadlineAt: j['deadline_at'] is String
          ? DateTime.tryParse(j['deadline_at']! as String)
          : null,
      result: j['result'] is Map
          ? (j['result']! as Map).cast<String, Object?>()
          : null,
      error: NexaToolCallError.fromJson(j['error']),
      asynchronous: j['asynchronous'] == true,
    );
  }
}

enum NexaToolSide { client, server }

/// `tool_call_progress` of a long job (`state` is an open set).
@immutable
final class NexaToolCallProgress {
  const NexaToolCallProgress({
    required this.toolCallId,
    required this.tool,
    required this.state,
    this.waitedSeconds,
  });

  final String toolCallId;
  final String tool;
  final String state;
  final int? waitedSeconds;
}

/// `asset_created`: `{id, kind, mime, size_bytes, origin}`.
@immutable
final class NexaAssetRef {
  const NexaAssetRef({
    required this.id,
    this.kind = 'file',
    this.mime,
    this.sizeBytes,
    this.origin,
    this.filename,
    this.deleted = false,
  });

  /// A `deleted_asset` message part: the file was deleted; only a
  /// placeholder remains in the conversation.
  const NexaAssetRef.deleted(this.id)
    : kind = 'file',
      mime = null,
      sizeBytes = null,
      origin = null,
      filename = null,
      deleted = true;

  final String id;

  /// `image|file`.
  final String kind;
  final String? mime;
  final int? sizeBytes;

  /// `user|generated|device`.
  final String? origin;
  final String? filename;
  final bool deleted;

  bool get isImage =>
      !deleted && (kind == 'image' || (mime?.startsWith('image/') ?? false));
  bool get isAudio =>
      !deleted && (kind == 'audio' || (mime?.startsWith('audio/') ?? false));
  bool get generated => origin == 'generated';

  static NexaAssetRef? fromJson(Object? v) {
    if (v is! Map || v['id'] is! String) return null;
    return NexaAssetRef(
      id: v['id']! as String,
      kind: v['kind'] as String? ?? 'file',
      mime: v['mime'] as String?,
      sizeBytes: v['size_bytes'] is int ? v['size_bytes']! as int : null,
      origin: v['origin'] as String?,
      filename: v['filename'] as String?,
    );
  }

  /// An `image` / `file` message part (`{type, asset_id, mime,
  /// filename?, generated?, size_bytes?}`) of a history message.
  static NexaAssetRef? fromPart(Map<String, Object?> p) {
    final id = p['asset_id'];
    final type = p['type'];
    if (id is! String || (type != 'image' && type != 'file')) return null;
    return NexaAssetRef(
      id: id,
      kind: type! as String,
      mime: p['mime'] as String?,
      sizeBytes: p['size_bytes'] is int ? p['size_bytes']! as int : null,
      origin: p['generated'] == true ? 'generated' : 'user',
      filename: p['filename'] as String?,
    );
  }
}

/// What the device answers for a client tool:
/// `POST .../tool-calls/{id}/result` with `{result}` or `{error}`.
@immutable
final class NexaToolCallAnswer {
  const NexaToolCallAnswer.success(Map<String, Object?> this.result)
    : error = null;
  const NexaToolCallAnswer.failure(NexaToolCallError this.error)
    : result = null;

  final Map<String, Object?>? result;
  final NexaToolCallError? error;

  bool get ok => error == null;

  Map<String, Object?> toJson() => ok
      ? {'result': result}
      : {
          'error': {
            'code': error!.code,
            if (error!.message != null) 'message': error!.message,
            'retryable': error!.retryable,
          },
        };
}

/// Device-side error codes this client sends (the gateway set is open).
abstract final class NexaDeviceErrorCodes {
  static const permissionDenied = 'permission_denied';
  static const unavailable = 'unavailable';
  static const cancelled = 'cancelled';
  static const deviceError = 'device_error';
  static const unsupported = 'client_does_not_support';
  static const invalidArguments = 'invalid_arguments';
}
