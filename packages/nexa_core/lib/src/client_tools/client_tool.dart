import 'package:meta/meta.dart';
import 'package:nexa_core/src/config/nexa_capability.dart';

/// Contract version of client-tool requests/results exchanged with the
/// backend (proposed: `docs/contracts/nexa-client-tools.proposed.md`).
const String clientToolContractV1 = 'nexa.client_tool.v1';

/// OS-level permission a client tool may need.
enum ClientToolPermission { location, camera, photoLibrary, files }

/// Platforms a tool runs on.
enum ClientToolPlatform { android, ios }

/// How sensitive a tool is; drives whether the user must approve each run.
enum ClientToolSensitivity {
  /// Reads nothing personal and changes nothing (e.g. connectivity type).
  low,

  /// Reads personal/device data (location, Wi-Fi name, files, camera).
  personal,

  /// Visible outside the app (opens another app, browser, share sheet).
  external,
}

/// Whether a tool can run right now on this device.
enum ClientToolAvailability {
  /// Ready; may still ask the user to approve the action.
  available,

  /// The OS permission has not been asked yet (asking is possible).
  needsPermission,

  /// The user denied the permission; asking again is possible.
  permissionDenied,

  /// Denied permanently or restricted: only system settings can change it.
  permissionBlocked,

  /// The device service is off (e.g. location services).
  serviceDisabled,

  /// No such hardware / unsupported platform.
  unsupported,

  /// The host app did not enable the tool.
  disabledByHost,

  /// A capability the tool needs was not granted for the session.
  notGranted,
}

/// Who asked for the tool run.
enum ClientToolOrigin {
  /// A backend `client_tool_call` event (model-initiated).
  assistant,

  /// The user launched it from the UI (e.g. "Take a photo").
  user,
}

/// Static description of a client tool. Flutter executes client tools;
/// server tools stay on the backend and never pass through the registry.
@immutable
final class ClientToolDescriptor {
  const ClientToolDescriptor({
    required this.id,
    required this.version,
    required this.title,
    required this.inputSchema,
    required this.outputSchema,
    this.requiredCapabilities = const {},
    this.requiredPermissions = const {},
    this.requiresApproval = true,
    this.platforms = const {ClientToolPlatform.android, ClientToolPlatform.ios},
    this.timeout = const Duration(seconds: 60),
    this.sensitivity = ClientToolSensitivity.personal,
  });

  /// Stable dotted id, e.g. `device.location.get_current`.
  final String id;

  /// Major version of the tool's input/output schema.
  final int version;

  /// Short human title (English; UI localises separately).
  final String title;

  /// JSON-Schema-like description of the arguments (`type: object`).
  final Map<String, Object?> inputSchema;

  /// JSON-Schema-like description of a successful output.
  final Map<String, Object?> outputSchema;

  final Set<NexaCapability> requiredCapabilities;
  final Set<ClientToolPermission> requiredPermissions;

  /// The user must confirm each run (always true for device data).
  final bool requiresApproval;

  /// Where the tool is implemented.
  final Set<ClientToolPlatform> platforms;

  /// Hard limit for one run (user interaction included); the run ends with
  /// `timeout` when exceeded.
  final Duration timeout;
  final ClientToolSensitivity sensitivity;

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'title': title,
    'input_schema': inputSchema,
    'output_schema': outputSchema,
    'required_capabilities': [for (final c in requiredCapabilities) c.name],
    'required_permissions': [for (final p in requiredPermissions) p.name],
    'requires_approval': requiresApproval,
    'platforms': [for (final p in platforms) p.name],
    'timeout_ms': timeout.inMilliseconds,
    'sensitivity': sensitivity.name,
  };
}

/// A request to run a client tool (`client_tool_call` event payload).
@immutable
final class ClientToolRequest {
  const ClientToolRequest({
    required this.callId,
    required this.toolId,
    required this.version,
    this.arguments = const {},
    this.origin = ClientToolOrigin.assistant,
    this.sessionId,
    this.voiceSessionId,
    this.expiresAt,
  });

  /// Parses a backend request. Throws [FormatException] when malformed.
  factory ClientToolRequest.fromJson(Map<String, Object?> json) {
    if (json['contract'] != clientToolContractV1) {
      throw FormatException('unsupported contract: ${json['contract']}');
    }
    final callId = json['call_id'];
    final toolId = json['tool_id'];
    final version = json['tool_version'];
    final args = json['arguments'] ?? const <String, Object?>{};
    if (callId is! String || callId.isEmpty) {
      throw const FormatException('call_id missing');
    }
    if (toolId is! String || toolId.isEmpty) {
      throw const FormatException('tool_id missing');
    }
    if (version is! int) throw const FormatException('tool_version missing');
    if (args is! Map) throw const FormatException('arguments not an object');
    final expires = json['expires_at'];
    return ClientToolRequest(
      callId: callId,
      toolId: toolId,
      version: version,
      arguments: Map.unmodifiable(args.cast<String, Object?>()),
      sessionId: json['session_id'] as String?,
      voiceSessionId: json['voice_session_id'] as String?,
      expiresAt: expires is String ? DateTime.tryParse(expires) : null,
    );
  }

