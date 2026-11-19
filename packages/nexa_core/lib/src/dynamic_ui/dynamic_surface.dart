import 'package:meta/meta.dart';

/// Dynamic UI schema major version this SDK renders (design handoff
/// "Dynamic UI", proposal). Minor additions are ignored; another major is
/// rendered as `fallback_text` only.
const int dynamicUiSchemaMajor = 1;

/// The ten presentation categories (design A–J).
enum NexaSurfaceCategory {
  choicesForms('choices_forms'),
  themesAppearance('themes_appearance'),
  news('news'),
  sports('sports'),
  research('web_research'),
  placesMaps('places_maps'),
  media('images_media'),
  files('files_documents'),
  deviceActions('device_actions'),
  tasks('tasks_workflows');

  const NexaSurfaceCategory(this.wire);
  final String wire;

  static NexaSurfaceCategory? fromWire(Object? v) =>
      values.where((c) => c.wire == v).firstOrNull;
}

/// Containers for the same component tree.
enum NexaPresentation {
  inlineCard('inline_card'),
  expandable('expandable'),
  floatingPanel('floating_panel'),
  modal('modal'),
  bottomSheet('bottom_sheet'),
  fullScreen('full_screen'),
  voiceCompanion('voice_companion');

  const NexaPresentation(this.wire);
  final String wire;

  static NexaPresentation fromWire(Object? v) =>
      values.where((p) => p.wire == v).firstOrNull ?? inlineCard;
}

/// Shared surface states (catalogue §3).
enum NexaSurfaceState {
  loading,
  partial,
  ready,
  empty,
  disabled,
  error,
  offline,
  providerUnavailable,
  confirmation,
}

/// Closed component library (catalogue §2). Anything else renders as text.
const Set<String> nexaComponentTypes = {
  'text',
  'single_choice',
  'multi_choice',
  'palette_choice',
  'segmented',
  'switch',
  'slider',
  'text_input',
  'filter_chips',
  'news_list',
  'score_cards',
  'search_results',
  'comparison',
  'summary',
  'place_list',
  'map_preview',
  'image_grid',
  'image',
  'file_preview',
  'action_list',
  'steps',
  'progress',
  'banner',
  'key_value',
  'attribution',
};

/// Closed action types (Flutter handoff "Actions"). Unknown types render
/// disabled with a reason.
const Set<String> nexaActionTypes = {
  'confirm',
  'cancel',
  'select',
  'open_url',
  'open_navigation',
  'directions',
  'share',
  'save',
  'download',
  'summarize',
  'compare',
  'follow_up',
  'camera.capture',
  'location.get',
  'permission.request',
  'workflow.start',
  'workflow.cancel',
  'approval',
  'host.theme.apply',
  'host.theme.reset',
};

/// A selectable option with a stable id and order.
@immutable
final class NexaChoice {
  const NexaChoice({required this.id, required this.order, required this.data});

  final String id;
  final int order;

  /// All scalar fields of the choice (label, swatches, distance_m, …).
  final Map<String, Object?> data;

  String get label => '${data['label'] ?? id}';
  bool get disabled => data['disabled'] == true;
  String? get disabledReason => data['disabled_reason'] as String?;
}

/// One validated component. Typed accessors read from [data]; the payload
/// is never executed.
@immutable
final class NexaComponent {
  const NexaComponent({
    required this.type,
    required this.id,
    required this.data,
    this.choices = const [],
  });

  final String type;
  final String id;
  final Map<String, Object?> data;

  /// Ordered by `order` (stable across updates).
  final List<NexaChoice> choices;

  bool get known => nexaComponentTypes.contains(type);
  String? get a11yLabel => data['a11y_label'] as String?;
  String? get title => data['title'] as String?;
  String? get fallbackText => data['fallback_text'] as String?;
  List<Map<String, Object?>> items(String key) => [
    for (final e in (data[key] as List?) ?? const [])
      if (e is Map) e.cast<String, Object?>(),
  ];
}

@immutable
final class NexaSurfaceAction {
  const NexaSurfaceAction({
    required this.id,
    required this.type,
    required this.data,
  });

