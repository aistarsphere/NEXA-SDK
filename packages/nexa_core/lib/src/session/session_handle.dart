import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nexa_core/src/config/nexa_capability.dart';
import 'package:nexa_core/src/ids/ids.dart';

part 'session_handle.freezed.dart';

/// Server-granted description of an active session.
@freezed
abstract class SessionHandle with _$SessionHandle {
  const SessionHandle._();

  const factory SessionHandle({
    required SessionId sessionId,
    required DateTime expiresAt,

    /// Capabilities the gateway actually granted (policy-filtered).
    required Set<NexaCapability> grantedCapabilities,

    /// Sequence to resume from when reconnecting (0 for a new session).
    @Default(0) int lastSequence,
  }) = _SessionHandle;

  /// Whether [capability] was granted.
  bool has(NexaCapability capability) =>
      grantedCapabilities.contains(capability);
}
