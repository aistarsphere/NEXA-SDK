import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_host_capabilities.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_tool_calls.dart';
import 'package:nexa_ui/nexa_ui.dart';

/// Opens an https URL outside the app (after the user's consent).
typedef NexaExternalOpener = Future<bool> Function(Uri url);

/// Renders a `nexa.ui/1` document with the host's ThemeData (styles from
/// the document are never applied). Unknown component types were already
/// dropped by the parser. Every interaction becomes a `ui_event` the
/// gateway validates against the document it sent.
class NexaUiView extends StatefulWidget {
  const NexaUiView({
    required this.uiId,
    required this.controller,
    this.openExternal,
    this.onDismiss,
    this.compact = false,
    super.key,
  });

  final String uiId;
  final LabeebToolCallController controller;
  final NexaExternalOpener? openExternal;
  final VoidCallback? onDismiss;

  /// Voice companion: tighter spacing.
  final bool compact;

  @override
  State<NexaUiView> createState() => _NexaUiViewState();
}

class _NexaUiViewState extends State<NexaUiView> {
  /// Component currently sending an event.
  String? _sending;

  /// Gateway refusal of the last event (e.g. `unknown_ui_component`).
  String? _refused;

  /// Sends the failed event again (a delivery failure, not a stale one).
  Future<void> Function()? _retry;

  LabeebToolCallController get _c => widget.controller;

  /// Returns the gateway refusal code of a `ui_event`, else null.
  Future<String?> _send(
    NexaUiDocument doc,
    NexaUiNode node,
    NexaUiAction? action, {
    required String defaultEvent,
    List<String>? optionIds,
    Object? value,
  }) async {
    if (action == null) return null;
    switch (action.type) {
      case 'dismiss':
        widget.onDismiss?.call();
        return null;
      case 'open_url':
        final url = action.url ?? _https(node.props['url']);
        if (url != null) await _open(url);
        return null;
      case 'send_ui_event' || 'client_tool':
        // An expired document sends nothing (it is greyed out).
        if (_c.isUiExpired(doc.id)) return null;
        // A client_tool action is a request to the assistant, which then
        // issues the tool call; nothing runs from the document itself.
        setState(() {
          _sending = node.id;
          _refused = null;
        });
        final code = await _c.sendUiEvent(
          NexaUiEvent(
            uiId: doc.id,
            componentId: node.id,
            event: action.event ?? defaultEvent,
            optionIds: optionIds,
            value: value,
          ),
        );
        final stale =
            code == 'unknown_ui_component' || code == 'unknown_ui_option';
        if (stale) _c.markUiExpired(doc.id);
        if (mounted) {
          setState(() {
            _sending = null;
            // An ignored second tap is not a refusal.
            if (code != LabeebToolCallController.uiEventInFlight) {
              _refused = code;
              _retry = code == null || stale
                  ? null
                  : () => _send(
                      doc,
                      node,
                      action,
                      defaultEvent: defaultEvent,
                      optionIds: optionIds,
                      value: value,
                    );
            }
          });
        }
        return code;
    }
    return null;
  }

  String? _https(Object? v) => v is String && isHttpsUrl(v) ? v : null;