  final String id;
  final String type;
  final Map<String, Object?> data;

  bool get known => nexaActionTypes.contains(type);
  String? get label => data['label'] as String?;
  bool get requiresConfirmation => data['requires_confirmation'] == true;
  bool get destructive => data['destructive'] == true;

  /// Component ids whose current values are the action's parameters.
  List<String> get paramsFrom => [
    for (final p in (data['params_from'] as List?) ?? const [])
      if (p is String) p,
  ];
}

@immutable
final class NexaSurfaceStatus {
  const NexaSurfaceStatus({
    this.state = NexaSurfaceState.ready,
    this.code,
    this.message,
    this.retryable = false,
  });

  final NexaSurfaceState state;
  final String? code;
  final String? message;
  final bool retryable;
}

/// Provider provenance (required for provider-backed categories).
@immutable
final class NexaToolResultReference {
  const NexaToolResultReference({
    this.tool,
    this.resultId,
    this.provider,
    this.retrievedAt,
  });

  final String? tool;
  final String? resultId;
  final String? provider;
  final DateTime? retrievedAt;
}

/// A validated Dynamic UI surface.
@immutable
final class NexaSurface {
  const NexaSurface({
    required this.surfaceId,
    required this.schemaVersion,
    required this.fallbackText,
    this.conversationId,
    this.messageId,
    this.category,
    this.presentation = NexaPresentation.inlineCard,
    this.title,
    this.description,
    this.components = const [],
    this.actions = const [],
    this.status = const NexaSurfaceStatus(),
    this.reference,
    this.supported = true,
    this.demo = false,
    this.problems = const [],
  });

  final String surfaceId;
  final String schemaVersion;
  final String? conversationId;
  final String? messageId;
  final NexaSurfaceCategory? category;
  final NexaPresentation presentation;
  final String? title;
  final String? description;
  final List<NexaComponent> components;
  final List<NexaSurfaceAction> actions;
  final NexaSurfaceStatus status;
  final NexaToolResultReference? reference;
  final String fallbackText;

  /// False when the major schema version is unsupported: render
  /// [fallbackText] only.
  final bool supported;

  /// Developer demo data (always labelled as such).
  final bool demo;

  /// Validation notes (invalid components dropped to text, etc.).
  final List<String> problems;

  NexaComponent? component(String id) =>
      components.where((c) => c.id == id).firstOrNull;
}

