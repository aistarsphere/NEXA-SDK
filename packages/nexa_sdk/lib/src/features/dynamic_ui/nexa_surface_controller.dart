import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_host_capabilities.dart';
import 'package:nexa_sdk/src/features/media/nexa_device_actions.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// State and behaviour of Dynamic UI surfaces: holds surfaces by
/// `surface_id` (updates replace by id, keeping the user's selections),
/// local selections/values (optimistic), and turns every interaction into
/// a typed [NexaSurfaceEvent] — identical for touch now and voice/text
/// selection later.
final class NexaSurfaceController extends ChangeNotifier {
  NexaSurfaceController({
    this.host = const NexaHostCapabilities(),
    this.deviceActions,
    this.sink,
  });

  NexaHostCapabilities host;
  final NexaDeviceActions? deviceActions;

  /// Sends events to the backend; returns true when accepted. Null (or
  /// false) while the backend has no UI event endpoint.
  Future<bool> Function(NexaSurfaceEvent event)? sink;

  final Map<String, NexaSurface> _surfaces = {};
  final Map<String, Map<String, Object?>> _values = {};
  final Set<String> _busy = {};
  final StreamController<NexaSurfaceEvent> _events =
      StreamController<NexaSurfaceEvent>.broadcast();

  /// Every interaction, in order.
  Stream<NexaSurfaceEvent> get events => _events.stream;

  NexaSurface? surface(String id) => _surfaces[id];

  /// Adds or updates a surface (same id: components diff by id; the
  /// user's selections survive while their choice ids still exist).
  void upsert(NexaSurface s) {
    _surfaces[s.surfaceId] = s;
    final values = _values.putIfAbsent(s.surfaceId, () => {});
    for (final c in s.components) {
      final ids = {for (final ch in c.choices) ch.id};
      final current = values[c.id];
      if (current == null && c.data.containsKey('value')) {
        values[c.id] =
            c.type == 'multi_choice' ||
                c.type == 'filter_chips' ||
                c.type == 'search_results'
            ? {...((c.data['value'] as List?) ?? const []).cast<String>()}
            : c.data['value'];
      } else if (current is String &&
          ids.isNotEmpty &&
          !ids.contains(current)) {
        values.remove(c.id); // choice disappeared in the update
      } else if (current is Set<String> && ids.isNotEmpty) {
        current.removeWhere((id) => !ids.contains(id));
      }
    }
    notifyListeners();
  }

  void remove(String surfaceId) {
    _surfaces.remove(surfaceId);
    _values.remove(surfaceId);
    notifyListeners();
  }

  Object? value(String surfaceId, String componentId) =>
      _values[surfaceId]?[componentId];

  bool isBusy(String surfaceId) => _busy.contains(surfaceId);

  /// Whether a host capability needed by [s] is missing.
  bool hostUnavailable(NexaSurface s) =>
      s.category == NexaSurfaceCategory.themesAppearance && host.theme == null;

  // -------------------------------------------------------------- inputs

  /// Selects [choiceIds] in [componentId] (single: one id).
  Future<void> select(
    NexaSurface s,
    NexaComponent c,
    List<String> choiceIds, {
    NexaSelectionSource source = NexaSelectionSource.touch,
    String? utterance,
  }) async {
    final multi =
        c.type == 'multi_choice' ||
        c.type == 'filter_chips' ||
        c.type == 'search_results';
    final values = _values.putIfAbsent(s.surfaceId, () => {});
    values[c.id] = multi ? {...choiceIds} : choiceIds.firstOrNull;
    notifyListeners();
    await _emit(
      NexaSurfaceEvent(
        eventType: 'selection',
        surfaceId: s.surfaceId,
        messageId: s.messageId,
        conversationId: s.conversationId,
        componentId: c.id,
        choiceIds: choiceIds,
        source: source,
        utterance: utterance,
      ),
    );
    // Themes: a palette/appearance selection previews app-wide.
    if (s.category == NexaSurfaceCategory.themesAppearance &&
        host.theme != null) {
      final (palette, appearance) = _themeParams(s);
      await host.theme!.preview(palette, appearance);
    }
  }

