import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_device/nexa_device.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_surface_controller.dart';
import 'package:nexa_sdk/src/features/media/nexa_device_actions.dart';
import 'package:nexa_sdk/src/features/media/nexa_media_widgets.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Renders one validated [NexaSurface] with the closed component library.
/// Container-agnostic: the presentation (inline, sheet, modal, panel, full
/// screen, voice companion) wraps this widget. Data only: nothing in the
/// payload is executed; links open only after a tap.
class NexaSurfaceView extends StatelessWidget {
  const NexaSurfaceView({
    required this.surfaceId,
    required this.controller,
    this.onRetry,
    this.onClose,
    this.compact = false,
    super.key,
  });

  final String surfaceId;
  final NexaSurfaceController controller;
  final VoidCallback? onRetry;

  /// Called after cancel / apply / reset (e.g. to close a sheet).
  final VoidCallback? onClose;

  /// Tighter layout (voice companion).
  final bool compact;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, ?controller.host.theme]),
    builder: (context, _) {
      final s = controller.surface(surfaceId);
      if (s == null) return const SizedBox.shrink();
      return _Surface(
        s: s,
        controller: controller,
        onRetry: onRetry,
        onClose: onClose,
        compact: compact,
      );
    },
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.s,
    required this.controller,
    required this.compact,
    this.onRetry,
    this.onClose,
  });

  final NexaSurface s;
  final NexaSurfaceController controller;
  final VoidCallback? onRetry;
  final VoidCallback? onClose;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (!s.supported) {
      return _Fallback(
        key: const Key('nexa_surface_unsupported'),
        text: s.fallbackText.isEmpty ? l10n.duiUnsupported : s.fallbackText,
      );
    }
    final hostMissing = controller.hostUnavailable(s);
    final state = s.status.state;
    final blocked =
        hostMissing ||
        state == NexaSurfaceState.disabled ||
        state == NexaSurfaceState.loading;
    final offline = state == NexaSurfaceState.offline;
    final children = <Widget>[];

    // Header.
    if (s.title != null || s.demo) {
      children.add(
        Row(
          children: [
            if (s.title != null)
              Expanded(
                child: Text(
                  s.title!,
                  key: const Key('nexa_surface_title'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            if (s.demo)
              Container(
                key: const Key('nexa_surface_demo'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: NexaColors.of(context).warningContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  l10n.duiDemo,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: NexaColors.of(context).warning,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    if (s.description != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            s.description!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Shared states.
    Widget? stateBox;
    switch (state) {
      case NexaSurfaceState.loading:
        stateBox = const _StateLine(
          key: Key('nexa_surface_loading'),
          icon: null,
          progress: true,
        );
      case NexaSurfaceState.partial:
        children.add(
          _Banner(kind: 'info', text: s.status.message ?? l10n.duiPartial),
        );
      case NexaSurfaceState.empty:
        stateBox = _StateLine(
          key: const Key('nexa_surface_empty'),
          icon: Icons.inbox_outlined,
          text: s.status.message ?? l10n.duiEmpty,
        );
      case NexaSurfaceState.error:
        stateBox = _StateLine(
          key: const Key('nexa_surface_error'),
          icon: Icons.error_outline,
          text: s.status.message ?? l10n.duiError,
          retry: s.status.retryable ? onRetry : null,
        );
      case NexaSurfaceState.providerUnavailable:
        stateBox = _StateLine(
          key: const Key('nexa_surface_provider_unavailable'),
          icon: Icons.cloud_off_outlined,
          text: l10n.duiProviderUnavailable,
          retry: s.status.retryable ? onRetry : null,
        );
      case NexaSurfaceState.offline:
        children.add(
          _Banner(
            key: const Key('nexa_surface_offline'),
            kind: 'warning',
            text: l10n.duiOffline,
          ),
        );
      case NexaSurfaceState.disabled:
        children.add(_Banner(kind: 'info', text: l10n.duiDisabled));
      case NexaSurfaceState.ready || NexaSurfaceState.confirmation:
        break;
    }
    if (hostMissing) {
      children.add(
        _Banner(
          key: const Key('nexa_surface_host_unavailable'),
          kind: 'warning',
          text: l10n.duiHostUnavailable,
        ),
      );
    }

    if (stateBox != null) {
      children.add(stateBox);
    } else if (!hostMissing) {
      for (final c in s.components) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _ComponentView(
              s: s,
              c: c,
              controller: controller,
              enabled: !blocked,
              compact: compact,
            ),
          ),
        );
      }
    }

    // Provenance for provider-backed surfaces.
    final ref = s.reference;
    if (ref?.provider != null &&
        !s.components.any((c) => c.type == 'attribution')) {
      children.add(_Attribution(source: ref!.provider!, at: ref.retrievedAt));
    }

    // Actions.
    if (s.actions.isNotEmpty && stateBox == null) {
      final busy = controller.isBusy(s.surfaceId);
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in s.actions)
                _ActionButton(
                  action: a,
                  enabled:
                      !busy &&
                      a.known &&
                      !(hostMissing && a.type.startsWith('host.')) &&
                      !(offline && _needsNetwork(a)) &&
                      state != NexaSurfaceState.disabled,
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final msg = await controller.act(context, s, a);
                    if (msg != null) {
                      messenger?.showSnackBar(SnackBar(content: Text(msg)));
                    }
                    if (const {
                      'cancel',
                      'host.theme.apply',
                      'host.theme.reset',
                    }.contains(a.type)) {
                      onClose?.call();
                    }
                  },
                ),
            ],
          ),
        ),
      );
    }

    if (!controller.eventsDelivered &&
        s.category != NexaSurfaceCategory.themesAppearance &&
        _hasSelectable(s) &&
        !s.demo) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            l10n.duiSelectionsLocal,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      liveRegion: true,
      label: s.title ?? s.fallbackText,
      child: Column(
        key: Key('nexa_surface_${s.surfaceId}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  static bool _needsNetwork(NexaSurfaceAction a) => const {
    'open_url',
    'open_navigation',
    'directions',
    'download',
    'summarize',
    'compare',
    'follow_up',
  }.contains(a.type);

  static bool _hasSelectable(NexaSurface s) => s.components.any(
    (c) => const {
      'single_choice',
      'multi_choice',
      'filter_chips',
      'search_results',
      'place_list',
    }.contains(c.type),
  );
}

// ================================================================ pieces

class _Fallback extends StatelessWidget {
  const _Fallback({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text, textDirection: nexaTextDirectionOf(text));
}

class _StateLine extends StatelessWidget {
  const _StateLine({
    required this.icon,
    this.text,
    this.retry,
    this.progress = false,
    super.key,
  });

  final IconData? icon;
  final String? text;
  final VoidCallback? retry;
  final bool progress;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: progress
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    height: 14,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                Text(l10n.duiLoading),
              ],
            )
          : Row(
              children: [
                Icon(icon, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(text ?? '')),
                if (retry != null)
                  TextButton(
                    key: const Key('nexa_surface_retry'),
                    onPressed: retry,
                    child: Text(l10n.retry),
                  ),
              ],
            ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.kind, required this.text, super.key});
  final String kind;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    final (bg, fg, icon) = switch (kind) {
      'warning' || 'permission' => (
        colors.warningContainer,
        colors.warning,
        Icons.warning_amber_rounded,
      ),
      'error' => (scheme.errorContainer, scheme.onErrorContainer, Icons.error),
      'success' => (
        colors.successContainer,
        colors.success,
        Icons.check_circle_outline,
      ),
      _ => (colors.infoContainer, colors.info, Icons.info_outline),
    };
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: fg)),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution({required this.source, this.at});
  final String source;
  final DateTime? at;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final when = at == null
        ? ''
        : ' · ${MaterialLocalizations.of(context).formatShortDate(at!.toLocal())} '
              '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(at!.toLocal()))}';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        '${l10n.duiSource(source)}$when',
        key: const Key('nexa_surface_attribution'),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.enabled,
    required this.onPressed,
  });

  final NexaSurfaceAction action;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final label = action.label ?? action.type;
    final primary = const {
      'confirm',
      'host.theme.apply',
      'directions',
      'open_url',
      'approval',
      'workflow.start',
    }.contains(action.type);
    final button = primary
        ? FilledButton(
            key: Key('nexa_action_${action.id}'),
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          )
        : OutlinedButton(
            key: Key('nexa_action_${action.id}'),
            onPressed: enabled ? onPressed : null,
            child: Text(label),
          );
    return action.known
        ? button
        : Tooltip(message: l10n.duiActionUnsupported, child: button);
  }
}