  Future<void> _open(String url) async {
    final opener = widget.openExternal;
    if (opener == null) return;
    final l10n = NexaLocalizations.of(context);
    final uri = Uri.parse(url);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => nexaScoped(
        context,
        AlertDialog(
          key: const Key('nexa_ui_open_url_confirm'),
          title: Text(l10n.duiOpenLinkTitle),
          content: Text(uri.host),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              key: const Key('nexa_ui_open_url_ok'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.duiOpen),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) await opener(uri);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final doc = _c.document(widget.uiId);
        if (doc == null) return const SizedBox.shrink();
        final l10n = NexaLocalizations.of(context);
        final theme = Theme.of(context);
        final lang = Localizations.localeOf(context).languageCode;
        final title = doc.titleFor(lang);
        final root = doc.root;
        final expired = _c.isUiExpired(doc.id);
        return Column(
          key: Key('nexa_ui_${doc.id}'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (root == null && doc.truncated)
              Row(
                key: const Key('nexa_ui_loading'),
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Text(l10n.duiLoading),
                ],
              )
            else if (root == null)
              // Nothing could be drawn (unknown root): the assistant's own
              // words when it gave some, else an honest notice.
              Text(
                doc.fallbackFor(lang) ?? l10n.duiUnsupported,
                key: doc.fallbackFor(lang) == null
                    ? const Key('nexa_ui_unsupported')
                    : const Key('nexa_ui_fallback'),
                style: theme.textTheme.bodyMedium,
              )
            else if (expired)
              Opacity(
                key: const Key('nexa_ui_expired'),
                opacity: 0.5,
                child: IgnorePointer(child: _node(context, doc, root, lang)),
              )
            else
              _node(context, doc, root, lang),
            if (_refused != null || expired)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        expired ? l10n.duiStale : l10n.duiNotDelivered,
                        key: _refused != null
                            ? const Key('nexa_ui_refused')
                            : const Key('nexa_ui_expired_label'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                    if (!expired && _retry != null)
                      TextButton(
                        key: const Key('nexa_ui_retry'),
                        onPressed: () => unawaited(_retry!()),
                        child: Text(l10n.retry),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _gap() => SizedBox(height: widget.compact ? 6 : 10);

  Widget _node(
    BuildContext context,
    NexaUiDocument doc,
    NexaUiNode n,
    String lang,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = NexaLocalizations.of(context);
    final busy = _sending == n.id || _c.isUiEventInFlight(doc.id, n.id);
    List<Widget> kids(List<NexaUiNode> list) => [
      for (final k in list) _node(context, doc, k, lang),
    ];
    String? t(String key) => n.text(key, lang);
    final key = Key('nexa_ui_node_${n.id}');

    switch (n.type) {
      case 'text':
        final style = switch (n.props['variant']) {
          'title' => theme.textTheme.titleSmall,
          'caption' => theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          _ => theme.textTheme.bodyMedium,
        };
        return Text(t('text') ?? t('label') ?? '', key: key, style: style);
      case 'icon':
        return Icon(
          _icon(n.props['name']),
          key: key,
          color: scheme.primary,
          semanticLabel: t('label'),
        );
      case 'image':
        return _UiImage(
          key: key,
          assetId: n.props['asset_id'] as String?,
          url: _https(n.props['url']),
          alt: t('alt') ?? t('label'),
          bytes: _c.assetBytes,
        );
      case 'button':
        final action = n.actions['action'] ?? n.actions['on_tap'];
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonal(
            key: key,
            onPressed: action == null || busy
                ? null
                : () => _send(doc, n, action, defaultEvent: 'submit'),
            child: busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t('label') ?? ''),
          ),
        );
      case 'choice' || 'palette':
        return _choices(context, doc, n, lang, busy, key);
      case 'switch':
        final v = _c.uiValue(doc.id, n.id) as bool? ?? n.props['value'] == true;
        return SwitchListTile(
          key: key,
          contentPadding: EdgeInsets.zero,
          title: Text(t('label') ?? ''),
          value: v,
          onChanged: busy
              ? null
              : (nv) {
                  _c.setUiValue(doc.id, n.id, nv);
                  unawaited(
                    _send(
                      doc,
                      n,
                      n.actions['on_change'],
                      defaultEvent: 'change',
                      value: nv,
                    ),
                  );
                },
        );
      case 'slider':
        final min = (n.props['min'] as num?)?.toDouble() ?? 0;
        final max = (n.props['max'] as num?)?.toDouble() ?? 1;
        final step = (n.props['step'] as num?)?.toDouble();
        final v =
            ((_c.uiValue(doc.id, n.id) ?? n.props['value']) as num?)
                ?.toDouble() ??
            min;
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t('label') != null) Text(t('label')!),
            Slider(
              min: min,
              max: max <= min ? min + 1 : max,
              divisions: step != null && step > 0
                  ? ((max - min) / step).round().clamp(1, 1000)
                  : null,
              value: v.clamp(min, max <= min ? min + 1 : max),
              label: v.toStringAsFixed(step != null && step < 1 ? 1 : 0),
              onChanged: (nv) => _c.setUiValue(doc.id, n.id, nv),
              onChangeEnd: (nv) => _send(
                doc,
                n,
                n.actions['on_change'],
                defaultEvent: 'change',
                value: nv,
              ),
            ),
          ],
        );
      case 'input':
        return _UiInput(
          key: key,
          label: t('label'),
          hint: t('placeholder') ?? t('hint'),
          initial: n.props['value'] as String?,
          maxLength: n.props['max_length'] as int?,
          busy: busy,
          submitLabel: l10n.duiSend,
          onSubmit: (v) => _send(
            doc,
            n,
            n.actions['on_submit'],
            defaultEvent: 'submit',
            value: v,
          ),
        );
      case 'list':
        final items = kids(n.items.isEmpty ? n.children : n.items);
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, w) in items.indexed) ...[
              if (i > 0) Divider(height: widget.compact ? 12 : 20),
              w,
            ],
          ],
        );
      case 'grid':
        final items = kids(n.items.isEmpty ? n.children : n.items);
        return LayoutBuilder(
          key: key,
          builder: (context, box) {
            final cols = box.maxWidth >= 520 ? 3 : 2;
            final w = (box.maxWidth - (cols - 1) * 8) / cols;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in items) SizedBox(width: w, child: c)],
            );
          },
        );
      case 'card':
        final tap = n.actions['on_tap'] ?? n.actions['action'];
        return Material(
          key: key,
          color: scheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: tap == null
                ? null
                : () => _send(doc, n, tap, defaultEvent: 'select'),
            child: Padding(
              padding: EdgeInsets.all(widget.compact ? 10 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _spaced([
                  if (t('title') != null)
                    Text(t('title')!, style: theme.textTheme.titleSmall),
                  if (t('subtitle') != null)
                    Text(
                      t('subtitle')!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ...kids(n.children),
                ]),
              ),
            ),
          ),
        );
      case 'row':
        return Wrap(
          key: key,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: kids(n.children),
        );
      case 'column':
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _spaced(kids(n.children)),
        );
      case 'divider':
        return Divider(key: key);
      case 'progress':
        final v = (n.props['value'] as num?)?.toDouble();
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: v?.clamp(0, 1)),
            if (t('label') != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(t('label')!, style: theme.textTheme.bodySmall),
              ),
          ],
        );
      case 'confirm':
        return Column(
          key: key,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (t('title') != null)
              Text(t('title')!, style: theme.textTheme.titleSmall),
            if (t('text') != null) Text(t('text')!),
            _gap(),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  key: Key('nexa_ui_cancel_${n.id}'),
                  onPressed: busy
                      ? null
                      : () => _send(
                          doc,
                          n,
                          n.actions['on_cancel'] ??
                              const NexaUiAction(type: 'send_ui_event'),
                          defaultEvent: 'cancel',
                        ),
                  child: Text(t('cancel_label') ?? l10n.cancel),
                ),
                FilledButton(
                  key: Key('nexa_ui_confirm_${n.id}'),
                  onPressed: busy
                      ? null
                      : () => _send(
                          doc,
                          n,
                          n.actions['on_confirm'] ??
                              const NexaUiAction(type: 'send_ui_event'),
                          defaultEvent: 'confirm',
                        ),
                  child: Text(t('confirm_label') ?? l10n.duiConfirm),
                ),
              ],
            ),
          ],
        );
      case 'link':
        final url = _https(n.props['url']) ?? n.actions['action']?.url;
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: key,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            onPressed: url == null ? null : () => _open(url),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(t('label') ?? Uri.tryParse(url ?? '')?.host ?? ''),
          ),
        );
      default:
        // A host-registered extension type (kept by the parser only when a
        // renderer exists); anything else was already dropped.
        final builder = _c.host.uiComponents[n.type];
        if (builder == null) return const SizedBox.shrink();
        return KeyedSubtree(
          key: key,
          child: builder(
            context,
            NexaUiComponentContext(
              node: n,
              languageCode: lang,
              send: ({action, event, optionIds, value}) {
                final base =
                    n.actions[action ?? 'action'] ??
                    const NexaUiAction(type: 'send_ui_event');
                return _send(
                  doc,
                  n,
                  event == null
                      ? base
                      : NexaUiAction(type: base.type, event: event),
                  defaultEvent: event ?? 'submit',
                  optionIds: optionIds,
                  value: value,
                );
              },
              buildChild: (child) => _node(context, doc, child, lang),
            ),
          ),
        );
    }
  }

  List<Widget> _spaced(List<Widget> ws) => [
    for (final (i, w) in ws.indexed) ...[if (i > 0) _gap(), w],
  ];

  Widget _choices(
    BuildContext context,
    NexaUiDocument doc,
    NexaUiNode n,
    String lang,
    bool busy,
    Key key,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = NexaLocalizations.of(context);
    final multiple = n.props['multiple'] == true;
    final selected = switch (_c.uiValue(doc.id, n.id)) {
      final List<Object?> l => {...l.whereType<String>()},
      _ => <String>{},
    };
    final palette = n.type == 'palette';

    Future<void> pick(NexaUiOption o) async {
      final next = multiple
          ? (selected.contains(o.id)
                ? ({...selected}..remove(o.id))
                : {...selected, o.id})
          : {o.id};
      _c.setUiValue(doc.id, n.id, next.toList());
      await _send(
        doc,
        n,
        n.actions['on_select'] ?? const NexaUiAction(type: 'send_ui_event'),
        defaultEvent: 'select',
        optionIds: next.toList(),
      );
    }

    Widget option(NexaUiOption o) {
      final sel = selected.contains(o.id);
      final label = o.labelFor(lang);
      final swatches = [for (final hex in o.colors.values) ?_color(hex)];
      return Semantics(
        key: Key('nexa_ui_option_${n.id}_${o.id}'),
        button: true,
        selected: sel,
        label: l10n.duiPosition(o.ordinal, n.options.length, label),
        excludeSemantics: true,
        child: Material(
          color: sel ? scheme.secondaryContainer : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: sel ? scheme.primary : scheme.outlineVariant,
              width: sel ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy ? null : () => pick(o),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (palette && swatches.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 28,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final c in swatches)
                                Expanded(child: ColoredBox(color: c)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Row(
                    children: [
                      // The ordinal: "the second one" == this option.
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: Text(
                          '${o.ordinal}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(label)),
                      if (sel)
                        Icon(
                          Icons.check_circle,
                          size: 18,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      key: key,
      builder: (context, box) {
        final cols = palette ? (box.maxWidth >= 520 ? 3 : 2) : 1;
        final w = (box.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in n.options) SizedBox(width: w, child: option(o)),
          ],
        );
      },
    );
  }

  static Color? _color(String hex) =>
      Color(int.parse('FF${hex.substring(1)}', radix: 16));

  static IconData _icon(Object? name) => switch (name) {
    'place' || 'location' || 'map' => Icons.place_outlined,
    'news' || 'article' => Icons.article_outlined,
    'sports' => Icons.sports_soccer_outlined,
    'video' || 'play' => Icons.play_circle_outline,
    'image' || 'photo' => Icons.image_outlined,
    'file' || 'document' => Icons.description_outlined,
    'palette' || 'theme' => Icons.palette_outlined,
    'check' || 'done' => Icons.check_circle_outline,
    'warning' || 'error' => Icons.warning_amber_rounded,
    'search' || 'web' => Icons.travel_explore_outlined,
    'camera' => Icons.photo_camera_outlined,
    'share' => Icons.ios_share_rounded,
    'settings' => Icons.settings_outlined,
    'star' || 'rating' => Icons.star_rounded,
    'time' || 'clock' => Icons.schedule_rounded,
    _ => Icons.circle_outlined,
  };
}

class _UiImage extends StatefulWidget {
  const _UiImage({
    required this.bytes,
    this.assetId,
    this.url,
    this.alt,
    super.key,
  });

  final String? assetId;
  final String? url;
  final String? alt;
  final Future<Uint8List> Function(String) bytes;

  @override
  State<_UiImage> createState() => _UiImageState();
}

class _UiImageState extends State<_UiImage> {
  late final Future<Uint8List>? _data = widget.assetId == null
      ? null
      : widget.bytes(widget.assetId!);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget broken() => Container(
      height: 120,
      color: scheme.surfaceContainerHigh,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    );
    final Widget img;
    if (_data != null) {
      img = FutureBuilder<Uint8List>(
        future: _data,
        builder: (context, snap) => snap.hasData
            ? Image.memory(
                snap.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => broken(),
              )
            : snap.hasError
            ? broken()
            : Container(
                height: 120,
                color: scheme.surfaceContainerHigh,
                alignment: Alignment.center,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
      );
    } else if (widget.url != null) {
      img = Image.network(
        widget.url!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => broken(),
      );
    } else {
      img = broken();
    }
    return Semantics(
      image: true,
      label: widget.alt,
      child: ClipRRect(borderRadius: BorderRadius.circular(12), child: img),
    );
  }
}

class _UiInput extends StatefulWidget {
  const _UiInput({
    required this.onSubmit,
    required this.busy,
    required this.submitLabel,
    this.label,
    this.hint,
    this.initial,
    this.maxLength,
    super.key,
  });

  final String? label;
  final String? hint;
  final String? initial;
  final int? maxLength;
  final bool busy;
  final String submitLabel;
  final ValueChanged<String> onSubmit;

  @override
  State<_UiInput> createState() => _UiInputState();
}

class _UiInputState extends State<_UiInput> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            maxLength: widget.maxLength,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
            ),
            onSubmitted: widget.busy ? null : widget.onSubmit,
          ),
        ),
        IconButton(
          tooltip: widget.submitLabel,
          onPressed: widget.busy ? null : () => widget.onSubmit(_text.text),
          icon: const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}

/// Closes the overlay it sits in when a device tool call starts waiting for
/// the user's approval: that card lives in the conversation behind the sheet,
/// and the approval window is short, so it must not stay hidden.
class _CloseOnApproval extends StatefulWidget {
  const _CloseOnApproval({
    required this.controller,
    required this.onClose,
    required this.child,
  });

  final LabeebToolCallController controller;
  final VoidCallback onClose;
  final Widget child;

  @override
  State<_CloseOnApproval> createState() => _CloseOnApprovalState();
}

class _CloseOnApprovalState extends State<_CloseOnApproval> {
  late Set<String> _seen;
  bool _closed = false;

  Set<String> _waiting() => {
    for (final a in widget.controller.activities)
      if (a.call.isClient &&
          a.call.status == NexaToolCallStatus.awaitingApproval)
        a.call.id,
  };

  void _check() {
    if (_closed || !mounted) return;
    if (_waiting().difference(_seen).isNotEmpty) {
      _closed = true;
      widget.onClose();
    }
  }

  @override
  void initState() {
    super.initState();
    _seen = _waiting();
    widget.controller.addListener(_check);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A presented document in its container. Overlays open on the host
/// navigator and never end a live call underneath.
Future<void> showNexaUi(
  BuildContext context,
  LabeebToolCallController controller,
  String uiId, {
  NexaExternalOpener? openExternal,
  NexaUiPresentation? as,
}) async {
  final doc = controller.document(uiId);
  if (doc == null) return;
  final presentation = as ?? doc.presentation;
  Widget body(BuildContext ctx) => _CloseOnApproval(
    controller: controller,
    onClose: () => Navigator.of(ctx).maybePop(),
    child: NexaUiView(
      uiId: uiId,
      controller: controller,
      openExternal: openExternal,
      onDismiss: () => Navigator.of(ctx).maybePop(),
    ),
  );
  switch (presentation) {
    case NexaUiPresentation.bottomSheet:
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => nexaScoped(
          context,
          SafeArea(
            child: SingleChildScrollView(
              key: const Key('nexa_ui_sheet'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: body(sheetContext),
            ),
          ),
        ),
      );
    case NexaUiPresentation.modal:
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => nexaScoped(
          context,
          Dialog(
            key: const Key('nexa_ui_modal'),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: body(dialogContext),
            ),
          ),
        ),
      );
    case NexaUiPresentation.fullscreen:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (routeContext) => nexaScoped(
            context,
            Scaffold(
              key: const Key('nexa_ui_fullscreen'),
              appBar: AppBar(
                title: Text(
                  doc.titleFor(Localizations.localeOf(context).languageCode) ??
                      '',
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: body(routeContext),
              ),
            ),
          ),
        ),
      );
    case NexaUiPresentation.inlineCard ||
        NexaUiPresentation.expandable ||
        NexaUiPresentation.companion:
      return; // rendered in place by the timeline / voice page
  }
}

