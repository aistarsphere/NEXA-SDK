import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Plays one local audio file (a seam for tests).
abstract interface class NexaAudioPlayback {
  Future<void> play(String path);
  Future<void> pause();
  Future<void> resume();

  /// Fires when playback reaches the end.
  Stream<void> get completed;
  Future<void> dispose();
}

/// [NexaAudioPlayback] backed by `audioplayers` (Android and iOS).
final class PluginAudioPlayback implements NexaAudioPlayback {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> resume() => _player.resume();

  @override
  Stream<void> get completed => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _player.dispose();
}

/// An audio asset (e.g. a `voice.profile.preview` sample): downloaded on
/// the first Play into a private temporary file, deleted again on
/// dispose. The bytes are never logged.
class LabeebAudioAssetTile extends StatefulWidget {
  const LabeebAudioAssetTile({
    required this.asset,
    required this.bytes,
    this.trailing,
    this.playback,
    super.key,
  });

  final NexaAssetRef asset;
  final Future<Uint8List> Function(String assetId) bytes;
  final Widget? trailing;
  final NexaAudioPlayback Function()? playback;

  @override
  State<LabeebAudioAssetTile> createState() => _LabeebAudioAssetTileState();
}

enum _Audio { idle, loading, playing, paused, failed }

class _LabeebAudioAssetTileState extends State<LabeebAudioAssetTile> {
  NexaAudioPlayback? _player;
  StreamSubscription<void>? _done;
  File? _file;
  _Audio _state = _Audio.idle;

  Future<void> _toggle() async {
    switch (_state) {
      case _Audio.playing:
        await _player?.pause();
        if (mounted) setState(() => _state = _Audio.paused);
      case _Audio.paused:
        await _player?.resume();
        if (mounted) setState(() => _state = _Audio.playing);
      case _Audio.loading:
        return;
      case _Audio.idle || _Audio.failed:
        setState(() => _state = _Audio.loading);
        try {
          final file = _file ??= await _write();
          final player = _player ??=
              (widget.playback ?? PluginAudioPlayback.new)();
          _done ??= player.completed.listen((_) {
            if (mounted) setState(() => _state = _Audio.idle);
          });
          await player.play(file.path);
          if (mounted) setState(() => _state = _Audio.playing);
        } on Object {
          if (mounted) setState(() => _state = _Audio.failed);
        }
    }
  }

  Future<File> _write() async {
    final data = await widget.bytes(widget.asset.id);
    final ext = switch (widget.asset.mime) {
      'audio/mpeg' => '.mp3',
      'audio/ogg' => '.ogg',
      'audio/mp4' || 'audio/aac' => '.m4a',
      _ => '.wav',
    };
    final f = File(
      '${Directory.systemTemp.path}/labeeb_audio_${widget.asset.id}$ext',
    );
    await f.writeAsBytes(data, flush: true);
    return f;
  }

  @override
  void dispose() {
    unawaited(_done?.cancel());
    unawaited(_player?.dispose());
    final f = _file;
    if (f != null && f.existsSync()) f.deleteSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final playing = _state == _Audio.playing;
    return ListTile(
      key: Key('labeeb_asset_${widget.asset.id}'),
      contentPadding: EdgeInsets.zero,
      leading: _state == _Audio.loading
          ? const SizedBox.square(
              dimension: 40,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton.filledTonal(
              key: Key('labeeb_audio_toggle_${widget.asset.id}'),
              tooltip: playing ? l10n.audioPause : l10n.audioPlay,
              onPressed: _toggle,
              icon: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
      title: Text(
        widget.asset.generated
            ? l10n.tcGenerated
            : widget.asset.filename ?? l10n.audioPlay,
      ),
      subtitle: _state == _Audio.failed
          ? Text(
              l10n.audioFailed,
              key: Key('labeeb_audio_failed_${widget.asset.id}'),
              style: TextStyle(color: scheme.error),
            )
          : null,
      trailing: widget.trailing,
    );
  }
}
