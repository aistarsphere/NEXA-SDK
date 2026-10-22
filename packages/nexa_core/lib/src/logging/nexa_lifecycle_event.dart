import 'package:nexa_core/src/errors/nexa_exception.dart';
import 'package:nexa_core/src/ids/ids.dart';

/// Lifecycle and error events published to the host application through
/// `NexaClient.lifecycle`.
sealed class NexaLifecycleEvent {
  const NexaLifecycleEvent(this.at);

  /// When the event happened.
  final DateTime at;
}

/// SDK initialised and ready.
final class NexaInitialized extends NexaLifecycleEvent {
  const NexaInitialized(super.at);
}

/// A session started.
final class NexaSessionStarted extends NexaLifecycleEvent {
  const NexaSessionStarted(super.at, this.sessionId);
  final SessionId sessionId;
}

/// A session ended.
final class NexaSessionEnded extends NexaLifecycleEvent {
  const NexaSessionEnded(super.at, this.sessionId, {this.reason});
  final SessionId sessionId;
  final String? reason;
}

/// A credential was (re)issued by the host auth provider.
final class NexaCredentialRefreshed extends NexaLifecycleEvent {
  const NexaCredentialRefreshed(super.at, this.expiresAt);
  final DateTime expiresAt;
}

/// An error the host may want to log or surface.
final class NexaErrorOccurred extends NexaLifecycleEvent {
  const NexaErrorOccurred(super.at, this.error);
  final NexaException error;
}

/// The SDK was disposed.
final class NexaDisposed extends NexaLifecycleEvent {
  const NexaDisposed(super.at);
}