  final String callId;
  final String toolId;
  final int version;
  final Map<String, Object?> arguments;
  final ClientToolOrigin origin;
  final String? sessionId;
  final String? voiceSessionId;
  final DateTime? expiresAt;

  Map<String, Object?> toJson() => {
    'contract': clientToolContractV1,
    'call_id': callId,
    'tool_id': toolId,
    'tool_version': version,
    'arguments': arguments,
    'origin': origin.name,
    if (sessionId != null) 'session_id': sessionId,
    if (voiceSessionId != null) 'voice_session_id': voiceSessionId,
    if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
  };
}

/// Structured error codes of a client tool run.
enum ClientToolErrorCode {
  unknownTool,
  unsupportedVersion,
  invalidArguments,
  disabledByHost,
  notGranted,
  userDeclined,
  permissionDenied,
  permissionBlocked,
  serviceDisabled,
  unsupported,
  timeout,
  cancelled,
  expired,
  deviceError,
  fileTooLarge,
  fileTypeUnsupported,
}

@immutable
final class ClientToolError {
  const ClientToolError(
    this.code,
    this.message, {
    this.retryable = false,
    this.canOpenSettings = false,
  });

  factory ClientToolError.fromJson(Map<String, Object?> json) =>
      ClientToolError(
        ClientToolErrorCode.values.firstWhere(
          (c) => c.name == _camel('${json['code']}'),
          orElse: () => ClientToolErrorCode.deviceError,
        ),
        '${json['message'] ?? ''}',
        retryable: json['retryable'] == true,
        canOpenSettings: json['can_open_settings'] == true,
      );

  final ClientToolErrorCode code;

  /// Developer-facing message (never shown verbatim to end users).
  final String message;
  final bool retryable;
  final bool canOpenSettings;

  Map<String, Object?> toJson() => {
    'code': _snake(code.name),
    'message': message,
    'retryable': retryable,
    'can_open_settings': canOpenSettings,
  };

  @override
  String toString() => 'ClientToolError(${code.name}: $message)';
}

enum ClientToolResultStatus { succeeded, failed, cancelled }

/// The outcome of a run (`client_tool_result` payload sent back).
@immutable
final class ClientToolResult {
  const ClientToolResult._({
    required this.callId,
    required this.toolId,
    required this.version,
    required this.status,
    required this.completedAt,
    this.output,
    this.error,
  });

  factory ClientToolResult.success(
    ClientToolRequest request,
    Map<String, Object?> output, {
    DateTime? at,
  }) => ClientToolResult._(
    callId: request.callId,
    toolId: request.toolId,
    version: request.version,
    status: ClientToolResultStatus.succeeded,
    output: Map.unmodifiable(output),
    completedAt: at ?? DateTime.now().toUtc(),
  );

  factory ClientToolResult.failure(
    ClientToolRequest request,
    ClientToolError error, {
    DateTime? at,
  }) => ClientToolResult._(
    callId: request.callId,
    toolId: request.toolId,
    version: request.version,
    status:
        error.code == ClientToolErrorCode.cancelled ||
            error.code == ClientToolErrorCode.userDeclined
        ? ClientToolResultStatus.cancelled
        : ClientToolResultStatus.failed,
    error: error,
    completedAt: at ?? DateTime.now().toUtc(),
  );

  factory ClientToolResult.fromJson(Map<String, Object?> json) {
    final status = ClientToolResultStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => throw FormatException('bad status ${json['status']}'),
    );
    final err = json['error'];
    final out = json['output'];
    return ClientToolResult._(
      callId: json['call_id']! as String,
      toolId: json['tool_id']! as String,
      version: json['tool_version']! as int,
      status: status,
      output: out is Map ? Map.unmodifiable(out.cast<String, Object?>()) : null,
      error: err is Map
          ? ClientToolError.fromJson(err.cast<String, Object?>())
          : null,
      completedAt:
          DateTime.tryParse('${json['completed_at']}') ?? DateTime.now(),
    );
  }

  final String callId;
  final String toolId;
  final int version;
  final ClientToolResultStatus status;
  final Map<String, Object?>? output;
  final ClientToolError? error;
  final DateTime completedAt;

  bool get isSuccess => status == ClientToolResultStatus.succeeded;

  Map<String, Object?> toJson() => {
    'contract': clientToolContractV1,
    'call_id': callId,
    'tool_id': toolId,
    'tool_version': version,
    'status': status.name,
    if (output != null) 'output': output,
    if (error != null) 'error': error!.toJson(),
    'completed_at': completedAt.toUtc().toIso8601String(),
  };
}

/// Lifecycle of one run, for UI.
enum ClientToolRunPhase {
  requested,
  awaitingApproval,
  awaitingPermission,
  running,
  succeeded,
  failed,
  cancelled,
}

String _snake(String camel) =>
    camel.replaceAllMapped(RegExp('[A-Z]'), (m) => '_${m[0]!.toLowerCase()}');

String _camel(String snake) =>
    snake.replaceAllMapped(RegExp('_([a-z])'), (m) => m[1]!.toUpperCase());
