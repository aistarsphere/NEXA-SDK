import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records a short microphone sample to a private temporary file.
///
/// Only started by an explicit user action (the recording sheet); nothing
/// is captured before that, and the file is deleted by the caller once it
/// is uploaded.
abstract interface class NexaMicrophoneRecorder {
  /// Asks the OS for microphone access when not yet decided.
  Future<bool> requestPermission();

  /// Starts recording to a new temporary file.
  Future<void> start();

  /// Input level, 0..1, while recording.
  Stream<double> get level;

  /// Stops and returns the recorded file (null: nothing recorded).
  Future<File?> stop();

  /// Stops and discards the recording.
  Future<void> cancel();

  Future<void> dispose();
}

/// [NexaMicrophoneRecorder] backed by the `record` plugin: WAV, 16 kHz,
/// mono, OS noise suppression on. WAV keeps the sample lossless for
/// voice processing.
final class PluginMicrophoneRecorder implements NexaMicrophoneRecorder {
  PluginMicrophoneRecorder() : _recorder = AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;

  static const config = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 16000,
    numChannels: 1,
    noiseSuppress: true,
    echoCancel: true,
  );

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/nexa_sample_${DateTime.now().microsecondsSinceEpoch}.wav';
    _path = path;
    await _recorder.start(config, path: path);
  }

  @override
  Stream<double> get level => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      // dBFS (-160..0) to 0..1; speech sits around -40..-10.
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0));

  @override
  Future<File?> stop() async {
    final path = await _recorder.stop() ?? _path;
    _path = null;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  @override
  Future<void> cancel() async {
    _path = null;
    await _recorder.cancel();
  }

  @override
  Future<void> dispose() => _recorder.dispose();
}
