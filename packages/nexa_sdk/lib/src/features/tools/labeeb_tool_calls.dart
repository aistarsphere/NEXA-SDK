import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:nexa_core/nexa_core.dart';
import 'package:nexa_sdk/src/data/labeeb/labeeb_sdk_client.dart';
import 'package:nexa_sdk/src/data/network/error_mapper.dart';
import 'package:nexa_sdk/src/features/dynamic_ui/nexa_host_capabilities.dart';
import 'package:nexa_sdk/src/features/media/nexa_conversation_media.dart';
import 'package:nexa_sdk/src/features/tools/labeeb_device_tools.dart';

/// What the device is doing with a call (the gateway's status is
/// authoritative; this only covers the local part).
enum LabeebLocalPhase {
  /// Nothing to do on the device (server tool, or not our turn yet).
  idle,

  /// Waiting for the user's Allow / Not now (status awaiting_approval).
  awaitingUser,

  /// Sending the approval.
  approving,

  /// Running the device tool.
  running,

  /// Posting the result.
  answering,

  /// The gateway accepted the answer.
  answered,

  /// The answer could not be delivered ([LabeebToolActivity.localError]).
  failed,
}

/// The live state of one tool call.
@immutable
final class LabeebToolActivity {
  const LabeebToolActivity({
    required this.call,
    required this.firstSeen,
    this.progress,
    this.assets = const [],
    this.phase = LabeebLocalPhase.idle,
    this.localError,
    this.surface = NexaItemSurface.chat,
  });

  final NexaToolCall call;
  final DateTime firstSeen;
  final NexaToolCallProgress? progress;
  final List<NexaAssetRef> assets;
  final LabeebLocalPhase phase;

  /// Gateway or device error code of the local step (e.g.
  /// `tool_call_closed`, `permission_denied`).
  final String? localError;
  final NexaItemSurface surface;

  LabeebToolActivity copyWith({
    NexaToolCall? call,
    NexaToolCallProgress? progress,
    List<NexaAssetRef>? assets,
    LabeebLocalPhase? phase,
    String? localError,
    bool clearError = false,
  }) => LabeebToolActivity(
    call: call ?? this.call,
    firstSeen: firstSeen,
    progress: progress ?? this.progress,
    assets: assets ?? this.assets,
    phase: phase ?? this.phase,
    localError: clearError ? null : localError ?? this.localError,
    surface: surface,
  );
}

/// Where tool calls are answered. The chat session in chat; the voice
/// call's `tools.session_id` in voice.
typedef LabeebSessionResolver = String? Function();

/// Runs the `labeeb.sdk/1` tool-call lifecycle on the device and keeps the
/// state of every call, long job, produced asset and `nexa.ui/1` document
/// of the conversation, for both the chat and the live voice views.
///
/// * Client tools: `awaiting_approval` → the user decides in the card →
///   `POST .../approval` → `awaiting_client` → the device tool runs →
///   `POST .../result` once. A closed call (409 `tool_call_closed`) is
///   shown as such, never retried.
/// * Server tools and jobs: shown with their status and progress; a job is
///   never shown as finished before `tool_call_completed`/`asset_created`.
/// * Nothing runs that the gateway did not request, and only tools this
///   device declared in `client_tools`.
final class LabeebToolCallController extends ChangeNotifier {
  LabeebToolCallController({
    required this.api,
    required List<LabeebDeviceTool> tools,
    required this.media,
    this.host = const NexaHostCapabilities(),
    List<String>? priority,
    NexaDiagnostics diagnostics = const NoopNexaDiagnostics(),
  }) : _tools = {for (final t in tools) t.name: t},
       _priority = priority ?? declarationPriority,
       _diagnostics = diagnostics;

  final LabeebSdkClient api;
  final NexaConversationMedia media;
  final NexaHostCapabilities host;
  final Map<String, LabeebDeviceTool> _tools;
  final List<String> _priority;
  final NexaDiagnostics _diagnostics;

