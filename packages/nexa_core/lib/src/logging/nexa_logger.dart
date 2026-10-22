/// Severity.
enum NexaLogLevel { debug, info, warning, error }

/// Minimal logging sink. Host apps may plug their own logger. The SDK never
/// logs credentials or message bodies at `info` or above.
abstract interface class NexaLogger {
  void log(
    NexaLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  });
}

/// Discards everything.
final class NoopNexaLogger implements NexaLogger {
  const NoopNexaLogger();

  @override
  void log(
    NexaLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

/// Collects log lines in memory. For tests.
final class MemoryNexaLogger implements NexaLogger {
  final List<String> lines = [];

  @override
  void log(
    NexaLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    lines.add('[${level.name}] $message${error == null ? '' : ' ($error)'}');
  }
}
