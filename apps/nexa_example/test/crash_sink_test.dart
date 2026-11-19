// Plan G-04: uncaught errors reach a CrashSink, without message text, and
// the handlers that were installed before keep working.
import 'dart:ui' show ErrorCallback, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexa_example/crash/crash_sink.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

final class _Memory implements CrashSink {
  final List<CrashReport> reports = [];
  @override
  void report(CrashReport r) => reports.add(r);
}

void main() {
  late _Memory sink;
  late FlutterExceptionHandler? savedFlutter;
  late ErrorCallback? savedPlatform;

  setUp(() {
    sink = _Memory();
    savedFlutter = FlutterError.onError;
    savedPlatform = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    FlutterError.onError = savedFlutter;
    PlatformDispatcher.instance.onError = savedPlatform;
  });

  test('a framework error is reported by type and stack, never by message', () {
    var previousCalled = 0;
    FlutterError.onError = (_) => previousCalled++;
    installCrashHandlers(sink);

    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('Bearer sk-secret-token and message text'),
        stack: StackTrace.current,
      ),
    );

    expect(sink.reports, hasLength(1));
    final r = sink.reports.single;
    expect(r.errorType, 'StateError');
    expect(r.source, 'flutter');
    expect(r.stack, isNotNull);
    expect(r.toString(), isNot(contains('sk-secret-token')));
    expect(r.toString(), isNot(contains('message text')));
    expect(previousCalled, 1, reason: 'the earlier handler still runs');
  });

  test('an async error is reported and left unhandled for the platform', () {
    installCrashHandlers(sink);
    final handled = PlatformDispatcher.instance.onError!(
      ArgumentError('private text'),
      StackTrace.current,
    );
    expect(sink.reports.single.errorType, 'ArgumentError');
    expect(sink.reports.single.source, 'platform');
    expect(handled, isFalse, reason: 'the engine still logs it');
    expect(sink.reports.single.toString(), isNot(contains('private text')));
  });

  test('a NexaException is reported by its code, not its message', () {
    installCrashHandlers(sink);
    PlatformDispatcher.instance.onError!(
      const NetworkException(NexaErrorCode.networkTimeout, 'user said hello'),
      StackTrace.current,
    );
    final r = sink.reports.single;
    expect(r.errorType, 'NetworkException');
    expect(r.errorCode, 'networkTimeout');
    expect(r.toString(), isNot(contains('hello')));
  });

  test('a failing sink never throws into the error path', () {
    installCrashHandlers(_Throwing());
    expect(
      () => PlatformDispatcher.instance.onError!(
        StateError('x'),
        StackTrace.current,
      ),
      returnsNormally,
    );
  });

  test('installing twice reports once per error', () {
    installCrashHandlers(sink);
    installCrashHandlers(sink);
    PlatformDispatcher.instance.onError!(StateError('x'), StackTrace.current);
    expect(sink.reports, hasLength(1));
  });
}

final class _Throwing implements CrashSink {
  @override
  void report(CrashReport r) => throw StateError('sink broke');
}
