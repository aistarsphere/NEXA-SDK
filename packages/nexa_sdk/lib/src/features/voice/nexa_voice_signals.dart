import 'dart:async';

import 'package:nexa_core/nexa_core.dart';

/// Client→agent signals of a call: listening control (mute / phone call)
/// and client info (platform, device, route, mute state). Sent only when the
/// agent advertises them in `agent_ready.capabilities.client_signals`:
///
/// ```json
/// "client_signals": {
///   "listening_control": "nexa.voice.listening",
///   "client_info": "nexa.voice.client_info"
/// }
/// ```
///
/// A value of `true` means "accepted under the default name"; a string is
/// the RPC method to call. Status: accepted by the backend as proposed
/// (docs/voice/client-signals-proposal.md, backend release d42c1ba). The
/// agent repeats `capabilities` in every `session_state` and in the `resume`
/// answer; [update] reads those without resetting a running signal.
///
/// Every send is an RPC to the agent, which shares the server's RPC rate
/// limit (burst 20, then 2/s) with `resume`. So each signal keeps only its
/// newest value, has at most one request in flight and waits [minInterval]
/// between sends; an `unsupported` answer stops that signal for the session.
/// Payloads never carry audio or text.
final class NexaVoiceSignals {
  NexaVoiceSignals({
    required Future<RealtimeSignalResult> Function(
      String method,
      Map<String, Object?> payload,
    )
    send,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
    this.minInterval = const Duration(milliseconds: 600),
    this.onResult,
  }) : _send = send,
       _diagnostics = diagnostics;

  /// Called after every send with the method, payload and result (for the
  /// debug panel; payloads carry no content).
  final void Function(
    String method,
    Map<String, Object?> payload,
    RealtimeSignalResult result,
  )?
  onResult;

  static const defaultListeningMethod = 'nexa.voice.listening';
  static const defaultClientInfoMethod = 'nexa.voice.client_info';

  final Future<RealtimeSignalResult> Function(
    String method,
    Map<String, Object?> payload,
  )
  _send;
  final NexaDiagnostics _diagnostics;
  final Duration minInterval;

  _Signal? _listening;
  _Signal? _clientInfo;

  bool get listeningEnabled => _listening != null;
  String? get listeningMethod => _listening?.method;
  bool get clientInfoEnabled => _clientInfo != null;

  /// Reads `capabilities` of `agent_ready`: a (new) agent starts afresh.
  void configure(Map<String, Object?> capabilities) {
    reset();
    update(capabilities, source: 'agent_ready');
  }

  /// Reads `capabilities` of a `session_state` snapshot or a `resume`
  /// answer. A signal whose method is unchanged keeps its state (pending
  /// value, or stopped after `unsupported`). Returns true when a signal was
  /// not enabled before and is now: the caller sends the current state.
  bool update(Map<String, Object?> capabilities, {String source = 'snapshot'}) {
    final cs = capabilities['client_signals'];
    String? name(Object? v, String fallback) =>
        v is String && v.isNotEmpty ? v : (v == true ? fallback : null);
    final listening = cs is Map
        ? name(cs['listening_control'], defaultListeningMethod)
        : null;
    final info = cs is Map
        ? name(cs['client_info'], defaultClientInfoMethod)
        : null;
    final before = (_listening?.method, _clientInfo?.method);
    _Signal? keep(_Signal? old, String? method) {
      if (old != null && old.method == method) return old;
      old?.closed = true;
      return method == null ? null : _Signal(method, this);
    }

    _listening = keep(_listening, listening);
    _clientInfo = keep(_clientInfo, info);
    final changed = before != (listening, info);
    if (changed) {
      _diagnostics.record('voice.signals', {
        'source': source,
        'listening_control': listening,
        'client_info': info,
      });
    }
    return (before.$1 == null && listening != null) ||
        (before.$2 == null && info != null);
  }

  /// A call ended: nothing is sent until the next `agent_ready`.
  void reset() {
    _listening?.closed = true;
    _clientInfo?.closed = true;
    _listening = null;
    _clientInfo = null;
  }

  /// The microphone stopped (false) or resumed (true) sending; [reason] is
  /// `mute`, `unmute`, `phone_call` or `phone_call_ended` (the agreed set;
  /// another app's call is reported as `phone_call`). The agent stops
  /// listening, drops the cut-off utterance and resets its VAD while false.
  void listening({required bool listening, required String reason}) =>
      _listening?.post({'listening': listening, 'reason': reason});

  void clientInfo(Map<String, Object?> info) => _clientInfo?.post(info);
}

final class _Signal {
  _Signal(this.method, this.owner);

  final String method;
  final NexaVoiceSignals owner;
  Map<String, Object?>? _pending;
  bool _busy = false;
  bool closed = false;
  bool _retried = false;
  DateTime? _lastSent;

  void post(Map<String, Object?> payload) {
    if (closed) return;
    _pending = payload;
    if (!_busy) unawaited(_drain());
  }

  Future<void> _drain() async {
    _busy = true;
    try {
      while (_pending != null && !closed) {
        final last = _lastSent;
        if (last != null) {
          final wait = owner.minInterval - DateTime.now().difference(last);
          if (wait > Duration.zero) await Future<void>.delayed(wait);
        }
        final payload = _pending!;
        _pending = null;
        if (closed) return;
        _lastSent = DateTime.now();
        final result = await owner._send(method, payload);
        owner._diagnostics.record('voice.signal', {
          'method': method,
          'result': result.name,
        });
        owner.onResult?.call(method, payload, result);
        if (result == RealtimeSignalResult.unsupported) {
          closed = true;
          return;
        }
        // One retry of a failed value, unless a newer one replaced it.
        if (result == RealtimeSignalResult.failed && !_retried) {
          _retried = true;
          _pending ??= payload;
        } else {
          _retried = false;
        }
      }
    } finally {
      _busy = false;
    }
  }
}