// ============================================================ components

class _ComponentView extends StatelessWidget {
  const _ComponentView({
    required this.s,
    required this.c,
    required this.controller,
    required this.enabled,
    required this.compact,
  });

  final NexaSurface s;
  final NexaComponent c;
  final NexaSurfaceController controller;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final v = controller.value(s.surfaceId, c.id);
    void pick(List<String> ids) => controller.select(s, c, ids);
    final label = c.a11yLabel ?? c.title;

    Widget labelled(Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.title != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(c.title!, style: theme.textTheme.labelLarge),
          ),
        child,
      ],
    );

    String pos(NexaChoice ch, bool selected) =>
        '${l10n.duiPosition(ch.order, c.choices.length, ch.label)}'
        '${selected ? ', ${l10n.duiSelected}' : ''}';

    final widget = switch (c.type) {
      'text' => NexaRichText('${c.data['text'] ?? ''}'),
      'single_choice' || 'multi_choice' => labelled(
        Column(
          children: [
            for (final ch in c.choices)
              Builder(
                builder: (context) {
                  final multi = c.type == 'multi_choice';
                  final sel = multi
                      ? (v is Set<String> && v.contains(ch.id))
                      : v == ch.id;
                  return Semantics(
                    label: pos(ch, sel),
                    selected: sel,
                    excludeSemantics: true,
                    child: ListTile(
                      key: Key('nexa_choice_${c.id}_${ch.id}'),
                      contentPadding: EdgeInsets.zero,
                      enabled: enabled && !ch.disabled,
                      leading: Icon(
                        multi
                            ? (sel
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded)
                            : (sel
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_unchecked_rounded),
                        color: sel ? scheme.primary : null,
                      ),
                      title: Text(ch.label),
                      subtitle: ch.disabled
                          ? Text(ch.disabledReason ?? l10n.duiDisabled)
                          : ch.data['description'] == null
                          ? null
                          : Text('${ch.data['description']}'),
                      onTap: () {
                        if (!multi) return pick([ch.id]);
                        final set = {if (v is Set<String>) ...v};
                        set.contains(ch.id)
                            ? set.remove(ch.id)
                            : set.add(ch.id);
                        pick(set.toList());
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      'palette_choice' => labelled(
        _PaletteGrid(
          c: c,
          selectedId: v as String?,
          appliedId: controller.host.theme?.appliedPaletteId,
          enabled: enabled,
          onPick: (id) => pick([id]),
          position: pos,
        ),
      ),
      'segmented' => labelled(
        SegmentedButton<String>(
          key: Key('nexa_segmented_${c.id}'),
          segments: [
            for (final ch in c.choices)
              ButtonSegment(
                value: ch.id,
                label: Text(ch.label),
                enabled: !ch.disabled,
              ),
          ],
          emptySelectionAllowed: true,
          selected: {if (v is String) v},
          onSelectionChanged: enabled
              ? (set) {
                  if (set.isNotEmpty) pick([set.first]);
                }
              : null,
        ),
      ),
      'switch' => SwitchListTile(
        key: Key('nexa_switch_${c.id}'),
        contentPadding: EdgeInsets.zero,
        title: Text(c.title ?? label ?? ''),
        value: v == true,
        onChanged: enabled ? (b) => controller.setValue(s, c, b) : null,
      ),
      'slider' => labelled(
        Builder(
          builder: (context) {
            final min = (c.data['min'] as num?)?.toDouble() ?? 0;
            final max = (c.data['max'] as num?)?.toDouble() ?? 1;
            final step = (c.data['step'] as num?)?.toDouble();
            final cur = ((v as num?)?.toDouble() ?? min).clamp(min, max);
            return Slider(
              key: Key('nexa_slider_${c.id}'),
              min: min,
              max: max,
              divisions: step == null || step <= 0
                  ? null
                  : ((max - min) / step).round(),
              value: cur,
              label: cur.toStringAsFixed(step != null && step >= 1 ? 0 : 1),
              onChanged: enabled ? (d) => controller.setValue(s, c, d) : null,
            );
          },
        ),
      ),
      'text_input' => TextFormField(
        key: Key('nexa_input_${c.id}'),
        enabled: enabled,
        initialValue: v as String?,
        maxLength: c.data['max_length'] as int?,
        decoration: InputDecoration(
          labelText: c.title ?? label,
          hintText: c.data['hint'] as String?,
        ),
        onChanged: (t) => controller.setValue(s, c, t),
      ),
      'filter_chips' => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final ch in c.choices)
            FilterChip(
              key: Key('nexa_chip_${c.id}_${ch.id}'),
              label: Text(ch.label),
              selected: v is Set<String> && v.contains(ch.id),
              onSelected: enabled && !ch.disabled
                  ? (on) {
                      final set = {if (v is Set<String>) ...v};
                      on ? set.add(ch.id) : set.remove(ch.id);
                      pick(set.toList());
                    }
                  : null,
            ),
        ],
      ),
      'news_list' => Column(
        children: [
          for (final it in c.items('items'))
            _LinkTile(
              key: Key('nexa_news_${it['id']}'),
              title: '${it['headline'] ?? ''}',
              subtitle: [
                if (it['publisher'] != null) '${it['publisher']}',
                if (it['published_at'] != null)
                  _shortTime(context, '${it['published_at']}'),
              ].join(' · '),
              body: it['excerpt'] as String?,
              imageUrl: it['thumbnail_url'] as String?,
              url: it['url'] as String?,
              controller: controller,
              s: s,
            ),
        ],
      ),
      'score_cards' => Column(
        children: [
          for (final it in c.items('items'))
            _ScoreCard(key: Key('nexa_score_${it['id']}'), data: it),
        ],
      ),
      'search_results' => Column(
        children: [
          for (final it in c.items('items'))
            Builder(
              builder: (context) {
                final id = '${it['id']}';
                final sel = v is Set<String> && v.contains(id);
                return _LinkTile(
                  key: Key('nexa_result_$id'),
                  title: '${it['title'] ?? ''}',
                  subtitle: [
                    if (it['domain'] != null) '${it['domain']}',
                    if (it['date'] != null)
                      _shortTime(context, '${it['date']}'),
                  ].join(' · '),
                  body: it['excerpt'] as String?,
                  url: it['url'] as String?,
                  controller: controller,
                  s: s,
                  leading: Checkbox(
                    value: sel,
                    onChanged: enabled
                        ? (on) {
                            final set = {if (v is Set<String>) ...v};
                            on ?? false ? set.add(id) : set.remove(id);
                            pick(set.toList());
                          }
                        : null,
                  ),
                );
              },
            ),
        ],
      ),
      'comparison' => _Comparison(data: c.data),
      'summary' => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NexaRichText('${c.data['text'] ?? ''}'),
          for (final (i, cit) in c.items('citations').indexed)
            _LinkTile(
              title: '[${cit['n'] ?? i + 1}] ${cit['title'] ?? ''}',
              url: cit['url'] as String?,
              controller: controller,
              s: s,
            ),
        ],
      ),
      'place_list' => _PlaceList(
        c: c,
        selectedId: v as String?,
        enabled: enabled,
        onPick: (id) => pick([id]),
        controller: controller,
        position: pos,
      ),
      'map_preview' => _MapPreview(pins: c.data['pins'] as List? ?? const []),
      'image_grid' || 'image' => _ImageGrid(
        items: c.type == 'image' ? [c.data] : c.items('items'),
        actions: controller.deviceActions,
      ),
      'file_preview' => _FilePreview(data: c.data),
      'action_list' => Column(
        children: [
          for (final it in c.items('items'))
            ListTile(
              key: Key('nexa_device_action_${it['id']}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone_rounded),
              title: Text('${it['label'] ?? it['tool_id']}'),
              subtitle: it['state'] == null ? null : Text('${it['state']}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              enabled:
                  enabled &&
                  controller.deviceActions != null &&
                  it['tool_id'] is String,
              onTap: () => controller.deviceActions!.runTool(
                context,
                it['tool_id']! as String,
                (it['arguments'] as Map?)?.cast<String, Object?>() ?? const {},
              ),
            ),
        ],
      ),
      'steps' => Column(
        children: [
          for (final it in c.items('items'))
            _Step(key: Key('nexa_step_${it['id']}'), data: it),
        ],
      ),
      'progress' => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            key: Key('nexa_progress_${c.id}'),
            value: (c.data['value'] as num?)?.toDouble(),
          ),
          if (c.data['label'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${c.data['label']}',
                style: theme.textTheme.labelSmall,
              ),
            ),
        ],
      ),
      'banner' => _Banner(
        kind: '${c.data['kind'] ?? 'info'}',
        text: '${c.data['text'] ?? ''}',
      ),
      'key_value' => NexaToolCardRows(
        rows: [for (final r in c.items('rows')) ('${r['k']}', '${r['v']}')],
      ),
      'attribution' => _Attribution(
        source: '${c.data['source'] ?? ''}',
        at: DateTime.tryParse('${c.data['retrieved_at']}'),
      ),
      _ => _Fallback(
        key: Key('nexa_component_fallback_${c.id}'),
        text: c.fallbackText ?? c.title ?? '',
      ),
    };
    return Semantics(label: label, child: widget);
  }

  static String _shortTime(BuildContext context, String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return iso;
    final m = MaterialLocalizations.of(context);
    return '${m.formatShortDate(t.toLocal())} '
        '${m.formatTimeOfDay(TimeOfDay.fromDateTime(t.toLocal()))}';
  }
}

