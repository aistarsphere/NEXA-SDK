import 'dart:async';

import 'package:nexa_core/src/client_tools/client_tool.dart';
import 'package:nexa_core/src/config/nexa_capability.dart';

/// Implemented per device tool (e.g. in `nexa_device`).
abstract interface class ClientToolExecutor {
  ClientToolDescriptor get descriptor;

  /// Current availability without prompting the user.
  Future<ClientToolAvailability> availability();

  /// Runs the tool after the registry validated and the user approved.
  /// Asks for OS permission itself when needed (report
  /// [ClientToolRunPhase.awaitingPermission] through [onPhase]).
  Future<ClientToolResult> execute(
    ClientToolRequest request, {
    required void Function(ClientToolRunPhase phase) onPhase,
  });
}

/// Asks the user to approve a run. Return false to decline.
typedef ClientToolApproval =
    Future<bool> Function(
      ClientToolDescriptor descriptor,
      ClientToolRequest request,
    );

/// The allow-list of client tools. Only registered `(id, version)` pairs
/// the host enabled can run; anything else (including unknown or
/// model-invented tool names) is rejected with a structured error and
/// nothing executes.
final class ClientToolRegistry {
  ClientToolRegistry({Set<String>? enabledToolIds, this.platform})
    : _enabled = enabledToolIds;

  /// The current platform (null: do not filter, e.g. tests).
  final ClientToolPlatform? platform;

  final Map<String, ClientToolExecutor> _tools = {};
  final Set<String>? _enabled;

  /// Capabilities the backend granted for the current session; assistant
  /// requests need [NexaCapability.toolCalling] plus the tool's own.
  Set<NexaCapability> grantedCapabilities = const {};

  void register(ClientToolExecutor tool, {bool replace = false}) {
    final id = tool.descriptor.id;
    if (_tools.containsKey(id) && !replace) {
      throw StateError('client tool $id registered twice');
    }
    _tools[id] = tool;
  }

  /// Host override of a built-in tool, or an additional host tool.
  void override(ClientToolExecutor tool) => register(tool, replace: true);

  final Map<String, Completer<ClientToolResult>> _running = {};

  /// Cancels a running call (backend cancellation or the user).
  bool cancel(String callId) {
    final c = _running.remove(callId);
    if (c == null || c.isCompleted) return false;
    c.complete(
      ClientToolResult.failure(
        ClientToolRequest(callId: callId, toolId: '', version: 0),
        const ClientToolError(ClientToolErrorCode.cancelled, 'cancelled'),
      ),
    );
    return true;
  }

  /// What the backend may call: enabled tools on this platform with their
  /// current availability. Unsupported / host-disabled tools are omitted.
  Future<List<Map<String, Object?>>> advertise() async {
    final out = <Map<String, Object?>>[];
    for (final t in _tools.values) {
      final d = t.descriptor;
      if (!isEnabled(d.id)) continue;
      if (platform != null && !d.platforms.contains(platform)) continue;
      final a = await t.availability();
      if (a == ClientToolAvailability.unsupported ||
          a == ClientToolAvailability.disabledByHost) {
        continue;
      }
      out.add({...d.toJson(), 'availability': a.name});
    }
    return out;
  }

  /// Registered tools the host enabled.
  List<ClientToolDescriptor> get descriptors => [
    for (final t in _tools.values)
      if (isEnabled(t.descriptor.id)) t.descriptor,
  ];

  bool isEnabled(String id) =>
      _tools.containsKey(id) && (_enabled?.contains(id) ?? true);

  ClientToolExecutor? executorFor(String id) =>
      isEnabled(id) ? _tools[id] : null;

  /// Availability of [id] for a run from [origin].
  Future<ClientToolAvailability> availability(
    String id, {
    ClientToolOrigin origin = ClientToolOrigin.user,
  }) async {
    final tool = _tools[id];
    if (tool == null) return ClientToolAvailability.unsupported;
    if (!isEnabled(id)) return ClientToolAvailability.disabledByHost;
    if (origin == ClientToolOrigin.assistant && !_granted(tool.descriptor)) {
      return ClientToolAvailability.notGranted;
    }
    return tool.availability();
  }

  bool _granted(ClientToolDescriptor d) =>
      grantedCapabilities.contains(NexaCapability.toolCalling) &&
      grantedCapabilities.containsAll(d.requiredCapabilities);

