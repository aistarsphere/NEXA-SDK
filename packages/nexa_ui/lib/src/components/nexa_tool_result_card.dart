import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_ui/l10n/generated/nexa_localizations.dart';
import 'package:nexa_ui/src/theme/nexa_colors.dart';
import 'package:nexa_ui/src/theme/nexa_shapes.dart';

/// Callback carrying an authorised user action back to the SDK.
typedef NexaToolActionCallback = void Function(ToolAction action);

/// Renders a validated [ToolResult]. The SDK guarantees the result passed
/// through `ToolResultValidator`; this widget never parses raw JSON.
///
/// Interactive variants (form, selection, confirmation, card actions, error
/// retry) call [onAction]. Once [resolved] is true the controls are disabled
/// so the user cannot submit twice.
class NexaToolResultCard extends StatelessWidget {
  const NexaToolResultCard({
    required this.toolCallId,
    required this.result,
    required this.onAction,
    this.resolved = false,
    super.key,
  });

  final ToolCallId toolCallId;
  final ToolResult result;
  final NexaToolActionCallback onAction;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final child = switch (result) {
      TextToolResult(:final text) => _TextBody(text),
      RichCardToolResult(:final card) => _RichCardBody(
        card: card,
        enabled: !resolved,
        onTap: (id) => onAction(
          ToolAction.cardActionTapped(toolCallId: toolCallId, actionId: id),
        ),
      ),
      RestaurantsToolResult(:final items) => _RestaurantsBody(items),
      MapRouteToolResult(:final route) => _RouteBody(route),
      WeatherToolResult(:final weather) => _WeatherBody(weather),
      MediaToolResult(:final items) => _MediaBody(items),
      FormToolResult(:final form) => _FormBody(
        form: form,
        enabled: !resolved,
        onSubmit: (values) => onAction(
          ToolAction.formSubmitted(
            toolCallId: toolCallId,
            formId: form.id,
            values: values,
          ),
        ),
      ),
      SelectionToolResult(:final selection) => _SelectionBody(
        selection: selection,
        enabled: !resolved,
        onSubmit: (ids) => onAction(
          ToolAction.optionSelected(
            toolCallId: toolCallId,
            selectionId: selection.id,
            optionIds: ids,
          ),
        ),
      ),
      ConfirmationToolResult(:final confirmation) => NexaConfirmationCard(
        confirmation: confirmation,
        enabled: !resolved,
        onConfirm: () => onAction(
          ToolAction.confirmed(
            toolCallId: toolCallId,
            confirmationId: confirmation.id,
          ),
        ),
        onDecline: () => onAction(
          ToolAction.declined(
            toolCallId: toolCallId,
            confirmationId: confirmation.id,
          ),
        ),
      ),
      ErrorToolResult(:final error) => _ErrorBody(
        error: error,
        onRetry: error.retryable && !resolved
            ? () => onAction(ToolAction.retryRequested(toolCallId: toolCallId))
            : null,
      ),
    };
    return Card(
      key: Key('nexa_tool_result_${toolCallId.value}'),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _TextBody extends StatelessWidget {
  const _TextBody(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: Theme.of(context).textTheme.bodyLarge);
}

class _RichCardBody extends StatelessWidget {
  const _RichCardBody({
    required this.card,
    required this.enabled,
    required this.onTap,
  });
  final RichCard card;
  final bool enabled;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(card.title, style: text.titleMedium),
        if (card.subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              card.subtitle!,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (card.body != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(card.body!, style: text.bodyMedium),
          ),
        if (card.actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in card.actions)
                  a.primary
                      ? FilledButton(
                          onPressed: enabled ? () => onTap(a.id) : null,
                          child: Text(a.label),
                        )
                      : OutlinedButton(
                          onPressed: enabled ? () => onTap(a.id) : null,
                          child: Text(a.label),
                        ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RestaurantsBody extends StatelessWidget {
  const _RestaurantsBody(this.items);
  final List<RestaurantResult> items;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, r) in items.indexed) ...[
          if (i > 0) const Divider(height: 16),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: const Icon(Icons.restaurant_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.name, style: text.titleSmall),
                    Text(
                      [
                        if (r.cuisine != null) r.cuisine!,
                        if (r.priceTier != null) '\$' * r.priceTier!,
                        if (r.distanceMeters != null)
                          _distance(l10n, r.distanceMeters!),
                      ].join(' · '),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (r.rating != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: colors.warning,
                        ),
                        Text(
                          r.rating!.toStringAsFixed(1),
                          style: text.labelLarge,
                        ),
                      ],
                    ),
                  Text(
                    r.openNow ? l10n.openNow : l10n.closed,
                    style: text.labelSmall?.copyWith(
                      color: r.openNow
                          ? colors.success
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

String _distance(NexaLocalizations l10n, double meters) => meters >= 1000
    ? l10n.distanceKm((meters / 1000).toStringAsFixed(1))
    : l10n.distanceM(meters.round());

class _RouteBody extends StatelessWidget {
  const _RouteBody(this.route);
  final MapRoute route;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map tiles are intentionally not rendered in this phase: no map
        // provider has been approved. A static summary keeps the contract
        // honest; a map widget can replace this container later.
        Container(
          height: 96,
          width: double.infinity,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: NexaShapes.card,
          ),
          child: Icon(
            Icons.map_outlined,
            size: 40,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _RoutePoint(
          icon: Icons.trip_origin,
          label: route.originLabel ?? _fmt(route.origin),
        ),
        _RoutePoint(
          icon: Icons.place_outlined,
          label: route.destinationLabel ?? _fmt(route.destination),
        ),
        if (route.distanceMeters != null && route.duration != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.routeSummary(
                _distance(l10n, route.distanceMeters!),
                route.duration!.inMinutes,
              ),
              style: text.labelLarge,
            ),
          ),
      ],
    );
  }

  static String _fmt(GeoPoint p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';
}

class _RoutePoint extends StatelessWidget {
  const _RoutePoint({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody(this.weather);
  final WeatherData weather;

  static IconData _icon(String? key) => switch (key) {
    'clear' => Icons.wb_sunny_outlined,
    'cloudy' => Icons.cloud_outlined,
    'rain' => Icons.umbrella_outlined,
    'storm' => Icons.thunderstorm_outlined,
    'snow' => Icons.ac_unit,
    _ => Icons.thermostat_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(_icon(weather.iconKey), size: 40, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(weather.locationName, style: text.titleMedium),
                  Text(
                    weather.condition,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Text('${weather.temperatureC.round()}°', style: text.displaySmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            if (weather.feelsLikeC != null)
              Text(
                l10n.weatherFeelsLike(weather.feelsLikeC!.round()),
                style: text.bodySmall,
              ),
            if (weather.humidityPercent != null)
              Text(
                l10n.weatherHumidity(weather.humidityPercent!.round()),
                style: text.bodySmall,
              ),
            if (weather.windKph != null)
              Text(
                l10n.weatherWind(weather.windKph!.round()),
                style: text.bodySmall,
              ),
          ],
        ),
        if (weather.forecast.isNotEmpty) ...[
          const Divider(height: 20),
          Row(
            children: [
              for (final d in weather.forecast.take(5))
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        DateFormat.E(
                          Localizations.localeOf(context).toString(),
                        ).format(d.date),
                        style: text.labelSmall,
                      ),
                      Icon(_icon(d.iconKey), size: 20),
                      Text(
                        '${d.highC.round()}° / ${d.lowC.round()}°',
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _MediaBody extends StatelessWidget {
  const _MediaBody(this.items);
  final List<MediaItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final m in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(NexaShapes.medium),
              ),
              child: Icon(switch (m.kind) {
                MediaKind.video => Icons.play_circle_outline,
                MediaKind.audio => Icons.audiotrack_outlined,
                MediaKind.image => Icons.image_outlined,
              }, color: scheme.onSurfaceVariant),
            ),
            title: Text(m.title ?? m.uri.host, style: text.titleSmall),
            subtitle: m.duration != null
                ? Text(_mmss(m.duration!), style: text.bodySmall)
                : null,
            // Playback is deferred: no media player dependency is approved yet.
            trailing: Tooltip(
              message: l10n.mediaPlay,
              child: Icon(Icons.open_in_new, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  static String _mmss(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _FormBody extends StatefulWidget {
  const _FormBody({
    required this.form,
    required this.enabled,
    required this.onSubmit,
  });
  final FormSpec form;
  final bool enabled;
  final ValueChanged<Map<String, Object?>> onSubmit;
  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  final _key = GlobalKey<FormState>();
  final Map<String, Object?> _values = {};

  @override
  void initState() {
    super.initState();
    for (final f in widget.form.fields) {
      _values[f.id] =
          f.defaultValue ?? (f.type == FormFieldType.toggle ? false : null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.form.title, style: text.titleMedium),
          if (widget.form.description != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(widget.form.description!, style: text.bodyMedium),
            ),
          const SizedBox(height: 12),
          for (final f in widget.form.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _field(context, f, l10n),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: Key('nexa_form_submit_${widget.form.id}'),
              onPressed: widget.enabled
                  ? () {
                      if (_key.currentState?.validate() ?? false) {
                        _key.currentState?.save();
                        widget.onSubmit(Map.of(_values));
                      }
                    }
                  : null,
              child: Text(widget.form.submitLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(BuildContext context, FormFieldSpec f, NexaLocalizations l10n) {
    switch (f.type) {
      case FormFieldType.toggle:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(f.label),
          subtitle: f.helperText != null ? Text(f.helperText!) : null,
          value: _values[f.id] == true,
          onChanged: widget.enabled
              ? (v) => setState(() => _values[f.id] = v)
              : null,
        );
      case FormFieldType.select:
        return DropdownButtonFormField<String>(
          initialValue: _values[f.id] as String?,
          decoration: InputDecoration(
            labelText: f.label,
            helperText: f.helperText,
          ),
          items: [
            for (final o in f.options)
              DropdownMenuItem(value: o.id, child: Text(o.label)),
          ],
          validator: (v) => f.required && v == null ? l10n.requiredField : null,
          onChanged: widget.enabled ? (v) => _values[f.id] = v : null,
          onSaved: (v) => _values[f.id] = v,
        );
      case FormFieldType.text:
      case FormFieldType.number:
      case FormFieldType.email:
      case FormFieldType.phone:
      case FormFieldType.date:
        return TextFormField(
          key: Key('nexa_form_field_${f.id}'),
          enabled: widget.enabled,
          initialValue: _values[f.id]?.toString(),
          decoration: InputDecoration(
            labelText: f.label,
            hintText: f.placeholder,
            helperText: f.helperText,
          ),
          keyboardType: switch (f.type) {
            FormFieldType.number => TextInputType.number,
            FormFieldType.email => TextInputType.emailAddress,
            FormFieldType.phone => TextInputType.phone,
            FormFieldType.date => TextInputType.datetime,
            _ => TextInputType.text,
          },
          validator: (v) => f.required && (v == null || v.trim().isEmpty)
              ? l10n.requiredField
              : null,
          onSaved: (v) => _values[f.id] = v?.trim(),
        );
    }
  }
}

class _SelectionBody extends StatefulWidget {
  const _SelectionBody({
    required this.selection,
    required this.enabled,
    required this.onSubmit,
  });
  final SelectionSpec selection;
  final bool enabled;
  final ValueChanged<List<String>> onSubmit;
  @override
  State<_SelectionBody> createState() => _SelectionBodyState();
}

class _SelectionBodyState extends State<_SelectionBody> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final s = widget.selection;
    final max = s.maxSelections ?? (s.multiSelect ? s.options.length : 1);
    final canSubmit =
        widget.enabled &&
        _selected.length >= s.minSelections &&
        _selected.length <= max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(s.prompt, style: text.titleMedium),
        Text(
          s.multiSelect ? l10n.selectMany : l10n.selectOne,
          style: text.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in s.options)
              FilterChip(
                key: Key('nexa_option_${o.id}'),
                label: Text(o.label),
                selected: _selected.contains(o.id),
                onSelected: widget.enabled
                    ? (v) => setState(() {
                        if (!s.multiSelect) _selected.clear();
                        if (v) {
                          if (_selected.length < max) _selected.add(o.id);
                        } else {
                          _selected.remove(o.id);
                        }
                      })
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton(
            key: Key('nexa_selection_submit_${s.id}'),
            onPressed: canSubmit
                ? () => widget.onSubmit(_selected.toList())
                : null,
            child: Text(l10n.submit),
          ),
        ),
      ],
    );
  }
}

/// Explicit confirmation card. Public so the SDK can also render it for
/// `userConfirmationRequested` events before any result exists.
class NexaConfirmationCard extends StatelessWidget {
  const NexaConfirmationCard({
    required this.confirmation,
    required this.onConfirm,
    required this.onDecline,
    this.enabled = true,
    super.key,
  });

  final ConfirmationSpec confirmation;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final colors = NexaColors.of(context);
    final accent = switch (confirmation.severity) {
      ConfirmationSeverity.low => scheme.primary,
      ConfirmationSeverity.medium => colors.warning,
      ConfirmationSeverity.high => scheme.error,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.shield_outlined, color: accent),
            const SizedBox(width: 8),
            Expanded(child: Text(confirmation.title, style: text.titleMedium)),
          ],
        ),
        const SizedBox(height: 8),
        Text(confirmation.description, style: text.bodyMedium),
        if (confirmation.details.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final d in confirmation.details)
                  Text('• $d', style: text.bodySmall),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              key: Key('nexa_decline_${confirmation.id}'),
              onPressed: enabled ? onDecline : null,
              child: Text(confirmation.declineLabel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: Key('nexa_confirm_${confirmation.id}'),
              onPressed: enabled ? onConfirm : null,
              style: confirmation.severity == ConfirmationSeverity.high
                  ? FilledButton.styleFrom(
                      backgroundColor: scheme.error,
                      foregroundColor: scheme.onError,
                    )
                  : null,
              child: Text(confirmation.confirmLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error, this.onRetry});
  final ToolError error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = NexaLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final friendly = error.code == 'invalid_tool_result'
        ? l10n.invalidResult
        : l10n.toolFailed;
    return Row(
      children: [
        Icon(Icons.error_outline, color: scheme.error),
        const SizedBox(width: 12),
        Expanded(child: Text(friendly, style: text.bodyMedium)),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