  /// Session used to answer chat tool calls (set by the chat view).
  LabeebSessionResolver chatSession = () => null;

  /// Conversation used for uploads (set by the chat view).
  LabeebSessionResolver conversation = () => null;

  /// The view that can present device UI (camera, pickers, sheets).
  BuildContext? Function() presenter = () => null;

  /// Sends a `nexa.ui/1` event (chat: `POST /messages` `ui_event`).
  /// Returns the gateway error code, null when accepted.
  Future<String?> Function(NexaUiEvent event)? uiEventSink;

  final LinkedHashMap<String, LabeebToolActivity> _calls = LinkedHashMap();
  final Map<String, NexaUiDocument> _documents = {};
  final Map<String, String> _sessionOf = {};
  final Set<String> _answered = {};
  final Map<String, Map<String, Object?>> _uiValues = {};
  final Map<String, Future<Uint8List>> _bytes = {};
  LabeebToolCatalogue? _catalogue;
  Object? _catalogueError;
  bool _disposed = false;

  /// Production refuses more than 8 `client_tools` (observed 2026-10-28:
  /// 9+ answer 422 `validation_failed`; not stated in labeeb.sdk/1).
  static const maxDeclaredTools = 8;

  /// Declaration order when more tools exist than may be declared:
  /// E2E-verified flows first, then the host features.
  static const declarationPriority = [
    LabeebTools.location,
    LabeebTools.directions,
    LabeebTools.camera,
    LabeebTools.photoPick,
    LabeebTools.filePick,
    LabeebTools.openUrl,
    LabeebTools.themeApply,
    LabeebTools.recordSample,
    LabeebTools.themeReset,
    LabeebTools.share,
    LabeebTools.openSettings,
    LabeebTools.network,
  ];

  /// Device tools this client can run (what `client_tools` declares),
  /// at most [maxDeclaredTools], in the host's priority order (default
  /// [declarationPriority]). When the catalogue is readable, only tools it
  /// lists as `available` for this application are declared: an
  /// unavailable tool can never run, and would take a scarce slot. Never
  /// waits for the catalogue: session start must not depend on it.
  Future<List<String>> declaredTools() async {
    if (_catalogue == null && _catalogueError == null) {
      unawaited(refreshCatalogue());
    }
    final catalogue = _catalogue;
    final supported = [
      for (final t in _tools.values)
        if ((catalogue == null || _declarable(catalogue[t.name])) &&
            await t.supported())
          t.name,
    ];
    int rank(String n) {
      final i = _priority.indexOf(n);
      return i < 0 ? _priority.length : i;
    }

    supported.sort((a, b) => rank(a).compareTo(rank(b)));
    return supported.take(maxDeclaredTools).toList();
  }

  // `client_does_not_support` only means this device has not declared it.
  static bool _declarable(LabeebToolEntry? e) =>
      e != null &&
      (e.available || e.unavailableReason == 'client_does_not_support');

  LabeebToolActivity? activity(String toolCallId) => _calls[toolCallId];
  Iterable<LabeebToolActivity> get activities => _calls.values;
  NexaUiDocument? document(String uiId) => _documents[uiId];

  /// Jobs still running (for "ask about my jobs" and the voice companion).
  Iterable<LabeebToolActivity> get runningJobs => _calls.values.where(
    (a) => a.call.asynchronous && !a.call.status.terminal,
  );

  // ----------------------------------------------------------- catalogue

  LabeebToolCatalogue? get catalogue => _catalogue;

  /// Why the catalogue is unavailable (e.g. `forbidden`: the token has no
  /// `tools:use` scope; `tools_disabled`).
  String? get catalogueUnavailable => _catalogueError == null
      ? null
      : gatewayErrorCode(_catalogueError!) ?? 'unavailable';

  /// `GET /tools`; availability comes only from here, never from model
  /// names.
  Future<void> refreshCatalogue() async {
    try {
      _catalogue = await api.tools();
      _catalogueError = null;
    } on Object catch (e) {
      _catalogue = null;
      _catalogueError = e;
    }
    // May finish after dispose (refreshed in the background).
    if (!_disposed) notifyListeners();
  }

