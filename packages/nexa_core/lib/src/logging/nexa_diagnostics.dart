import 'package:nexa_core/src/errors/nexa_exception.dart';

/// Structured development diagnostics: timestamped SDK lifecycle, request
/// and media records for real-device QA (`NexaOverrides.diagnostics`).
///
/// Event names are `<area>.<name>` with `area` one of `session`, `chat`,
/// `voice` or `http`. [record] data holds only JSON scalars (`String`, `num`,
/// `bool`, `null`). The SDK never passes credentials, join tokens or
/// authorization headers, and passes message text or transcripts **only**
/// when [captureContent] is true. Timestamps are the sink's job; durations
/// the SDK measures itself (`*_ms`) use a monotonic stopwatch.
abstract interface class NexaDiagnostics {
  /// False for [NoopNexaDiagnostics]: lets the SDK skip costly sampling
  /// (e.g. WebRTC stats) when nobody records.
  bool get enabled;

  /// Whether message bodies and transcripts may be included (`text`).
  bool get captureContent;

  void record(String event, [Map<String, Object?> data = const {}]);
}

/// Records nothing (the default, and the only sink for production builds).
final class NoopNexaDiagnostics implements NexaDiagnostics {
  const NoopNexaDiagnostics();

  @override
  bool get enabled => false;

  @override
  bool get captureContent => false;

  @override
  void record(String event, [Map<String, Object?> data = const {}]) {}
}

/// Collects records in memory. For tests.
final class MemoryNexaDiagnostics implements NexaDiagnostics {
  MemoryNexaDiagnostics({this.captureContent = false});

  final List<(String, Map<String, Object?>)> records = [];

  @override
  bool get enabled => true;

  @override
  final bool captureContent;

  @override
  void record(String event, [Map<String, Object?> data = const {}]) =>
      records.add((event, data));

  /// Names of the recorded events, in order.
  List<String> get names => [for (final r in records) r.$1];
}

/// Diagnostic fields for an SDK error: code, type, server code and HTTP
/// status. Deliberately not the message, which may quote a cause verbatim.
Map<String, Object?> nexaErrorFields(NexaException e) => {
  'error': e.code.name,
  'error_type': e.runtimeType.toString(),
  'retryable': e.retryable,
  if (e is ServerException) ...{
    'status': e.statusCode,
    'server_code': e.serverCode,
  },
};
