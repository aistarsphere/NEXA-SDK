import 'package:flutter/widgets.dart';
import 'package:nexa_sdk/src/features/voice/nexa_voice_controller.dart';

/// Tells the voice controller when the app leaves and returns to the
/// foreground (`paused` / `resumed`). The controller decides what that
/// means for a call (see [NexaVoiceController.notePaused]).
final class NexaVoiceLifecycle with WidgetsBindingObserver {
  NexaVoiceLifecycle(this._voice);

  final NexaVoiceController _voice;
  bool _attached = false;

  /// Starts observing. Does nothing without a widgets binding (pure Dart).
  void attach() {
    if (_attached) return;
    try {
      WidgetsBinding.instance.addObserver(this);
      _attached = true;
    } on Object {
      // No binding (headless use): the host can call notePaused/noteResumed.
    }
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _voice.notePaused();
      case AppLifecycleState.resumed:
        _voice.noteResumed();
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.detached:
        break;
    }
  }
}
