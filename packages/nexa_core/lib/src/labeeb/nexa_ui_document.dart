import 'dart:convert';

import 'package:meta/meta.dart';

/// Dynamic UI documents, contract `labeeb.sdk/1` `ui` (`nexa.ui/1`).
///
/// A document is a tree of components from a closed set. Unknown component
/// types are skipped, unknown fields ignored; the renderer uses the host
/// ThemeData and never applies styles from the document.
const nexaUiSchema = 'nexa.ui/1';

/// `ui.components` of `nexa.ui/1`.
const nexaUiComponentTypes = {
  'text',
  'icon',
  'image',
  'button',
  'choice',
  'palette',
  'switch',
  'slider',
  'input',
  'list',
  'grid',
  'card',
  'row',
  'column',
  'divider',
  'progress',
  'confirm',
  'link',
};

/// `ui.limits`.
abstract final class NexaUiLimits {
  static const maxNodes = 200;
  static const maxDepth = 6;
  static const maxBytes = 48000;
}

final _idPattern = RegExp(r'^[A-Za-z0-9_.:-]{1,64}$');

/// `ui.presentations` (unknown values fall back to [inlineCard]).
enum NexaUiPresentation {
  inlineCard('inline_card'),
  modal('modal'),
  bottomSheet('bottom_sheet'),
  expandable('expandable'),
  fullscreen('fullscreen'),
  companion('companion');

  const NexaUiPresentation(this.wire);
  final String wire;

  static NexaUiPresentation fromWire(Object? v) =>
      values.where((p) => p.wire == v).firstOrNull ?? inlineCard;
}

/// `ui.actions` (closed): send_ui_event, open_url, client_tool, dismiss.
@immutable
final class NexaUiAction {
  const NexaUiAction({
    required this.type,
    this.event,
    this.url,
    this.tool,
    this.data = const {},
  });

  final String type;

  /// `select|confirm|cancel|submit|change|dismiss` for `send_ui_event`.
  final String? event;

  /// https only (validated on parse).
  final String? url;
  final String? tool;
  final Map<String, Object?> data;

  static const types = {'send_ui_event', 'open_url', 'client_tool', 'dismiss'};
  static const events = {
    'select',
    'confirm',
    'cancel',
    'submit',
    'change',
    'dismiss',
  };

  static NexaUiAction? fromJson(Object? v) {
    if (v is! Map || v['type'] is! String) return null;
    final type = v['type']! as String;
    if (!types.contains(type)) return null;
    final event = v['event'];
    final url = v['url'];
    return NexaUiAction(
      type: type,
      event: event is String && events.contains(event) ? event : null,
      url: url is String && isHttpsUrl(url) ? url : null,
      tool: v['tool'] as String?,
      data: v.cast<String, Object?>(),
    );
  }
}

/// https URL with a host, no credentials.
bool isHttpsUrl(String v) {
  final u = Uri.tryParse(v);
  return u != null &&
      u.scheme == 'https' &&
      u.host.isNotEmpty &&
      u.userInfo.isEmpty;
}

/// A selectable option: stable [id] and 1-based [ordinal], so a touch and
/// "the second one" resolve to the same id.
@immutable
final class NexaUiOption {
  const NexaUiOption({
    required this.id,
    required this.ordinal,
    this.label,
    this.colors = const {},
    this.data = const {},
  });

  final String id;
  final int ordinal;

  /// A string or `{en, ar}` (see [labelFor]).
  final Object? label;

  /// `{role: #RRGGBB}` (palette options; painted only inside the swatch).
  final Map<String, String> colors;
  final Map<String, Object?> data;

  String labelFor(String languageCode) =>
      localizedText(label, languageCode) ?? id;
}

/// A string, or a `{en, ar}` map picked by [languageCode].
String? localizedText(Object? v, String languageCode) {
  if (v is String) return v;
  if (v is Map) {
    final s = v[languageCode] ?? v['en'] ?? v.values.firstOrNull;
    return s is String ? s : null;
  }
  return null;
}

/// One component. [props] keeps every field (renderers read their own).
@immutable
final class NexaUiNode {
  const NexaUiNode({
    required this.id,
    required this.type,
    this.children = const [],
    this.items = const [],
    this.options = const [],
    this.actions = const {},
    this.props = const {},
  });

  final String id;
  final String type;
  final List<NexaUiNode> children;
  final List<NexaUiNode> items;
  final List<NexaUiOption> options;

  /// `on_select`, `on_change`, `on_confirm`, `on_cancel`, `on_submit`,
  /// `action`, `on_tap`.
  final Map<String, NexaUiAction> actions;
  final Map<String, Object?> props;

  String? text(String key, String languageCode) =>
      localizedText(props[key], languageCode);

  NexaUiOption? optionByOrdinal(int ordinal) =>
      options.where((o) => o.ordinal == ordinal).firstOrNull;
}

/// A parsed `nexa.ui/1` document.
@immutable
final class NexaUiDocument {
  const NexaUiDocument({
    required this.id,
    required this.category,
    required this.presentation,
    required this.root,
    this.title,
    this.toolCallId,
    this.truncated = false,
    this.raw = const {},
  });

  final String id;

  /// Open set (`ui.categories`); unknown categories still render.
  final String category;
  final NexaUiPresentation presentation;
  final Object? title;
  final NexaUiNode? root;

  /// The tool call that presented it (for `GET .../tool-calls/{id}`).
  final String? toolCallId;

  /// Voice: large documents arrive as `{id, category, truncated: true}`;
  /// read the full one from the tool call.
  final bool truncated;
  final Map<String, Object?> raw;