/// Parses and validates a surface. Never throws for content problems: an
/// unusable payload becomes an unsupported surface showing its
/// `fallback_text`. Returns null only when even `surface_id` is missing.
NexaSurface? parseNexaSurface(Map<String, Object?> json) {
  final id = json['surface_id'];
  if (id is! String || id.isEmpty) return null;
  final version = '${json['schema_version'] ?? ''}';
  final fallback =
      json['fallback_text'] as String? ?? json['title'] as String? ?? '';
  final major = int.tryParse(version.split('.').first);
  if (major != dynamicUiSchemaMajor) {
    return NexaSurface(
      surfaceId: id,
      schemaVersion: version,
      fallbackText: fallback,
      supported: false,
      problems: ['unsupported schema_version "$version"'],
    );
  }
  final problems = <String>[];
  final components = <NexaComponent>[];
  for (final raw in (json['components'] as List?) ?? const []) {
    if (raw is! Map) {
      problems.add('component is not an object');
      continue;
    }
    final c = raw.cast<String, Object?>();
    final type = c['type'];
    final cid = c['id'];
    if (type is! String || cid is! String || cid.isEmpty) {
      problems.add('component without type/id');
      continue;
    }
    final choices = <NexaChoice>[];
    final seen = <String>{};
    for (final (i, ch) in ((c['choices'] as List?) ?? const []).indexed) {
      if (ch is! Map || ch['id'] is! String) continue;
      final chId = ch['id']! as String;
      if (!seen.add(chId)) {
        problems.add('duplicate choice id $chId in $cid');
        continue;
      }
      choices.add(
        NexaChoice(
          id: chId,
          order: ch['order'] is int ? ch['order']! as int : i + 1,
          data: Map.unmodifiable(ch.cast<String, Object?>()),
        ),
      );
    }
    choices.sort((a, b) => a.order.compareTo(b.order));
    if (!nexaComponentTypes.contains(type)) {
      problems.add('unknown component type "$type" ($cid): shown as text');
    }
    components.add(
      NexaComponent(
        type: type,
        id: cid,
        data: Map.unmodifiable(c),
        choices: List.unmodifiable(choices),
      ),
    );
  }
  final actions = <NexaSurfaceAction>[];
  for (final (i, raw) in ((json['actions'] as List?) ?? const []).indexed) {
    if (raw is! Map || raw['type'] is! String) continue;
    final a = raw.cast<String, Object?>();
    actions.add(
      NexaSurfaceAction(
        id: a['id'] as String? ?? 'action_$i',
        type: a['type']! as String,
        data: Map.unmodifiable(a),
      ),
    );
  }
  final s = (json['status'] as Map?)?.cast<String, Object?>() ?? const {};
  final ref = (json['tool_result_reference'] as Map?)?.cast<String, Object?>();
  return NexaSurface(
    surfaceId: id,
    schemaVersion: version,
    conversationId: json['conversation_id'] as String?,
    messageId: json['message_id'] as String?,
    category: NexaSurfaceCategory.fromWire(json['category']),
    presentation: NexaPresentation.fromWire(json['presentation']),
    title: json['title'] as String?,
    description: json['description'] as String?,
    components: List.unmodifiable(components),
    actions: List.unmodifiable(actions),
    status: NexaSurfaceStatus(
      state: switch (s['state']) {
        'loading' => NexaSurfaceState.loading,
        'partial' => NexaSurfaceState.partial,
        'empty' => NexaSurfaceState.empty,
        'disabled' => NexaSurfaceState.disabled,
        'offline' => NexaSurfaceState.offline,
        'confirmation' => NexaSurfaceState.confirmation,
        'error' when s['code'] == 'provider_unavailable' =>
          NexaSurfaceState.providerUnavailable,
        'error' => NexaSurfaceState.error,
        _ => NexaSurfaceState.ready,
      },
      code: s['code'] as String?,
      message: s['message'] as String?,
      retryable: s['retryable'] == true,
    ),
    reference: ref == null
        ? null
        : NexaToolResultReference(
            tool: ref['tool'] as String?,
            resultId: ref['result_id'] as String?,
            provider: ref['provider'] as String?,
            retrievedAt: DateTime.tryParse('${ref['retrieved_at']}'),
          ),
    fallbackText: fallback,
    demo: json['demo'] == true,
    problems: List.unmodifiable(problems),
  );
}

/// Where a selection came from.
enum NexaSelectionSource { touch, voice, text }

/// Typed surface events (selection, value_change, action, permission,
/// approval), identical for touch and future voice/text selection.
@immutable
final class NexaSurfaceEvent {
  const NexaSurfaceEvent({
    required this.eventType,
    required this.surfaceId,
    this.messageId,
    this.conversationId,
    this.componentId,
    this.choiceIds = const [],
    this.value,
    this.actionId,
    this.actionType,
    this.params = const {},
    this.source = NexaSelectionSource.touch,
    this.utterance,
  });

  /// `selection`, `value_change`, `action`, `permission`, `approval`.
  final String eventType;
  final String surfaceId;
  final String? messageId;
  final String? conversationId;
  final String? componentId;
  final List<String> choiceIds;
  final Object? value;
  final String? actionId;
  final String? actionType;
  final Map<String, Object?> params;
  final NexaSelectionSource source;
  final String? utterance;

  Map<String, Object?> toJson() => {
    'schema_version': '$dynamicUiSchemaMajor.0',
    'event_type': eventType,
    'surface_id': surfaceId,
    'message_id': ?messageId,
    'conversation_id': ?conversationId,
    'component_id': ?componentId,
    if (choiceIds.isNotEmpty) 'choice_ids': choiceIds,
    'value': ?value,
    'action_id': ?actionId,
    'action_type': ?actionType,
    if (params.isNotEmpty) 'params': params,
    'source': source.name,
    'utterance': ?utterance,
  };
}