  // --------------------------------------------------------------- events

  /// Feeds a chat event (from `ChatBloc.toolEvents`).
  void ingest(
    ConversationEvent e, {
    NexaItemSurface surface = NexaItemSurface.chat,
    String? sessionId,
  }) {
    switch (e) {
      case ContractToolCallEvent(:final call):
        final c = NexaToolCall.fromJson(call);
        if (c != null) {
          _onCall(
            c,
            surface: surface,
            sessionId: sessionId ?? e.sessionId.value,
          );
        }
      case ToolCallProgressEvent(:final toolCallId, :final tool, :final state):
        final a = _calls[toolCallId];
        final p = NexaToolCallProgress(
          toolCallId: toolCallId,
          tool: tool,
          state: state,
          waitedSeconds: e.waitedS,
        );
        if (a != null) {
          _calls[toolCallId] = a.copyWith(progress: p);
          notifyListeners();
        }
      case AssetCreatedEvent(:final asset, :final toolCallId):
        final ref = NexaAssetRef.fromJson(asset);
        if (ref != null) onAsset(ref, toolCallId: toolCallId, surface: surface);
      case UiPresentedEvent(:final ui, :final toolCallId):
        onUi(ui, toolCallId: toolCallId, surface: surface);
      default:
        break;
    }
  }

  /// Voice: a tool event from the sealed voice channel (same fields as the
  /// SSE events). [toolsSessionId] is `tools.session_id` of the call.
  void ingestVoice(
    String type,
    Map<String, Object?> data, {
    required String? toolsSessionId,
  }) {
    switch (type) {
      case 'tool_call_requested' ||
          'tool_call_updated' ||
          'tool_call_completed' ||
          'tool_call_failed':
        final c = NexaToolCall.fromJson(data);
        if (c != null) {
          _onCall(c, surface: NexaItemSurface.voice, sessionId: toolsSessionId);
        }
      case 'tool_call_progress':
        final id = data['tool_call_id'];
        final a = id is String ? _calls[id] : null;
        if (a != null) {
          _calls[a.call.id] = a.copyWith(
            progress: NexaToolCallProgress(
              toolCallId: a.call.id,
              tool: a.call.tool,
              state: '${data['state'] ?? ''}',
              waitedSeconds: data['waited_s'] as int?,
            ),
          );
          notifyListeners();
        }
      case 'asset_created':
        final ref = NexaAssetRef.fromJson(data['asset']);
        if (ref != null) {
          onAsset(
            ref,
            toolCallId: data['tool_call_id'] as String?,
            surface: NexaItemSurface.voice,
          );
        }
      case 'ui_presented':
        if (data['ui'] case final Map<Object?, Object?> ui) {
          onUi(
            ui.cast<String, Object?>(),
            toolCallId: data['tool_call_id'] as String?,
            surface: NexaItemSurface.voice,
            sessionId: toolsSessionId,
          );
        }
    }
  }

