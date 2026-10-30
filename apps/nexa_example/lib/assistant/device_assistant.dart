import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_assistant/nexa_assistant.dart';
import 'package:nexa_example/assistant/device_assistant_strings.dart';
import 'package:nexa_example/brand/labeeb_brand.dart';
import 'package:nexa_sdk/nexa_sdk.dart';

/// LABEEB as the Android assistant: turns device activations (assist
/// gesture/button, «يا لبيب») into a live-voice conversation, either in the
/// compact system panel (over another app) or the in-app voice screen.
///
/// * The panel and the app share one engine and one voice controller: a
///   call started in the panel is the same call the full app shows.
/// * Activations above the lock screen are held behind [DeviceAssistantLockGate]
///   until Android unlocks; nothing private is shown before that.
/// * The wake listener releases the microphone while a voice call runs.
/// * Nothing here talks to the backend: the voice session starts only
///   through the SDK, after a local activation.
class DeviceAssistant extends ChangeNotifier {
  DeviceAssistant({required this.client, NexaAssistant? plugin})
    : plugin = plugin ?? NexaAssistant();

  final NexaClient client;
  final NexaAssistant plugin;

  /// The Arabic wake phrase (shown in settings and the notification).
  static const wakePhrase = 'يا لبيب';

  bool get supported => plugin.supported;

  late final StreamController<void> _voice = StreamController<void>.broadcast(
    onListen: _flushPending,
  );
  bool _pendingVoice = false;

  /// Feed for `assistantView(voiceRequests:)`.
  Stream<void> get voiceRequests => _voice.stream;

  bool _lockedSession = false;

  /// Shown above the lock screen and waiting for the user to unlock.
  bool get lockedSession => _lockedSession;

  NexaAssistantSurface _surface = NexaAssistantSurface.none;

  /// The compact system panel is showing: render [DeviceAssistantPanelHost].
  NexaAssistantSurface get surface => _surface;

  Duration? _idleTimeout = const Duration(seconds: 60);

  /// Panel conversations end after this much inactivity (null: never).
  Duration? get idleTimeout => _idleTimeout;

  set idleTimeout(Duration? value) {
    _idleTimeout = value;
    unawaited(plugin.setIdleTimeout(value?.inSeconds ?? 0));
    notifyListeners();
  }

  final ValueNotifier<bool> _voiceBusy = ValueNotifier(false);
  StreamSubscription<NexaAssistantEvent>? _events;
  VoidCallback? _unfollow;

  /// Call before `runApp`: a cold start straight into the panel then
  /// renders the panel in its first frame.
  Future<void> start() async {
    if (!supported) return;
    await plugin.configure(phraseLabel: wakePhrase);
    client.voice.state.addListener(_syncVoice);
    _syncVoice();
    _unfollow = plugin.followMicrophoneUse(_voiceBusy);
    _events = plugin.events.listen((e) {
      switch (e) {
        case NexaAssistantActivation():
          _onActivation(e);
        case NexaAssistantSurface():
          _onSurface(e);
        default:
          break;
      }
    });
    final status = await plugin.status();
    _idleTimeout = status.idleTimeoutSeconds <= 0
        ? null
        : Duration(seconds: status.idleTimeoutSeconds);
    _onSurface(await plugin.surface());
    final pending = await plugin.takePendingActivation();
    if (pending != null) _onActivation(pending);
  }

  void _onSurface(NexaAssistantSurface s) {
    final wasPanel = _surface.panel;
    _surface = s;
    _syncVoice();
    notifyListeners();
    // Dismissed by the system (home, back, another app): end the call so
    // no session or microphone lingers. Expand keeps it.
    if (wasPanel && !s.panel && s.reason == 'dismissed') {
      if (client.voice.state.value.isActive) unawaited(client.voice.end());
      unawaited(plugin.reportSessionEnd('dismissed'));
    }
  }

  /// The panel ended its call (close, idle timeout, call ended).
  Future<void> panelClosed(NexaPanelCloseReason reason) async {
    debugPrint('[assistant] panel conversation ended: ${reason.code}');
    await plugin.closePanel(reason.code);
  }

  /// Continue the panel's call in the full app.
  Future<void> expandPanel() => plugin.expandPanel();

  /// The wake listener stays off the microphone during a call and while
  /// the panel is open (also after a failed start, until it closes).
  void _syncVoice() =>
      _voiceBusy.value = client.voice.state.value.isActive || _surface.panel;

