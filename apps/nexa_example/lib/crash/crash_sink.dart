import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// What an uncaught error looks like to a crash reporter. Deliberately has
/// no message: exception messages can carry user text, ids or tokens, which
/// must never leave the device through this path. The stack holds code
/// locations only.
@immutable
final class CrashReport {
  const CrashReport({
    required this.errorType,
    required this.source,
    required this.at,
    this.errorCode,
    this.stack,
  });

  /// `runtimeType` of the error (e.g. `StateError`, `NetworkException`).
  final String errorType;

  /// Stable code of a [NexaException] (`networkTimeout`, …), else null.
  final String? errorCode;

  /// `flutter` (framework callback) or `platform` (async / engine).
  final String source;
  final DateTime at;
  final StackTrace? stack;

  @override
  String toString() =>
      'CrashReport($errorType${errorCode == null ? '' : '/$errorCode'}, $source)';
}

/// Where crash reports go. No vendor is chosen yet: a host plugs one in
/// (Crashlytics, Sentry, a file…) by implementing this.
abstract interface class CrashSink {
  void report(CrashReport report);
}

/// Reports nothing (the default in release builds until a vendor exists).
final class NoopCrashSink implements CrashSink {
  const NoopCrashSink();
  @override
  void report(CrashReport report) {}
}

/// Prints the report (type and code only) in debug builds.
final class DebugPrintCrashSink implements CrashSink {
  const DebugPrintCrashSink();
  @override
  void report(CrashReport report) => debugPrint('[crash] $report');
}

CrashSink _sink = const NoopCrashSink();
FlutterExceptionHandler? _ourFlutterHandler;
ErrorCallback? _ourPlatformHandler;

/// Forwards uncaught errors (`FlutterError.onError` and
/// `PlatformDispatcher.onError`) to [sink], then to whatever handler was
/// installed before. Safe to call again: the sink is replaced and nothing is
/// reported twice. A failing sink never throws into the error path.
void installCrashHandlers(CrashSink sink) {
  _sink = sink;

  if (FlutterError.onError != _ourFlutterHandler ||
      _ourFlutterHandler == null) {
    final previous = FlutterError.onError;
    void handler(FlutterErrorDetails details) {
      _forward(details.exception, details.stack, 'flutter');
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
    }

    _ourFlutterHandler = handler;
    FlutterError.onError = handler;
  }

  if (PlatformDispatcher.instance.onError != _ourPlatformHandler ||
      _ourPlatformHandler == null) {
    final previous = PlatformDispatcher.instance.onError;
    bool handler(Object error, StackTrace stack) {
      _forward(error, stack, 'platform');
      // Not handled here: the engine still logs the error.
      return previous?.call(error, stack) ?? false;
    }

    _ourPlatformHandler = handler;
    PlatformDispatcher.instance.onError = handler;
  }
}

void _forward(Object error, StackTrace? stack, String source) {
  try {
    _sink.report(
      CrashReport(
        errorType: error.runtimeType.toString(),
        errorCode: error is NexaException ? error.code.name : null,
        source: source,
        at: DateTime.now().toUtc(),
        stack: stack,
      ),
    );
  } on Object {
    // Reporting must never make a crash worse.
  }
}