  void _onCall(
    NexaToolCall c, {
    required NexaItemSurface surface,
    String? sessionId,
  }) {
    if (sessionId != null) _sessionOf[c.id] = sessionId;
    final existing = _calls[c.id];
    var a =
        existing?.copyWith(call: c) ??
        LabeebToolActivity(
          call: c,
          firstSeen: DateTime.now().toUtc(),
          surface: surface,
        );
    if (existing == null) {
      media.add(
        NexaToolCallItem(
          id: 'tc:${c.id}',
          createdAt: a.firstSeen,
          toolCallId: c.id,
          surface: surface,
        ),
      );
    }
    _diagnostics.record('tool.call', {
      'tool_call_id': c.id,
      'tool': c.tool,
      'side': c.side.name,
      'status': c.status.wire,
    });
    if (c.isClient && !c.status.terminal && !_answered.contains(c.id)) {
      final tool = _tools[c.tool];
      if (tool == null) {
        // Not declared by this device: refuse cleanly, never run.
        unawaited(_refuseUnknown(c));
      } else if (c.status == NexaToolCallStatus.awaitingApproval &&
          a.phase == LabeebLocalPhase.idle) {
        a = a.copyWith(phase: LabeebLocalPhase.awaitingUser);
        if (c.tool == LabeebTools.themeApply) {
          // The preview is what the user approves.
          final spec = themeSpecOf(c);
          if (spec != null) unawaited(host.theme?.previewSpec(spec));
        }
      } else if (c.status == NexaToolCallStatus.awaitingClient &&
          (a.phase == LabeebLocalPhase.idle ||
              a.phase == LabeebLocalPhase.awaitingUser ||
              a.phase == LabeebLocalPhase.approving)) {
        a = a.copyWith(phase: LabeebLocalPhase.running);
        _calls[c.id] = a;
        unawaited(_run(c, tool));
      }
    }
    if (c.status.terminal && c.tool == LabeebTools.themeApply) {
      // Denied/expired/cancelled: drop a preview that was never applied.
      if (c.status != NexaToolCallStatus.succeeded) {
        unawaited(host.theme?.cancelPreview());
      }
    }
    if (!c.isClient &&
        c.status == NexaToolCallStatus.succeeded &&
        existing?.call.status != NexaToolCallStatus.succeeded) {
      unawaited(_adoptResultAsset(c, surface));
      if (!_completed.isClosed) _completed.add(c);
    }
    _calls[c.id] = a;
    notifyListeners();
  }

  /// Server tools that just succeeded (each once), e.g. so the host can
  /// react to `voice.profile.activate`.
  Stream<NexaToolCall> get completed => _completed.stream;
  final StreamController<NexaToolCall> _completed =
      StreamController<NexaToolCall>.broadcast();

  /// A result naming an `asset_id` the client has not seen (no
  /// `asset_created`, e.g. `voice.profile.preview`) is shown from its
  /// metadata, so any tool producing a file needs no SDK change.
  Future<void> _adoptResultAsset(
    NexaToolCall c,
    NexaItemSurface surface,
  ) async {
    final id = c.result?['asset_id'];
    if (id is! String || id.isEmpty) return;
    if (media.items.any((i) => i.id == 'ast:$id')) return;
    try {
      final ref = await api.asset(id);
      if (!_disposed) onAsset(ref, toolCallId: c.id, surface: surface);
    } on Object catch (e) {
      // The card still shows the call's status; nothing is invented.
      _diagnostics.record('tool.result_asset_failed', {
        'tool_call_id': c.id,
        'error': e.runtimeType.toString(),
      });
    }
  }

  String? _session(String toolCallId) =>
      _sessionOf[toolCallId] ?? chatSession();

  Future<void> _refuseUnknown(NexaToolCall c) async {
    final sid = _session(c.id);
    if (sid == null || !_answered.add(c.id)) return;
    try {
      if (c.status == NexaToolCallStatus.awaitingApproval) {
        await api.approve(sid, c.id, granted: false);
      } else if (c.status == NexaToolCallStatus.awaitingClient) {
        await api.answer(
          sid,
          c.id,
          const NexaToolCallAnswer.failure(
            NexaToolCallError(NexaDeviceErrorCodes.unsupported),
          ),
        );
      }
    } on Object catch (e) {
      _diagnostics.record('tool.refuse_failed', {
        'tool_call_id': c.id,
        'gateway_code': gatewayErrorCode(e),
      });
    }
  }

  // ------------------------------------------------------------- approval