  /// Validates, asks for approval and runs [request]. Never throws: every
  /// outcome is a [ClientToolResult].
  Future<ClientToolResult> run(
    ClientToolRequest request, {
    required ClientToolApproval approve,
    void Function(ClientToolRunPhase phase)? onPhase,
    DateTime Function() now = DateTime.now,
  }) async {
    void phase(ClientToolRunPhase p) => onPhase?.call(p);
    ClientToolResult fail(ClientToolErrorCode code, String message) {
      final r = ClientToolResult.failure(
        request,
        ClientToolError(code, message),
      );
      phase(
        r.status == ClientToolResultStatus.cancelled
            ? ClientToolRunPhase.cancelled
            : ClientToolRunPhase.failed,
      );
      return r;
    }

    phase(ClientToolRunPhase.requested);
    final tool = _tools[request.toolId];
    if (tool == null) {
      return fail(
        ClientToolErrorCode.unknownTool,
        'no client tool "${request.toolId}"',
      );
    }
    final d = tool.descriptor;
    if (platform != null && !d.platforms.contains(platform)) {
      return fail(
        ClientToolErrorCode.unsupported,
        '${d.id} is not available on ${platform!.name}',
      );
    }
    if (request.version != d.version) {
      return fail(
        ClientToolErrorCode.unsupportedVersion,
        '${d.id} supports version ${d.version}, got ${request.version}',
      );
    }
    if (!isEnabled(d.id)) {
      return fail(ClientToolErrorCode.disabledByHost, '${d.id} is disabled');
    }
    if (request.origin == ClientToolOrigin.assistant && !_granted(d)) {
      return fail(
        ClientToolErrorCode.notGranted,
        'toolCalling / required capabilities not granted',
      );
    }
    final expires = request.expiresAt;
    if (expires != null && now().isAfter(expires)) {
      return fail(ClientToolErrorCode.expired, 'request expired');
    }
    final invalid = validateArguments(d.inputSchema, request.arguments);
    if (invalid != null) {
      return fail(ClientToolErrorCode.invalidArguments, invalid);
    }
    if (d.requiresApproval) {
      phase(ClientToolRunPhase.awaitingApproval);
      final ok = await approve(d, request);
      if (!ok) return fail(ClientToolErrorCode.userDeclined, 'declined');
    }
    phase(ClientToolRunPhase.running);
    final done = Completer<ClientToolResult>();
    _running[request.callId] = done;
    unawaited(
      tool
          .execute(request, onPhase: phase)
          .timeout(d.timeout)
          .then(
            (r) {
              if (!done.isCompleted) done.complete(r);
            },
            onError: (Object e) {
              if (done.isCompleted) return;
              done.complete(
                ClientToolResult.failure(
                  request,
                  ClientToolError(
                    e is TimeoutException
                        ? ClientToolErrorCode.timeout
                        : ClientToolErrorCode.deviceError,
                    e.runtimeType.toString(),
                    retryable: true,
                  ),
                ),
              );
            },
          ),
    );
    try {
      var result = await done.future;
      _running.remove(request.callId);
      if (result.toolId.isEmpty) {
        // Cancelled through [cancel]: address it to this request.
        result = ClientToolResult.failure(request, result.error!);
      }
      phase(switch (result.status) {
        ClientToolResultStatus.succeeded => ClientToolRunPhase.succeeded,
        ClientToolResultStatus.failed => ClientToolRunPhase.failed,
        ClientToolResultStatus.cancelled => ClientToolRunPhase.cancelled,
      });
      return result;
    } on Object catch (e) {
      return fail(ClientToolErrorCode.deviceError, e.runtimeType.toString());
    }
  }
}

/// Validates [args] against the supported JSON-Schema subset (`type:
/// object`, `properties` with `type` / `enum` / `minimum` / `maximum`,
/// `required`, `additionalProperties: false`). Returns an error or null.
String? validateArguments(
  Map<String, Object?> schema,
  Map<String, Object?> args,
) {
  final props =
      (schema['properties'] as Map?)?.cast<String, Object?>() ?? const {};
  for (final r in (schema['required'] as List?) ?? const []) {
    if (!args.containsKey(r)) return 'missing argument "$r"';
  }
  final closed = schema['additionalProperties'] == false;
  for (final entry in args.entries) {
    final spec = (props[entry.key] as Map?)?.cast<String, Object?>();
    if (spec == null) {
      if (closed) return 'unexpected argument "${entry.key}"';
      continue;
    }
    final v = entry.value;
    final ok = switch (spec['type']) {
      'string' => v is String,
      'boolean' => v is bool,
      'integer' => v is int,
      'number' => v is num,
      'object' => v is Map,
      'array' => v is List,
      _ => true,
    };
    if (!ok) return 'argument "${entry.key}" must be ${spec['type']}';
    final allowed = spec['enum'];
    if (allowed is List && !allowed.contains(v)) {
      return 'argument "${entry.key}" must be one of $allowed';
    }
    if (v is num) {
      final min = spec['minimum'];
      final max = spec['maximum'];
      if (min is num && v < min) return '"${entry.key}" below $min';
      if (max is num && v > max) return '"${entry.key}" above $max';
    }
  }
  return null;
}