/// A document in the chat timeline: inline cards and expandables in place;
/// sheets, modals and full screens as a compact card that opens them.
class NexaUiDocumentCard extends StatefulWidget {
  const NexaUiDocumentCard({
    required this.uiId,
    required this.controller,
    this.openExternal,
    this.autoOpen = true,
    super.key,
  });

  final String uiId;
  final LabeebToolCallController controller;
  final NexaExternalOpener? openExternal;

  /// Open overlay presentations once when they arrive.
  final bool autoOpen;

  @override
  State<NexaUiDocumentCard> createState() => _NexaUiDocumentCardState();
}

class _NexaUiDocumentCardState extends State<NexaUiDocumentCard> {
  static final Set<String> _opened = {};
  bool _hidden = false;

  bool _overlay(NexaUiPresentation p) =>
      p == NexaUiPresentation.bottomSheet ||
      p == NexaUiPresentation.modal ||
      p == NexaUiPresentation.fullscreen;

  @override
  void initState() {
    super.initState();
    final doc = widget.controller.document(widget.uiId);
    if (widget.autoOpen &&
        doc != null &&
        _overlay(doc.presentation) &&
        _opened.add(doc.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _show();
      });
    }
  }

  void _show() => showNexaUi(
    context,
    widget.controller,
    widget.uiId,
    openExternal: widget.openExternal,
  );

  @override
  Widget build(BuildContext context) {
    final doc = widget.controller.document(widget.uiId);
    if (doc == null || _hidden) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final l10n = NexaLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    Widget frame(Widget child) => Material(
      key: Key('nexa_ui_card_${doc.id}'),
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (_overlay(doc.presentation)) {
      return frame(
        ListTile(
          leading: Icon(
            Icons.dashboard_customize_outlined,
            color: scheme.primary,
          ),
          title: Text(doc.titleFor(lang) ?? l10n.duiOpen),
          trailing: const Icon(Icons.open_in_full_rounded),
          onTap: _show,
        ),
      );
    }
    final view = NexaUiView(
      uiId: widget.uiId,
      controller: widget.controller,
      openExternal: widget.openExternal,
      onDismiss: () => setState(() => _hidden = true),
    );
    if (doc.presentation == NexaUiPresentation.expandable) {
      return frame(
        ExpansionTile(
          title: Text(doc.titleFor(lang) ?? ''),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: const Border(),
          children: [view],
        ),
      );
    }
    return frame(Padding(padding: const EdgeInsets.all(16), child: view));
  }
}