  /// The user's decision in the tool card (status `awaiting_approval`).
  Future<void> decide(String toolCallId, {required bool allow}) async {
    final a = _calls[toolCallId];
    final sid = _session(toolCallId);
    if (a == null ||
        sid == null ||
        a.phase != LabeebLocalPhase.awaitingUser ||
        a.call.status != NexaToolCallStatus.awaitingApproval) {
      return;
    }
    _set(toolCallId, a.copyWith(phase: LabeebLocalPhase.approving));
    if (!allow && a.call.tool == LabeebTools.themeApply) {
      await host.theme?.cancelPreview();
    }
    try {
      final updated = await api.approve(sid, toolCallId, granted: allow);
      _diagnostics.record('tool.approval', {
        'tool_call_id': toolCallId,
        'granted': allow,
        'status': updated.status.wire,
      });
      _onCall(updated, surface: a.surface, sessionId: sid);
      final now = _calls[toolCallId]!;
      if (!allow || updated.status != NexaToolCallStatus.awaitingClient) {
        if (now.phase == LabeebLocalPhase.approving) {
          _set(toolCallId, now.copyWith(phase: LabeebLocalPhase.idle));
        }
      }
    } on Object catch (e) {
      final code = gatewayErrorCode(e) ?? 'network_error';
      _set(
        toolCallId,
        _calls[toolCallId]!.copyWith(
          // A closed call stays closed; otherwise the user may try again.
          phase: code == 'tool_call_closed' || code == 'not_awaiting_approval'
              ? LabeebLocalPhase.failed
              : LabeebLocalPhase.awaitingUser,
          localError: code,
        ),
      );
    }
  }

  Future<void> _run(NexaToolCall c, LabeebDeviceTool tool) async {
    final shown = presenter();
    final context = shown != null && shown.mounted ? shown : null;
    final sid = _session(c.id);
    if (sid == null) return;
    NexaToolCallAnswer answer;
    if (tool.needsUi && context == null) {
      // No screen to show the camera/picker on: the deadline decides.
      _set(c.id, _calls[c.id]!.copyWith(phase: LabeebLocalPhase.awaitingUser));
      return;
    }
    try {
      answer = await tool.run(
        LabeebToolRunContext(
          context: context,
          upload: _upload,
          download: assetBytes,
          theme: host.theme,
          saveThemePreference: _saveTheme,
        ),
        c,
      );
    } on Object catch (e) {
      answer = NexaToolCallAnswer.failure(
        NexaToolCallError(
          gatewayErrorCode(e) ?? NexaDeviceErrorCodes.deviceError,
          retryable: true,
        ),
      );
    }
    await _answer(c, answer, sid);
  }

  Future<void> _answer(
    NexaToolCall c,
    NexaToolCallAnswer answer,
    String sid,
  ) async {
    if (!_answered.add(c.id)) return; // answer once
    _set(c.id, _calls[c.id]!.copyWith(phase: LabeebLocalPhase.answering));
    try {
      final updated = await api.answer(sid, c.id, answer);
      _diagnostics.record('tool.answered', {
        'tool_call_id': c.id,
        'tool': c.tool,
        'ok': answer.ok,
        if (!answer.ok) 'device_code': answer.error!.code,
        'status': updated.status.wire,
      });
      _set(
        c.id,
        _calls[c.id]!.copyWith(
          call: updated,
          phase: LabeebLocalPhase.answered,
          localError: answer.ok ? null : answer.error!.code,
        ),
      );
    } on Object catch (e) {
      final code = gatewayErrorCode(e) ?? 'network_error';
      _diagnostics.record('tool.answer_failed', {
        'tool_call_id': c.id,
        'gateway_code': code,
      });
      _set(
        c.id,
        _calls[c.id]!.copyWith(
          phase: LabeebLocalPhase.failed,
          localError: code,
        ),
      );
    }
  }

  /// Stops a running server call or long job (`POST .../cancel`).
  Future<String?> cancel(String toolCallId) async {
    final sid = _session(toolCallId);
    if (sid == null) return 'session_not_found';
    try {
      await api.cancelToolCall(sid, toolCallId);
      return null;
    } on Object catch (e) {
      return gatewayErrorCode(e) ?? 'network_error';
    }
  }

  void _set(String id, LabeebToolActivity a) {
    _calls[id] = a;
    notifyListeners();
  }