  String? titleFor(String languageCode) => localizedText(title, languageCode);

  /// Every node, depth first.
  Iterable<NexaUiNode> get nodes sync* {
    Iterable<NexaUiNode> walk(NexaUiNode n) sync* {
      yield n;
      for (final c in [...n.children, ...n.items]) {
        yield* walk(c);
      }
    }

    if (root != null) yield* walk(root!);
  }

  NexaUiNode? node(String id) => nodes.where((n) => n.id == id).firstOrNull;
}

/// Why a document was rejected.
final class NexaUiDocumentException implements Exception {
  const NexaUiDocumentException(this.reason);
  final String reason;
  @override
  String toString() => 'NexaUiDocumentException: $reason';
}

/// Parses a `nexa.ui/1` document. Throws [NexaUiDocumentException] for a
/// wrong schema, bad ids or a document over the limits; unknown component
/// types are dropped (with their subtree), unknown fields ignored.
/// [extensionTypes] are host-rendered types kept as well (the host
/// registered a renderer for them); they obey the same limits.
NexaUiDocument parseNexaUiDocument(
  Map<String, Object?> json, {
  String? toolCallId,
  Set<String> extensionTypes = const {},
}) {
  final id = json['id'];
  if (id is! String || !_idPattern.hasMatch(id)) {
    throw const NexaUiDocumentException('missing or invalid id');
  }
  final category = json['category'] is String
      ? json['category']! as String
      : 'unknown';
  if (json['truncated'] == true) {
    return NexaUiDocument(
      id: id,
      category: category,
      presentation: NexaUiPresentation.fromWire(json['presentation']),
      title: json['title'],
      root: null,
      toolCallId: toolCallId,
      truncated: true,
      raw: json,
    );
  }
  if (json['schema'] != nexaUiSchema) {
    throw NexaUiDocumentException('unsupported schema ${json['schema']}');
  }
  if (utf8.encode(jsonEncode(json)).length > NexaUiLimits.maxBytes) {
    throw const NexaUiDocumentException('document over max_bytes');
  }
  var count = 0;
  final seen = <String>{};

  NexaUiNode? parseNode(Object? v, int depth) {
    if (v is! Map) return null;
    final nid = v['id'];
    final type = v['type'];
    if (nid is! String || !_idPattern.hasMatch(nid) || type is! String) {
      return null;
    }
    if (!nexaUiComponentTypes.contains(type) &&
        !extensionTypes.contains(type)) {
      return null; // skipped
    }
    if (depth > NexaUiLimits.maxDepth) {
      throw const NexaUiDocumentException('document over max_depth');
    }
    if (++count > NexaUiLimits.maxNodes) {
      throw const NexaUiDocumentException('document over max_nodes');
    }
    if (!seen.add(nid)) {
      throw NexaUiDocumentException('duplicate component id $nid');
    }
    List<NexaUiNode> kids(String key) => [
      for (final c in (v[key] as List?) ?? const []) ?parseNode(c, depth + 1),
    ];
    final optionIds = <String>{};
    final options = <NexaUiOption>[];
    for (final (i, o) in ((v['options'] as List?) ?? const []).indexed) {
      if (o is! Map || o['id'] is! String) continue;
      final oid = o['id']! as String;
      if (!optionIds.add(oid)) continue;
      final colors = <String, String>{};
      if (o['colors'] case final Map<Object?, Object?> c) {
        for (final MapEntry(:key, :value) in c.entries) {
          if (key is String &&
              value is String &&
              RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
            colors[key] = value;
          }
        }
      }
      options.add(
        NexaUiOption(
          id: oid,
          ordinal: o['ordinal'] is int && (o['ordinal']! as int) >= 1
              ? o['ordinal']! as int
              : i + 1,
          label: o['label'],
          colors: colors,
          data: o.cast<String, Object?>(),
        ),
      );
    }
    options.sort((a, b) => a.ordinal.compareTo(b.ordinal));
    final actions = <String, NexaUiAction>{};
    for (final key in const [
      'on_select',
      'on_change',
      'on_confirm',
      'on_cancel',
      'on_submit',
      'action',
      'on_tap',
    ]) {
      final a = NexaUiAction.fromJson(v[key]);
      if (a != null) actions[key] = a;
    }
    return NexaUiNode(
      id: nid,
      type: type,
      children: kids('children'),
      items: kids('items'),
      options: List.unmodifiable(options),
      actions: Map.unmodifiable(actions),
      props: Map.unmodifiable(v.cast<String, Object?>()),
    );
  }

  final root = parseNode(json['root'], 1);
  if (root == null) {
    throw const NexaUiDocumentException('missing or unsupported root');
  }
  return NexaUiDocument(
    id: id,
    category: category,
    presentation: NexaUiPresentation.fromWire(json['presentation']),
    title: json['title'],
    root: root,
    toolCallId: toolCallId,
    raw: json,
  );
}

/// `ui_event` sent on `POST /messages` (validated by the gateway against
/// the document it sent: a stale or forged event answers 422).
@immutable
final class NexaUiEvent {
  const NexaUiEvent({
    required this.uiId,
    required this.componentId,
    required this.event,
    this.optionIds,
    this.value,
  });

  final String uiId;
  final String componentId;

  /// `select|confirm|cancel|submit|change|dismiss`.
  final String event;
  final List<String>? optionIds;

  /// string, number or boolean.
  final Object? value;

  Map<String, Object?> toJson() => {
    'ui_id': uiId,
    'component_id': componentId,
    'event': event,
    'option_ids': ?optionIds,
    'value': ?value,
  };
}