  /// Switch / slider / text input values.
  Future<void> setValue(NexaSurface s, NexaComponent c, Object? v) async {
    _values.putIfAbsent(s.surfaceId, () => {})[c.id] = v;
    notifyListeners();
    await _emit(
      NexaSurfaceEvent(
        eventType: 'value_change',
        surfaceId: s.surfaceId,
        messageId: s.messageId,
        conversationId: s.conversationId,
        componentId: c.id,
        value: v,
      ),
    );
  }

  (String, NexaAppearance) _themeParams(NexaSurface s) {
    final theme = host.theme!;
    String? palette;
    NexaAppearance? appearance;
    for (final c in s.components) {
      final v = value(s.surfaceId, c.id);
      if (c.type == 'palette_choice' && v is String) palette = v;
      if (c.type == 'segmented' && v is String) {
        appearance = appearanceFromWire(v);
      }
    }
    return (
      palette ?? theme.appliedPaletteId,
      appearance ?? theme.appliedAppearance,
    );
  }

  Map<String, Object?> _params(NexaSurface s, NexaSurfaceAction a) => {
    for (final id in a.paramsFrom)
      id: switch (value(s.surfaceId, id)) {
        final Set<String> set => set.toList(),
        final Object? v => v,
      },
  };

  // ------------------------------------------------------------- actions

  /// Runs a predefined action. Returns a user-facing outcome message or
  /// null. Unknown action types never run.
  Future<String?> act(
    BuildContext context,
    NexaSurface s,
    NexaSurfaceAction a,
  ) async {
    if (!a.known) return null;
    final l10n = NexaLocalizations.of(context);
    if (a.requiresConfirmation) {
      final ok = await _confirm(context, a);
      if (!ok || !context.mounted) return null;
    }
    _busy.add(s.surfaceId);
    notifyListeners();
    try {
      await _emit(
        NexaSurfaceEvent(
          eventType: 'action',
          surfaceId: s.surfaceId,
          messageId: s.messageId,
          conversationId: s.conversationId,
          actionId: a.id,
          actionType: a.type,
          params: _params(s, a),
        ),
      );
      final theme = host.theme;
      switch (a.type) {
        case 'host.theme.apply':
          if (theme == null) return l10n.duiHostUnavailable;
          final (p, ap) = _themeParams(s);
          return await theme.apply(p, ap) ? l10n.duiThemeApplied : null;
        case 'host.theme.reset':
          if (theme == null) return l10n.duiHostUnavailable;
          final ok = await theme.reset();
          if (ok) {
            final values = _values[s.surfaceId] ?? {};
            for (final c in s.components) {
              if (c.type == 'palette_choice') {
                values[c.id] = theme.appliedPaletteId;
              }
              if (c.type == 'segmented') {
                values[c.id] = theme.appliedAppearance.name;
              }
            }
          }
          return ok ? l10n.duiThemeReset : null;
        case 'cancel':
          if (s.category == NexaSurfaceCategory.themesAppearance) {
            await theme?.cancelPreview();
          }
          return null;
        case 'open_url' || 'open_navigation':
          final url = a.data['url'] as String?;
          if (url == null || deviceActions == null || !context.mounted) {
            return null;
          }
          await deviceActions!.runTool(context, BrowserOpenTool.id, {
            'url': url,
          });
          return null;
        case 'camera.capture':
          if (deviceActions != null && context.mounted) {
            await deviceActions!.takePhoto(context);
          }
          return null;
        case 'location.get':
          if (deviceActions != null && context.mounted) {
            await deviceActions!.shareLocation(context);
          }
          return null;
        default:
          // Backend-handled actions (summarize, compare, follow_up,
          // workflow.*, approval, …): the event above is the request.
          return null;
      }
    } finally {
      _busy.remove(s.surfaceId);
      notifyListeners();
    }
  }

  Future<bool> _confirm(BuildContext context, NexaSurfaceAction a) async {
    final l10n = NexaLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => nexaScoped(
            context,
            AlertDialog(
              key: const Key('nexa_surface_confirm'),
              title: Text(a.label ?? l10n.duiConfirmTitle),
              content: Text(l10n.duiConfirmBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  key: const Key('nexa_surface_confirm_ok'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(l10n.duiConfirm),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  /// Whether events reach the backend (false: local only).
  bool get eventsDelivered => sink != null;

  Future<void> _emit(NexaSurfaceEvent e) async {
    if (!_events.isClosed) _events.add(e);
    await sink?.call(e);
  }

  @override
  void dispose() {
    unawaited(_events.close());
    super.dispose();
  }
}