  // ------------------------------------------------------- assets and UI

  Future<String> _upload(Uint8List bytes, String mime, String? name) async {
    final cid = conversation();
    if (cid == null) {
      throw const ContractViolationException('conversation_required');
    }
    final ref = await api.uploadAsset(cid, bytes, mime: mime, filename: name);
    return ref.id;
  }

  Future<void> _saveTheme(String paletteId, NexaAppearance mode) async {
    try {
      final current = await api.preferences();
      await api.putPreferences({
        ...current,
        'theme.palette_id': paletteId,
        'theme.mode': mode.name,
      });
    } on Object catch (e) {
      // The host already persisted locally; the server copy is best effort.
      _diagnostics.record('theme.preference_failed', {
        'gateway_code': gatewayErrorCode(e),
      });
    }
  }

  /// Asset bytes (owner only), cached in memory for this conversation.
  Future<Uint8List> assetBytes(String assetId) {
    if (_bytes.length > 40) _bytes.remove(_bytes.keys.first);
    return _bytes.putIfAbsent(
      assetId,
      () => api.assetContent(assetId).catchError((Object e) {
        _bytes.remove(assetId);
        throw e;
      }),
    );
  }

  void onAsset(
    NexaAssetRef ref, {
    String? toolCallId,
    NexaItemSurface surface = NexaItemSurface.chat,
    DateTime? at,
  }) {
    if (toolCallId != null) {
      final a = _calls[toolCallId];
      if (a != null && a.assets.every((x) => x.id != ref.id)) {
        _calls[toolCallId] = a.copyWith(assets: [...a.assets, ref]);
      }
    }
    if (media.items.any((i) => i.id == 'ast:${ref.id}')) return;
    media.add(
      NexaAssetItem(
        id: 'ast:${ref.id}',
        createdAt: at ?? DateTime.now().toUtc(),
        asset: ref,
        toolCallId: toolCallId,
        surface: surface,
      ),
    );
    notifyListeners();
  }

  /// A presented document; a truncated (voice) one is read in full from
  /// its tool call. Malformed documents are dropped, never rendered.
  void onUi(
    Map<String, Object?> json, {
    String? toolCallId,
    NexaItemSurface surface = NexaItemSurface.chat,
    String? sessionId,
    DateTime? at,
  }) {
    NexaUiDocument doc;
    try {
      doc = parseNexaUiDocument(
        json,
        toolCallId: toolCallId,
        extensionTypes: host.uiComponents.keys.toSet(),
      );
    } on NexaUiDocumentException catch (e) {
      _diagnostics.record('ui.rejected', {'reason': e.reason});
      return;
    }
    if (sessionId != null && toolCallId != null) {
      _sessionOf[toolCallId] = sessionId;
    }
    final fresh = !_documents.containsKey(doc.id);
    _documents[doc.id] = doc;
    if (fresh) {
      media.add(
        NexaUiDocumentItem(
          id: 'ui:${doc.id}',
          createdAt: at ?? DateTime.now().toUtc(),
          uiId: doc.id,
          surface: surface,
        ),
      );
    }
    notifyListeners();
    if (doc.truncated && toolCallId != null) unawaited(_loadFull(doc));
  }

  Future<void> _loadFull(NexaUiDocument doc) async {
    final sid = _session(doc.toolCallId!);
    if (sid == null) return;
    try {
      final call = await api.toolCall(sid, doc.toolCallId!);
      final ui = call.result?['ui'];
      if (ui is Map) {
        final full = parseNexaUiDocument(
          ui.cast<String, Object?>(),
          toolCallId: doc.toolCallId,
          extensionTypes: host.uiComponents.keys.toSet(),
        );
        _documents[doc.id] = full;
        notifyListeners();
      }
    } on Object catch (e) {
      _diagnostics.record('ui.full_failed', {
        'gateway_code': gatewayErrorCode(e),
      });
    }
  }

  // ------------------------------------------------- nexa.ui/1 selections