/// Key/value rows in the tool-card style.
class NexaToolCardRows extends StatelessWidget {
  const NexaToolCardRows({required this.rows, super.key});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (final (k, v) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      k,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(child: Text(v, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PaletteGrid extends StatelessWidget {
  const _PaletteGrid({
    required this.c,
    required this.selectedId,
    required this.appliedId,
    required this.enabled,
    required this.onPick,
    required this.position,
  });

  final NexaComponent c;
  final String? selectedId;
  final String? appliedId;
  final bool enabled;
  final ValueChanged<String> onPick;
  final String Function(NexaChoice, bool) position;

  static Color? _hex(Object? v) {
    if (v is! String || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(v)) return null;
    return Color(int.parse('FF${v.substring(1)}', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 520 ? 3 : 2;
        final w = (box.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final ch in c.choices)
              Builder(
                builder: (context) {
                  final sel = ch.id == selectedId;
                  final applied = ch.id == appliedId;
                  final swatches = [
                    for (final h in (ch.data['swatches'] as List?) ?? const [])
                      ?_hex(h),
                  ];
                  return Semantics(
                    label: position(ch, sel),
                    selected: sel,
                    button: true,
                    excludeSemantics: true,
                    child: InkWell(
                      key: Key('nexa_palette_${ch.id}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: enabled ? () => onPick(ch.id) : null,
                      child: Container(
                        width: w,
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: sel ? scheme.primary : scheme.outlineVariant,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // The palette's own colors, only inside the swatch.
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                height: 36,
                                child: Row(
                                  // Stretch: a childless ColoredBox is
                                  // otherwise 0 px tall.
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final col in swatches)
                                      Expanded(child: ColoredBox(color: col)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    ch.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelLarge,
                                  ),
                                ),
                                if (sel)
                                  Icon(
                                    Icons.check_circle,
                                    size: 18,
                                    color: scheme.primary,
                                  ),
                              ],
                            ),
                            if (sel || applied)
                              Text(
                                sel && !applied
                                    ? l10n.duiPreviewing
                                    : l10n.duiApplied,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.controller,
    required this.s,
    this.subtitle,
    this.body,
    this.url,
    this.imageUrl,
    this.leading,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? body;
  final String? url;
  final String? imageUrl;
  final Widget? leading;
  final NexaSurfaceController controller;
  final NexaSurface s;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safe = url == null ? null : validateBrowserUrl(url!);
    final img = imageUrl == null ? null : validateBrowserUrl(imageUrl!);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading:
          leading ??
          (img == null
              ? null
              : ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    img.toString(),
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.image_not_supported_outlined),
                  ),
                )),
      title: Text(
        title,
        textDirection: nexaTextDirectionOf(title),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle == null && body == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: theme.textTheme.labelSmall),
                if (body != null)
                  Text(
                    body!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textDirection: nexaTextDirectionOf(body!),
                  ),
              ],
            ),
      // Links open only after a tap, through the browser tool (validated).
      onTap: safe == null || controller.deviceActions == null
          ? null
          : () => controller.deviceActions!.runTool(
              context,
              BrowserOpenTool.id,
              {'url': safe.toString()},
            ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.data, super.key});
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = NexaColors.of(context);
    final home = (data['home'] as Map?) ?? const {};
    final away = (data['away'] as Map?) ?? const {};
    final status = '${data['status'] ?? ''}';
    final (label, color) = switch (status) {
      'live' => (
        '${l10n.duiLive}${data['minute'] == null ? '' : ' · ${data['minute']}′'}',
        theme.colorScheme.error,
      ),
      'upcoming' => (l10n.duiUpcoming, colors.info),
      _ => (l10n.duiFinished, theme.colorScheme.onSurfaceVariant),
    };
    Widget team(Map<dynamic, dynamic> t) => Row(
      children: [
        Expanded(child: Text('${t['name'] ?? ''}')),
        Text(
          t['score'] == null ? '–' : '${t['score']}',
          style: theme.textTheme.titleMedium,
        ),
      ],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${data['competition'] ?? ''}',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            team(home),
            team(away),
          ],
        ),
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.data});
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cols = [for (final h in (data['columns'] as List?) ?? const []) '$h'];
    final rows = [
      for (final r in (data['rows'] as List?) ?? const [])
        if (r is Map) r,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        columns: [
          const DataColumn(label: SizedBox.shrink()),
          for (final c in cols)
            DataColumn(label: Text(c, style: theme.textTheme.labelLarge)),
        ],
        rows: [
          for (final r in rows)
            DataRow(
              cells: [
                DataCell(Text('${r['label'] ?? ''}')),
                for (var i = 0; i < cols.length; i++)
                  DataCell(
                    Text(
                      i < ((r['values'] as List?)?.length ?? 0)
                          ? '${(r['values']! as List)[i]}'
                          : '',
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PlaceList extends StatelessWidget {
  const _PlaceList({
    required this.c,
    required this.selectedId,
    required this.enabled,
    required this.onPick,
    required this.controller,
    required this.position,
  });

  final NexaComponent c;
  final String? selectedId;
  final bool enabled;
  final ValueChanged<String> onPick;
  final NexaSurfaceController controller;
  final String Function(NexaChoice, bool) position;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: [
        for (final ch in c.choices)
          Builder(
            builder: (context) {
              final sel = ch.id == selectedId;
              final d = (ch.data['distance_m'] as num?)?.toDouble();
              final loc = ch.data['location'];
              NexaPlace? place;
              if (loc is Map && loc['lat'] is num && loc['lng'] is num) {
                place = NexaPlace(
                  placeId: '${ch.data['place_id'] ?? ch.id}',
                  name: ch.label,
                  latitude: (loc['lat']! as num).toDouble(),
                  longitude: (loc['lng']! as num).toDouble(),
                );
              }
              final meta = [
                if (ch.data['rating'] != null) '★ ${ch.data['rating']}',
                if (d != null)
                  d < 1000
                      ? l10n.placesDistanceM(d.round())
                      : l10n.placesDistanceKm((d / 1000).toStringAsFixed(1)),
                if (ch.data['address'] != null) '${ch.data['address']}',
              ].join(' · ');
              return Semantics(
                label: position(ch, sel),
                selected: sel,
                child: ListTile(
                  key: Key('nexa_place_choice_${ch.id}'),
                  contentPadding: EdgeInsets.zero,
                  selected: sel,
                  enabled: enabled,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: sel
                        ? scheme.primary
                        : scheme.primaryContainer,
                    child: Text(
                      '${ch.order}',
                      style: TextStyle(
                        color: sel
                            ? scheme.onPrimary
                            : scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  title: Text(ch.label),
                  subtitle: meta.isEmpty ? null : Text(meta),
                  onTap: () => onPick(ch.id),
                  trailing:
                      place == null ||
                          controller.deviceActions == null ||
                          !controller.deviceActions!.canOpenDirections
                      ? null
                      : IconButton(
                          tooltip: l10n.placesDirections,
                          icon: const Icon(Icons.directions_rounded),
                          onPressed: () => controller.deviceActions!
                              .openDirections(context, place!),
                        ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.pins});
  final List<Object?> pins;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    // A map provider tile needs a provider integration; until then this is
    // an honest numbered pin strip, not a fake map.
    return Container(
      key: const Key('nexa_map_preview'),
      height: 96,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 10,
            child: Text(
              l10n.duiMapPreview,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          Center(
            child: Wrap(
              spacing: 18,
              children: [
                for (var i = 0; i < pins.length; i++)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on, color: scheme.primary),
                      Text('${i + 1}'),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  const _ImageGrid({required this.items, required this.actions});
  final List<Map<String, Object?>> items;
  final NexaDeviceActions? actions;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final it in items)
          Builder(
            builder: (context) {
              final url = validateBrowserUrl('${it['url'] ?? ''}');
              final generated = it['generated'] == true;
              final att = NexaAttachment(
                id: '${it['id'] ?? it['url']}',
                kind: NexaAttachmentKind.image,
                origin: generated
                    ? NexaAttachmentOrigin.generated
                    : NexaAttachmentOrigin.uploaded,
                mimeType: 'image/*',
                createdAt: DateTime.now(),
                remoteUrl: url,
              );
              return GestureDetector(
                onTap: url == null
                    ? null
                    : () => openNexaImage(context, att, actions),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 140,
                        height: 100,
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: url == null
                            ? const Icon(Icons.image_outlined)
                            : Image.network(
                                url.toString(),
                                fit: BoxFit.cover,
                                semanticLabel: it['alt'] as String?,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.image_not_supported_outlined,
                                ),
                              ),
                      ),
                    ),
                    if (generated)
                      PositionedDirectional(
                        top: 6,
                        start: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.inverseSurface,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.imageGenerated,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onInverseSurface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _FilePreview extends StatelessWidget {
  const _FilePreview({required this.data});
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final theme = Theme.of(context);
    final pages = data['pages'] as int?;
    return Container(
      key: const Key('nexa_file_preview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${data['name'] ?? ''}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (pages != null)
                Text(l10n.duiPages(pages), style: theme.textTheme.labelSmall),
            ],
          ),
          for (final i in (data['insights'] as List?) ?? const [])
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('• $i', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.data, super.key});
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    final (icon, color, label) = switch (data['state']) {
      'done' => (Icons.check_circle, colors.success, l10n.duiStepDone),
      'running' => (Icons.autorenew_rounded, colors.info, l10n.duiStepRunning),
      'failed' => (Icons.error, scheme.error, l10n.duiStepFailed),
      'cancelled' => (
        Icons.cancel_outlined,
        scheme.onSurfaceVariant,
        l10n.duiStepCancelled,
      ),
      _ => (
        Icons.radio_button_unchecked,
        scheme.onSurfaceVariant,
        l10n.duiStepWaiting,
      ),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: color),
      title: Text('${data['label'] ?? ''}'),
      trailing: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
