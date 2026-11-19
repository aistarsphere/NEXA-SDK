// Diagnostics only: the peer connections are LiveKit internals.
// ignore_for_file: invalid_use_of_internal_member
import 'dart:async';

import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:nexa_core/nexa_core.dart';

/// Development diagnostics for one LiveKit room: samples WebRTC stats of
/// the publisher and subscriber peer connections every [interval] and
/// records them on [NexaDiagnostics] (`voice.ice`, `voice.audio_stats`,
/// `voice.inbound_audio`).
///
/// Records candidate *types* and protocols, never IP addresses; only whether
/// an address is in the shared/CGNAT range 100.64.0.0/10 (used by overlay
/// VPNs such as NetBird, a known cause of lost media).
///
/// `voice.inbound_audio` marks the sample in which received audio energy
/// went from silent to audible (or back): it is the client-measured start
/// of audible assistant output, with [interval] resolution.
final class LiveKitStatsSampler {
  LiveKitStatsSampler(
    this._room,
    this._diagnostics, {
    this.interval = const Duration(seconds: 1),
  });

  final lk.Room _room;
  final NexaDiagnostics _diagnostics;
  final Duration interval;

  /// Received-energy increase per second above which audio counts as
  /// audible (silence and DTX stay well below; speech is ~1e-3 and up).
  static const audibleEnergyPerSecond = 1e-4;

  Timer? _timer;
  bool _sampling = false;
  final Map<String, String?> _ice = {};
  String? _pair;
  double? _lastEnergy;
  int? _lastEnergyAtMs;
  bool _audible = false;
  final Stopwatch _clock = Stopwatch();

  void start() {
    if (!_diagnostics.enabled || _timer != null) return;
    _clock.start();
    _timer = Timer.periodic(interval, (_) => unawaited(_sample()));
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    if (_diagnostics.enabled) await _sample(); // final counters
  }

  Future<void> _sample() async {
    if (_sampling) return;
    _sampling = true;
    try {
      final engine = _room.engine;
      final out = <String, Object?>{};
      for (final (name, t) in [
        ('pub', engine.publisher),
        ('sub', engine.subscriber),
      ]) {
        if (t == null) continue;
        final ice = t.pc.iceConnectionState?.name.replaceFirst(
          'RTCIceConnectionState',
          '',
        );
        if (_ice[name] != ice) {
          _ice[name] = ice;
          _diagnostics.record('voice.ice', {'pc': name, 'state': ice});
        }
        final List<_Report> reports;
        try {
          final raw = await t.pc.getStats().timeout(const Duration(seconds: 2));
          reports = [
            for (final r in raw) (id: r.id, type: r.type, values: r.values),
          ];
        } on Object {
          out['${name}_stats'] = 'timeout';
          continue;
        }
        _read(name, reports, out);
      }
      _diagnostics.record('voice.audio_stats', out);
    } on Object catch (e) {
      _diagnostics.record('voice.audio_stats', {
        'error': e.runtimeType.toString(),
      });
    } finally {
      _sampling = false;
    }
  }

  void _read(String pc, List<_Report> reports, Map<String, Object?> out) {
    final byId = {for (final r in reports) r.id: r.values};
    for (final r in reports) {
      final v = r.values;
      switch (r.type) {
        case 'transport':
          final pair = byId[v['selectedCandidatePairId']];
          if (pair != null) _recordPair(pc, pair, byId);
          out['${pc}_rx_bytes'] = v['bytesReceived'];
          out['${pc}_tx_bytes'] = v['bytesSent'];
        case 'inbound-rtp' when v['kind'] == 'audio':
          out['in_packets'] = v['packetsReceived'];
          out['in_lost'] = v['packetsLost'];
          out['in_jitter'] = v['jitter'];
          out['in_concealed'] = v['concealedSamples'];
          final energy = _num(v['totalAudioEnergy']);
          out['in_energy'] = energy;
          if (energy != null) _trackAudible(energy);
        case 'outbound-rtp' when v['kind'] == 'audio':
          out['out_packets'] = v['packetsSent'];
        case 'media-source' when v['kind'] == 'audio':
          out['mic_level'] = v['audioLevel'];
      }
    }
  }

  void _recordPair(
    String pc,
    Map<dynamic, dynamic> pair,
    Map<String, Map<dynamic, dynamic>> byId,
  ) {
    final local = byId[pair['localCandidateId']] ?? const {};
    final remote = byId[pair['remoteCandidateId']] ?? const {};
    final data = <String, Object?>{
      'pc': pc,
      'local_type': local['candidateType'],
      'local_protocol': local['protocol'],
      'local_relay_protocol': local['relayProtocol'],
      'local_network': local['networkType'],
      'local_cgnat': _isCgnat(local['address'] ?? local['ip']),
      'remote_type': remote['candidateType'],
      'remote_protocol': remote['protocol'],
      'remote_cgnat': _isCgnat(remote['address'] ?? remote['ip']),
    };
    final key = data.values.join('|');
    final rtt = _num(pair['currentRoundTripTime']);
    if (key != _pair) {
      _pair = key;
      _diagnostics.record('voice.ice_pair', {
        ...data,
        if (rtt != null) 'rtt_ms': (rtt * 1000).round(),
      });
    }
  }

  void _trackAudible(double energy) {
    final now = _clock.elapsedMilliseconds;
    final last = _lastEnergy;
    final lastAt = _lastEnergyAtMs;
    _lastEnergy = energy;
    _lastEnergyAtMs = now;
    if (last == null || lastAt == null || now <= lastAt) return;
    final perSecond = (energy - last) * 1000 / (now - lastAt);
    final audible = perSecond > audibleEnergyPerSecond;
    if (audible == _audible) return;
    _audible = audible;
    _diagnostics.record('voice.inbound_audio', {
      'audible': audible,
      'energy_per_s': perSecond,
      'resolution_ms': interval.inMilliseconds,
    });
  }

  static double? _num(Object? v) => v is num ? v.toDouble() : null;

  /// 100.64.0.0/10 (RFC 6598), used by NetBird/Tailscale overlays.
  static bool? _isCgnat(Object? address) {
    if (address is! String) return null;
    final parts = address.split('.');
    if (parts.length != 4) return false;
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    return a == 100 && b != null && b >= 64 && b <= 127;
  }
}

typedef _Report = ({String id, String type, Map<dynamic, dynamic> values});