  /// The local value of [componentId] in document [uiId] (option ids,
  /// switch/slider/input value), optimistic until the assistant answers.
  Object? uiValue(String uiId, String componentId) =>
      _uiValues[uiId]?[componentId];

  void setUiValue(String uiId, String componentId, Object? value) {
    _uiValues.putIfAbsent(uiId, () => {})[componentId] = value;
    notifyListeners();
  }

  /// Sends [event]; returns the gateway error code when refused.
  Future<String?> sendUiEvent(NexaUiEvent event) async {
    final sink = uiEventSink;
    if (sink == null) return 'unavailable';
    return sink(event);
  }

  // ------------------------------------------------------ history resume

  final Map<String, Timer> _recovering = {};
  int _generation = 0;

  /// Restores the media of a reopened conversation from its history
  /// messages (`message_parts`): attachments and generated files, deleted
  /// files, tool results and errors, and presented documents. Restored
  /// calls never run or ask again; a job still `running` is followed with
  /// `GET .../tool-calls/{id}` in its original session until it ends.
  void restore(List<LabeebMessage> messages) {
    final requests = <String, (NexaToolCall, LabeebMessage)>{};
    final done = <String>{};
    for (final m in messages) {
      final at = m.createdAt ?? DateTime.now().toUtc();
      final sid = m.sessionId;
      for (final (i, p) in m.parts.indexed) {
        switch (p['type']) {
          case 'image' || 'file':
            if (NexaAssetRef.fromPart(p) case final ref?) {
              onAsset(ref, at: at);
            }
          case 'deleted_asset':
            onAsset(NexaAssetRef.deleted('${m.id}:$i'), at: at);
          case 'tool_request':
            if (NexaToolCall.fromJson({...p, 'status': 'unknown'})
                case final c?) {
              requests[c.id] = (c, m);
            }
          case 'tool_result' || 'tool_error':
            final c = NexaToolCall.fromJson({
              ...p,
              'status': p['type'] == 'tool_error'
                  ? 'failed'
                  : p['status'] ?? 'unknown',
            });
            if (c == null) continue;
            done.add(c.id);
            final known = requests[c.id]?.$1;
            _restoreCall(
              NexaToolCall(
                id: c.id,
                tool: c.tool,
                status: c.status,
                arguments: known?.arguments ?? c.arguments,
                result: c.result,
                error: c.error,
                asynchronous: c.status == NexaToolCallStatus.running,
              ),
              at: requests[c.id]?.$2.createdAt ?? at,
              sessionId: sid,
            );
            if (c.result?['ui'] case final Map<Object?, Object?> ui) {
              onUi(
                ui.cast<String, Object?>(),
                toolCallId: c.id,
                sessionId: sid,
                at: at,
              );
            }
        }
      }
    }
    // A request without a stored result: only its live status says what
    // happened (expired, still running…); nothing is assumed.
    for (final MapEntry(key: id, value: (c, m)) in requests.entries) {
      if (done.contains(id) || m.sessionId == null) continue;
      unawaited(_follow(id, m.sessionId!, at: m.createdAt, request: c));
    }
  }

  void _restoreCall(
    NexaToolCall c, {
    required DateTime at,
    required String? sessionId,
  }) {
    if (sessionId != null) _sessionOf[c.id] = sessionId;
    _answered.add(c.id); // history is never executed or answered again
    final existing = _calls[c.id];
    _calls[c.id] =
        existing?.copyWith(call: c) ??
        LabeebToolActivity(call: c, firstSeen: at);
    if (existing == null) {
      media.add(
        NexaToolCallItem(id: 'tc:${c.id}', createdAt: at, toolCallId: c.id),
      );
    }
    notifyListeners();
    if (!c.status.terminal && sessionId != null) {
      unawaited(_follow(c.id, sessionId, at: at));
    }
  }