  void _onActivation(NexaAssistantActivation a) {
    if (a.locked) {
      _lockedSession = true;
      notifyListeners();
      return;
    }
    _requestVoice();
  }

  void _requestVoice() {
    if (_voice.hasListener) {
      _voice.add(null);
    } else {
      _pendingVoice = true; // cold start: the assistant view is not up yet
    }
  }

  void _flushPending() {
    if (!_pendingVoice) return;
    _pendingVoice = false;
    scheduleMicrotask(() => _voice.add(null));
  }

  /// Android's own unlock (PIN, pattern, biometrics); then the call opens.
  Future<NexaUnlockResult> unlock() async {
    final r = await plugin.requestUnlock();
    if (r == NexaUnlockResult.unlocked) {
      _lockedSession = false;
      notifyListeners();
      _requestVoice();
    }
    return r;
  }

  /// Leaves the lock-screen session without showing anything.
  Future<void> dismissLocked() async {
    _lockedSession = false;
    notifyListeners();
    await plugin.endLockScreenSession(moveToBack: true);
    await plugin.resumeListening();
  }

  @override
  void dispose() {
    client.voice.state.removeListener(_syncVoice);
    _unfollow?.call();
    unawaited(_events?.cancel());
    unawaited(_voice.close());
    _voiceBusy.dispose();
    super.dispose();
  }
}

/// Renders the compact panel when the system assistant window shows it
/// (the app itself stays built but off screen, so its state survives).
class DeviceAssistantPanelHost extends StatelessWidget {
  const DeviceAssistantPanelHost({
    required this.assistant,
    required this.child,
    super.key,
  });

  final DeviceAssistant assistant;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: assistant,
    builder: (context, _) {
      final s = assistant.surface;
      final lang = Localizations.localeOf(context).languageCode;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: s.panel,
            child: ExcludeSemantics(
              excluding: s.panel,
              child: TickerMode(enabled: !s.panel, child: child),
            ),
          ),
          if (s.panel)
            // Drawn above the app's navigator: bring an overlay for tooltips.
            Overlay.wrap(
              child: NexaCompactVoicePanel(
                key: const Key('assistant_panel'),
                voice: assistant.client.voice,
                tools: assistant.client.toolCalls,
                title: Labeeb.name(lang),
                placement: switch (s.position) {
                  NexaPanelPosition.bottom => NexaPanelPlacement.bottom,
                  NexaPanelPosition.top => NexaPanelPlacement.top,
                  NexaPanelPosition.left => NexaPanelPlacement.left,
                  NexaPanelPosition.right => NexaPanelPlacement.right,
                },
                idleTimeout: assistant.idleTimeout,
                voiceVerified: s.verified ?? false,
                activationSource: s.source,
                onClosed: assistant.panelClosed,
                onExpand: assistant.expandPanel,
              ),
            ),
        ],
      );
    },
  );
}

/// Covers the whole app while it is shown above the lock screen: the
/// conversation, history and account stay hidden until Android unlocks.
class DeviceAssistantLockGate extends StatelessWidget {
  const DeviceAssistantLockGate({
    required this.assistant,
    required this.child,
    super.key,
  });

  final DeviceAssistant assistant;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: assistant,
    builder: (context, _) {
      final locked = assistant.lockedSession;
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(
            offstage: locked,
            child: ExcludeSemantics(
              excluding: locked,
              child: TickerMode(enabled: !locked, child: child),
            ),
          ),
          if (locked) _Gate(assistant: assistant),
        ],
      );
    },
  );
}

class _Gate extends StatefulWidget {
  const _Gate({required this.assistant});
  final DeviceAssistant assistant;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _busy = false;
  NexaUnlockResult? _last;

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final r = await widget.assistant.unlock();
    if (mounted) {
      setState(() {
        _busy = false;
        _last = r;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = DeviceAssistantStrings.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lang = Localizations.localeOf(context).languageCode;
    return Material(
      key: const Key('assistant_lock_gate'),
      color: scheme.surface,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 32,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  Labeeb.name(lang),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.unlockToContinue,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (_last == NexaUnlockResult.cancelled ||
                    _last == NexaUnlockResult.error) ...[
                  const SizedBox(height: 8),
                  Text(
                    s.unlockNotDone,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('assistant_lock_unlock'),
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open_rounded),
                  label: Text(s.unlock),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('assistant_lock_cancel'),
                  onPressed: _busy ? null : widget.assistant.dismissLocked,
                  child: Text(s.notNow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