  /// Reads a restored call until it is terminal (5 s, slowing to 30 s).
  Future<void> _follow(
    String id,
    String sessionId, {
    DateTime? at,
    NexaToolCall? request,
    int attempt = 0,
  }) async {
    _recovering.remove(id)?.cancel();
    final generation = _generation;
    try {
      final c = await api.toolCall(sessionId, id);
      if (generation != _generation) return; // conversation changed
      _restoreCall(c, at: at ?? DateTime.now().toUtc(), sessionId: null);
      if (c.status.terminal) {
        _diagnostics.record('tool.recovered', {
          'tool_call_id': id,
          'status': c.status.wire,
        });
        if (c.result?['ui'] case final Map<Object?, Object?> ui) {
          onUi(ui.cast<String, Object?>(), toolCallId: id, at: at);
        }
        if (c.status == NexaToolCallStatus.succeeded) {
          await _restoreRecentAssets();
        }
        return;
      }
    } on Object catch (e) {
      if (generation != _generation) return;
      final code = gatewayErrorCode(e);
      _diagnostics.record('tool.recover_failed', {
        'tool_call_id': id,
        'gateway_code': code,
      });
      final a = _calls[id];
      if (a != null) {
        _set(id, a.copyWith(localError: code ?? 'network_error'));
      }
      // No scope / no such call: the status cannot be read; stop asking.
      if (code == 'forbidden' ||
          code == 'tool_call_not_found' ||
          code == 'session_not_found' ||
          code == 'not_found') {
        return;
      }
    }
    if (attempt >= 120) return;
    final delay = Duration(seconds: (5 + attempt * 5).clamp(5, 30));
    _recovering[id] = Timer(
      delay,
      () => unawaited(
        _follow(id, sessionId, at: at, request: request, attempt: attempt + 1),
      ),
    );
  }

  /// A recovered job finished: its file is in the newest messages.
  Future<void> _restoreRecentAssets() async {
    final cid = conversation();
    if (cid == null) return;
    try {
      final page = await api.messages(cid, limit: 20);
      for (final m in page.items) {
        for (final p in m.parts) {
          if (NexaAssetRef.fromPart(p) case final ref?) {
            onAsset(ref, at: m.createdAt);
          }
        }
      }
    } on Object catch (e) {
      _diagnostics.record('tool.recover_assets_failed', {
        'gateway_code': gatewayErrorCode(e),
      });
    }
  }

  /// Deletes an asset the user owns (`DELETE /assets/{id}`); the item
  /// becomes the "deleted" placeholder. Returns the gateway error code.
  Future<String?> deleteAsset(String assetId) async {
    try {
      await api.deleteAsset(assetId);
    } on Object catch (e) {
      final code = gatewayErrorCode(e) ?? 'network_error';
      if (code != 'asset_not_found') return code;
    }
    _bytes.remove(assetId)?.ignore();
    for (final MapEntry(:key, :value) in _calls.entries.toList()) {
      if (value.assets.any((x) => x.id == assetId)) {
        _calls[key] = value.copyWith(
          assets: [
            for (final x in value.assets)
              x.id == assetId ? NexaAssetRef.deleted(assetId) : x,
          ],
        );
      }
    }
    final item = media.items.whereType<NexaAssetItem>().where(
      (i) => i.asset.id == assetId,
    );
    for (final it in item.toList()) {
      media.replace(
        NexaAssetItem(
          id: it.id,
          createdAt: it.createdAt,
          asset: NexaAssetRef.deleted(assetId),
          toolCallId: it.toolCallId,
          surface: it.surface,
        ),
      );
    }
    notifyListeners();
    return null;
  }

  /// Forgets everything (new conversation).
  void reset() {
    for (final t in _recovering.values) {
      t.cancel();
    }
    _recovering.clear();
    _generation++;
    _calls.clear();
    _documents.clear();
    _sessionOf.clear();
    _answered.clear();
    _uiValues.clear();
    _bytes.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_completed.close());
    for (final t in _recovering.values) {
      t.cancel();
    }
    _recovering.clear();
    super.dispose();
  }
}
