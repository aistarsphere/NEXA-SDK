# LABEEB Beta Mobile — Master Implementation Plan

Version 1.0, 2026-11-03. Executes the requirements in `MOBILE_BETA_REQUIREMENTS.md` against the findings in `MOBILE_ARCHITECTURE_AUDIT.md`. The implementing session reads `.ai/mobile.md` first, then this file, and works tasks in order unless a dependency note says otherwise. Progress is tracked in `MOBILE_IMPLEMENTATION_STATUS.md`.

## 0. Ground rules for the implementing agent

1. **Do not rewrite.** Every task below extends an existing class or adds a small new one. If a task seems to require replacing a package, stop and record the reason in the status file.
2. **Keep the app runnable after every task.** Each task ends with `tool/check.sh` green (or the targeted subset named in the task) and no behaviour change outside its scope.
3. **Evidence discipline.** A task is `DONE` only when its Definition of Done (DoD) is met and the evidence link is in the status file. Device claims need a device log/screenshot path under `docs/qa/evidence/`.
4. **Backend gaps** (`G-xx`, audit §4) are never worked around by inventing an endpoint. Implement the client side behind a capability check and record `BLOCKED_BACKEND`.
5. **Conventions** (from `.ai/mobile.md`): package boundaries, `NexaException` only, no Flutter in `nexa_core`, no `livekit_client` outside `nexa_realtime`, strings in ARB, directional layout APIs, time via `clock`, ids via `uuid`, tests at the lowest layer.
6. **Commit granularity:** one commit per task id, message `M-xx: <task id> <summary>`; never push; never commit secrets (`config/*.json` is ignored).
7. The uncommitted wake-word benchmark files are committed first as task **F-01** (no behaviour change, dev-only) so no later task collides with them. Do this before A-01.

## 1. Execution order and dependency graph

```
F-01 (commit bench)        ← first, isolated
Phase A  A-01 ConversationCoordinator ─► A-02 route graph ─► A-03 call lifecycle service ─► A-04 app lifecycle hooks
Phase B  B-01 conversation list root (needs A-01, A-02) ─► B-02 cache keyed by conv_* + account (needs A-01) ─► B-03 older pages
Phase C  C-01 post-call reconcile (needs A-01, B-02) ─► C-02 voice turns in timeline ─► C-03 tool stage in capsule ─► C-04 honest barge-in label ─► C-05 reconnect/background polish (needs A-03, A-04)
Phase D  D-01 pending tool state persistence (needs B-02) ─► D-02 ui_event in-flight guard + voice ui_event sink ─► D-03 unknown/expired/fallback states ─► D-04 migrate theme picker to nexa.ui/1 and remove legacy surfaces
Phase E  E-01 mute finalisation (needs C-01 evidence from T-M07-01) ─► E-02 rapid-toggle debounce ─► E-03 Bluetooth/route/focus (needs A-03) ─► E-04 barge-in evidence + backend request
Phase F  F-02 wake engine interface + Porcupine spike ─► F-03 speech-embedding classifier spike ─► F-04 speaker-verification calibration + consent ─► F-05 assistant cold-start policy (needs A-01)
Phase G  G-01 perf baseline ─► G-02 a11y device pass ─► G-03 release hardening ─► G-04 crash/diagnostics hook ─► G-05 CI script
```

Ordering rationale (changed from the brief where the code dictates it): Phase B's list root depends on the coordinator and route graph (A), so A stays first. The in-call foreground service (A-03) is placed in Phase A, not E, because C-05 (background reconnect), E-03 (routing) and the device acceptance of M-02 all depend on it. E-01 waits for the device evidence of T-M07-01 so that we build the right fix. No cycles: every arrow points forward.

---

## Phase A — Architecture foundation and navigation

### A-01 ConversationCoordinator (single owner of the conversation id)

| Field | Content |
|---|---|
| Priority | P0 (M-01, M-02, M-04) |
| User problem | Duplicate conversations after retries; call pages and chat pages disagree about "the current conversation"; nothing knows when a conversation changed |
| Root cause | `SessionManager.conversationId` is mutated by `NexaClient.newConversation/resumeConversation`, `SessionManager._start` and `NexaVoiceController._connect`; `client_ref` is regenerated per attempt (`nexa.dart:201-216`) |
| Target files | new `packages/nexa_sdk/lib/src/features/conversation/conversation_coordinator.dart`; edit `nexa.dart`, `session_manager.dart`, `nexa_voice_controller.dart`, `nexa_assistant_view.dart`, `sdk_module.dart` (register), `nexa_sdk.dart` (export) |
| Design | `final class ConversationCoordinator extends ChangeNotifier` owning: `String? conversationId`, `String? _pendingClientRef`, `int lastKnownSeq`, `bool resumePending`, `Stream<ConversationChanged>`. API: `Future<String> ensureConversation({required String reason})` (creates with a **stable** `client_ref` kept until success, serialised with a single in-flight future); `Future<void> open(String id)` (= resume); `Future<void> startNew()`; `void noteSeq(int seq)`; `Future<List<ChatMessage>> fetchSince()` (C-01). `SessionManager.conversationProvider` and `NexaVoiceController` call `ensureConversation` instead of their own logic. |
| Pseudocode | ```dart
Future<String> ensureConversation({required String reason}) {
  if (conversationId case final id?) return Future.value(id);
  return _creating ??= () async {
    _pendingClientRef ??= '${installation.id}:${uuid.v4()}';   // stable across retries
    try {
      final c = await api.createConversation(kind: 'chat', clientRef: _pendingClientRef);
      conversationId = c.id; _pendingClientRef = null; lastKnownSeq = 0;
      diagnostics.record('conversation.created', {'reason': reason, 'id': c.id});
      notifyListeners(); return c.id;
    } finally { _creating = null; }
  }();
}
``` |
| Contracts | `POST /v1/sdk/conversations {kind, client_ref}` (idempotent per `client_ref`, contract 1.0.0) |
| Backend deps | none |
| Compatibility | `NexaClient.conversationId` keeps returning the same value; `SessionManager.conversationId` becomes a getter delegating to the coordinator (keep the setter for tests one release, marked `@Deprecated`) |
| Tests | unit: stable `client_ref` across 3 failed attempts then success (mocktail `LabeebSdkClient`); concurrent `ensureConversation` from chat + voice → one POST; `startNew` clears id and seq; existing `history_identity_test.dart`, `voice_controller_test.dart` stay green |
| Device acceptance | start app offline, tap Call, go online within 10 s → exactly one conversation in `GET /conversations` |
| DoD | all callers routed through the coordinator; `grep -rn "conversationId = " packages/nexa_sdk/lib` shows only the coordinator (the `SessionManager.conversationId` setter is `@Deprecated` and delegates); `SessionManager.canCreateConversation` replaces the `conversationProvider != null` guard in the voice controller (panel cold start); tests above green. Implemented 2026-11-03: the coordinator is built in `NexaClient` (needs `LabeebSdkClient`, which is not in DI); `conversationProvider` remains as a fallback for hosts/tests without a coordinator |
| Depends on | F-01 |
| Rollback | the class is additive; revert the three call-site edits |
| Out of scope | UI, history list |

### A-02 Route graph owned by the app (go_router), SDK exposes pages

| Field | Content |
|---|---|
| Priority | P0 (M-02) |
| User problem | Double voice pages; call from the splash returns to the splash; three navigation owners |
| Root cause | `NexaAssistantView` pushes `MaterialPageRoute`s on the host navigator (`nexa_assistant_view.dart:76-87,448-475`); the header voice button has no guard |
| Target files | `apps/nexa_example/lib/main.dart` (routes), new `apps/nexa_example/lib/assistant/labeeb_router.dart`, `packages/nexa_sdk/lib/src/features/assistant/nexa_assistant_view.dart` (expose `NexaAssistantPages`), `nexa_assistant_options.dart` |
| Design | Routes: `/` (conversation list, B-01; until B-01 lands it is the current chat page), `/c/:conversationId` (chat), `/c/:conversationId/call` (call, `fullscreenDialog`), `/history` (optional alias), `/settings`, `/settings/assistant`, dev `/dev/*`. The SDK gains `NexaAssistantPages` with `Widget chatPage(...)`, `Widget callPage(...)`, `Widget historyPage(...)` and **callbacks** `onOpenChat(conversationId)`, `onOpenCall(conversationId)`, `onCallEnded(conversationId)` so the host router decides. Internal pushes remain only for sheets/dialogs. Re-entrancy: `GoRouter` guards `/call` by checking `state.uri` equality (`if (router.state.uri.path.endsWith('/call')) return;`). Call page `onClose` → `context.pop()`; `dispose` still ends the call. "Call from root" = `await coordinator.ensureConversation(reason: 'call_from_root')` then `go('/c/$id/call')`; on end → `pop` lands on `/c/$id`. |
| Pseudocode | ```dart
// labeeb_router.dart
GoRoute(path: '/c/:id', builder: (c, s) => pages.chatPage(conversationId: s.pathParameters['id']!),
  routes: [GoRoute(path: 'call', pageBuilder: (c, s) => CustomTransitionPage(fullscreenDialog: true,
     child: pages.callPage(conversationId: s.pathParameters['id']!, onClose: () => c.pop()), ...))]);
// re-entrancy
void openCall(BuildContext c, String id) {
  final r = GoRouter.of(c); if (r.state.uri.path == '/c/$id/call') return; r.push('/c/$id/call');
}
``` |
| Contracts | none |
| Compatibility | `assistantView()` stays for third-party hosts (it wraps `NexaAssistantPages` with the old in-SDK pushes); LABEEB uses the new pages. `voiceRequests` stream now maps to `onOpenCall` via the host |
| Tests | widget: double tap on voice → one `/c/x/call` entry; back from call → `/c/x`; root call → `/c/new/call` → end → `/c/new`; history resume → `/c/y` with remount; existing `assistant_test.dart`, `app_smoke_test.dart` updated |
| Device acceptance | T-M02-01..04 |
| DoD | no `Navigator.push` of full pages inside `nexa_assistant_view.dart` for LABEEB's path; router test file added |
| Implemented 2026-11-03 | `onOpenCall(context, {fromHome})` + `NexaAssistantView.callPage/chatPage`; SDK-pushed path kept for third-party hosts with a per-client guard (`_callRouteOpen`) and home→chat→call ordering; app `openLabeebCall` (single in-flight, `router.state` check, ensureConversation, `new` when offline/mock); `/c/:id` resumes via `RouteConversation` (microtask, never in build); coordinator is always attached and `canCreate` only on a real gateway |
| Depends on | A-01 |
| Rollback | keep `assistantView()` path; switch `AssistantPage` back |
| Out of scope | list screen design (B-01) |

### A-03 In-call foreground service and notification (Android)

| Field | Content |
|---|---|
| Priority | P0 (M-12.2, M-03.5) |
| User problem | A call dies or goes silent when the user switches apps or locks the phone |
| Root cause | no foreground service holds the microphone for calls; `flutter_webrtc`/`livekit_client` ship none |
| Target files | `packages/nexa_assistant/android/src/main/kotlin/com/nexa/assistant/CallForegroundService.kt` (new), `AndroidManifest.xml` (plugin: `<service android:foregroundServiceType="microphone|mediaPlayback">`), `NexaAssistantPlugin.kt` (methods `callStarted(title, conversationId)`, `callEnded()`), Dart `packages/nexa_assistant/lib/src/nexa_assistant.dart`, app `apps/nexa_example/lib/assistant/device_assistant.dart` (bridge: listen to `client.voice.state`, start when `isActive`, stop when not) |
| Design | Start the service **only while the activity is resumed** (Android 14+ rule); if `start()` throws `ForegroundServiceStartNotAllowedException` record `call.fgs_blocked` and continue (call still works in foreground). Notification: channel `nexa_call`, title "LABEEB call", action "End call" (PendingIntent → plugin → Dart `voice.end()`), `setOngoing(true)`, category `CALL`. `START_NOT_STICKY`. Stop in `callEnded` and in `onTaskRemoved` (end the call: send a `voice_end_requested` event to Dart; if the engine is gone, nothing to do; the server ends it by `idle_timeout`). The wake listener stays paused during calls (existing `followMicrophoneUse`). |
| Contracts | none |
| Compatibility | plugin method additive; hosts without the plugin unaffected |
| Tests | Kotlin: none (service wiring); Dart unit: `DeviceAssistant` starts/stops the service on state transitions (mock plugin); app widget test unchanged |
| Device acceptance | T-M12-02: 2-minute backgrounded call on Android 16 stays audible both ways; notification "End call" ends it (`DELETE 200`) |
| DoD | `dumpsys activity services` shows the service only during calls; evidence file |
| Depends on | A-02 (call page route known), none for the plugin |
| Rollback | feature flag `NexaAssistantOptions.callForegroundService` default on; set off |
| Out of scope | iOS (already `UIBackgroundModes audio`) |

### A-04 App lifecycle hooks for calls

| Field | Content |
|---|---|
| Priority | P1 (M-02.5, M-12) |
| User problem | Nothing records that the app went to background during a call; UI state after return is stale |
| Target files | `packages/nexa_sdk/lib/src/features/voice/nexa_voice_lifecycle.dart` (new, `WidgetsBindingObserver`), `nexa_voice_controller.dart` (`notePaused()/noteResumed()`), `QaRecorder` already records lifecycle |
| Design | On `paused`: diagnostics `voice.app_paused {phase}`; start a 25 s timer (= `reconnect.grace_seconds − 5`); if still paused and `phase.isActive` and **no** foreground service is held (A-03 reported blocked), end the call deliberately with `endReason: 'background'` so the server is not left to `idle_timeout`. On `resumed`: if `phase == reconnecting` trigger `_recover()` immediately; refresh `transport.isMicrophoneEnabled` into state (honesty). |
| Tests | unit with `TestWidgetsFlutterBinding.handleAppLifecycleStateChanged` |
| Device acceptance | T-M02-05 |
| DoD | diagnostics show `voice.app_paused/resumed`; behaviour matrix documented in `.ai/mobile.md` |
| Depends on | A-03 |

---

## Phase B — Unified conversations and history

### B-01 Conversation list as the root screen

| Field | Content |
|---|---|
| Priority | P0 (M-01.1) |
| Target files | new `packages/nexa_sdk/lib/src/features/history/nexa_conversation_list_page.dart` (reuses `NexaHistoryController`, `NexaHistoryView` list item), `nexa_assistant_options.dart` (`NexaLaunchMode.list` default for LABEEB), `apps/nexa_example/lib/main.dart` (`/` → list), ARB strings (`listTitle`, `listNew`, `listCall`, `listEmptyBody`) |
| Design | AppBar: brand + settings. Body: `refresh()` on mount; items from `history.entries` (server-backed) with cached entries shown greyed while loading; pull-to-refresh; infinite `loadMore`. Primary FAB "New conversation" → `coordinator.startNew()` → `go('/c/new')` where `new` resolves lazily: the chat page shows the composer and the id is created on first send (A-01 `ensureConversation(reason:'first_message')`). Secondary action "Call" → `ensureConversation(reason:'call_from_list')` → `/c/$id/call`. Tap item → `coordinator.open(id)` → `/c/$id`. Empty state: brand mark + two buttons (reuse `_HomePage` visuals). |
| Pseudocode | ```dart
onNew: () async { await coordinator.startNew(); context.go('/c/new'); }
onCall: () async { final id = await coordinator.ensureConversation(reason: 'call_from_list'); context.go('/c/$id'); context.push('/c/$id/call'); }
onTap(entry): () async { await coordinator.open(entry.id); context.go('/c/${entry.id}'); }
``` The chat page accepts `conversationId == 'new'` and binds to the coordinator's future id. |
| Contracts | `GET /v1/sdk/conversations` (E2E_VERIFIED) |
| Tests | widget: empty/loading/error/list; tap → route; FAB → `/c/new`; RTL golden |
| Device acceptance | T-M01-03 |
| DoD | LABEEB opens on the list; `NexaLaunchMode.chat` still works for hosts |
| Depends on | A-01, A-02 |
| Out of scope | search over server (client search of loaded items stays) |

### B-02 Cache keyed by `conv_*`, account-scoped, no `vs_*` rows

| Field | Content |
|---|---|
| Priority | P0 (M-01.5, M-15.2) |
| Root cause | audit F-01.4, F-15.3 |
| Target files | `nexa_history.dart` (`_record`, `recordChat`, `recordVoice`, `NexaHistoryOptions.scope`), `nexa_assistant_view.dart:538-543` (stop `recordVoice` when server-backed), `apps/nexa_example/lib/main.dart` (cache file path includes an `accountKey`), `NexaHistoryEntry` (add `conversationId`; keep `sessionId` as deprecated alias) |
| Design | `recordChat` keys by `coordinator.conversationId` (not `ses_*`); `recordVoice` is only used when `!serverBacked` and then records under the conversation id with `kind: mixed`. `NexaHistoryOptions.accountKey` (String, default `'default'`) selects the cache file `history_<sha256(accountKey).first8>.json`; `NexaClient.dispose()` does **not** delete other accounts' files; a new `NexaClient.clearLocalData({required accountKey})` deletes this account's cache, media and theme file. Migration: on first load, a file with legacy `session_id` rows starting with `vs_`/`ses_` is dropped (cache only). |
| Tests | unit: entries keyed by conv id; two account keys → two files; migration drops legacy rows; `history_identity_test.dart` updated |
| DoD | no `vs_` key written in a server-backed run (assert in test); T-M15-02 |
| Depends on | A-01 |

### B-03 Older message pages on resume

| Field | Content |
|---|---|
| Priority | P2 (M-01.2) |
| Target files | `chat_bloc.dart` (`ChatOlderRequested` event, `before_seq` paging), `nexa_chat_view.dart` (top-of-list loader) |
| Design | first page 100 (existing); scrolling to the top with `nextBefore != null` loads the previous 100 and prepends with dedupe by id |
| Tests | bloc test with mocked loader; widget scroll test |
| Depends on | B-01 |

---

## Phase C — Realtime calls and transcript synchronisation

### C-01 Post-call reconciliation into the open chat

| Field | Content |
|---|---|
| Priority | P0 (M-04.2) |
| Root cause | audit F-04.2 |
| Target files | `conversation_coordinator.dart` (`fetchSince`), `chat_bloc.dart` (`ChatHistoryMerged` event + `_merge`), `chat_event.dart`, `conversation_reducer.dart` (`mergePersisted(messages)` pure), `nexa_assistant_view.dart` / call page `onClose`, `labeeb_sdk_client.dart` (`messages(afterSeq:)` when G-01 lands) |
| Design | When the call page closes (and on `resumed` after a background call ends), the coordinator fetches the newest page `GET …/messages?limit=50` (until G-01 provides `after_seq`), filters `seq > lastKnownSeq` or unknown ids, and the bloc merges them: existing ids are updated, new ones inserted by `createdAt` then `seq`; messages with `channel == 'voice'` get `ChatMessage.origin = MessageOrigin.voice` (new enum field, default `text`) so the bubble shows a small mic glyph. `lastKnownSeq` is updated from every accepted SSE event (`noteSeq`) and from merged messages. Dedupe rules: id equality; else same role + same text + `createdAt` within 2 s (covers the client-posted turn vs gateway-recorded message case). |
| Pseudocode | ```dart
ConversationState mergePersisted(ConversationState s, List<ChatMessage> fetched) {
  final byId = {for (final m in s.messages) m.id: m};
  final out = [...s.messages];
  for (final f in fetched) {
    if (byId.containsKey(f.id)) continue;
    final dup = out.any((m) => m.role == f.role && m.text == f.text && (m.createdAt.difference(f.createdAt)).abs() < 2s);
    if (!dup) out.add(f);
  }
  out.sort((a,b) { final c = a.createdAt.compareTo(b.createdAt); return c != 0 ? c : (a.seq ?? 0).compareTo(b.seq ?? 0); });
  return s.copyWith(messages: out);
}
``` |
| Contracts | `GET /conversations/{id}/messages` (deployed); G-01 requested |
| Tests | reducer unit (dedupe, ordering, origin); bloc test `ChatHistoryMerged`; integration against the reference gateway (extend `ReferenceGateway` to record voice turns into messages — dev infra change allowed) |
| Device acceptance | T-M04-01 |
| DoD | 3-turn call → 6 bubbles in chat within 2 s of close, once |
| Depends on | A-01, B-02 |

### C-02 Live voice turns visible in the chat timeline during a call (optional for Beta)

| Field | Content |
|---|---|
| Priority | P2 |
| Design | `NexaConversationMedia` already shares items between chat and voice; add `NexaTranscriptRefItem` rendering (currently `SizedBox.shrink()` in `nexa_chat_view.dart:327`) as a compact "Voice call in progress · n turns" card that opens the call route |
| Depends on | C-01 |

### C-03 Tool stage in the full call capsule

| Field | Content |
|---|---|
| Priority | P1 (M-03.3) |
| Target files | `nexa_voice_capsule.dart` (`toolLabel` param), `nexa_voice_view.dart` (compute from `client.toolCalls.activities` like the panel does), ARB |
| Design | same rule as `nexa_compact_voice_panel.dart:216-230`: when a call-scoped tool is `running`/`awaiting_*` and phase is not `aiSpeaking`/`userSpeaking`, the label is "Working: <tool title>" and the orb mode `tool` |
| Tests | widget `voice_view_test.dart` |
| Depends on | none |

### C-04 Honest barge-in label

| Field | Content |
|---|---|
| Priority | P1 (M-08.2) |
| Target files | `voice_session_machine.dart:169-173`, ARB (`voiceStateBargeIn` → "Listening to you…" until confirmed; new `voiceStateInterrupted`), capsule/orb mapping |
| Design | keep the `bargeIn` state (needed for `StopPlayback`/`SendInterrupt` commands) but add `interruptConfirmed: bool` to `NexaVoiceState`, set on `RealtimeInterrupted`; the label reads "Interrupting…" only when confirmed |
| Tests | machine totality test unchanged; controller test: `user_speech_started` during `aiSpeaking` → label listening; `interrupted` → label interrupting |
| Depends on | none |

### C-05 Reconnect and background polish

| Field | Content |
|---|---|
| Priority | P1 |
| Design | on `resumed` with `reconnecting` → immediate `_recover()`; after `_recover` outcome `rejoined` emit a live-region "Reconnected"; unify the `weakNetwork` banner with the `reconnecting` chip; add `endReason: 'background'` string |
| Depends on | A-03, A-04 |

---

## Phase D — Tool calling and Dynamic UI

### D-01 Persist pending tool-workflow state per conversation

| Field | Content |
|---|---|
| Priority | P1 (M-06) |
| Root cause | audit F-06.3 |
| Target files | `labeeb_tool_calls.dart` (`exportState()/importState()`), new `packages/nexa_sdk/lib/src/features/tools/labeeb_pending_store.dart` (JSON file per account+conversation: `{tool_call_id: {session_id, status, surface, ui_values, seen_at}}`, ≤ 50 entries, ≤ 7 days), `nexa.dart` (wire on `resumeConversation`/startup), `main.dart` (store path) |
| Design | write on every `_set`/`setUiValue` (debounced 500 ms); on `open(conversationId)` import, then `restore(messages)` runs as today and `_follow` uses the persisted `session_id` when the message part lacks one. Never persists arguments/results (they come from the server). When G-06 lands, prefer the server list and drop the file. |
| Tests | unit: kill-restore round trip; voice-raised call answered after restore using persisted `tools.session_id` |
| Device acceptance | T-M06-01/02 |
| Depends on | B-02 |

### D-02 `ui_event` in-flight guard and voice-only selection sink

| Field | Content |
|---|---|
| Priority | P1 (M-05.3, F-05.4/F-05.5) |
| Target files | `labeeb_tool_calls.dart` (`Set<String> _uiInFlight` keyed `ui_id:component_id`), `nexa_ui_view.dart` (disable while in flight, show progress), `nexa.dart` (default `uiEventSink`: if no chat view is mounted, open a chat session on the coordinator's conversation via `SessionManager.start()` and send through the transport — the gateway accepts `ui_event` on `POST /sessions/{id}/messages`; **verify** with T-M05-05 that a voice-time `ui_event` on the chat session is accepted; if `409 voice_session` is returned, record `BLOCKED_BACKEND` and keep "Show options → expand") |
| Tests | unit: double tap sends once; sink fallback chooses the chat session |
| Depends on | A-01 |

### D-03 Unknown component fallback, expired actions, loading/error states

| Field | Content |
|---|---|
| Priority | P1 (M-05.4) |
| Target files | `nexa_ui_view.dart`, `nexa_ui_document.dart` (`fallbackText` from `raw['fallback_text']`), ARB (`duiExpired`, `duiUnavailable`) |
| Design | a document whose root was skipped shows `fallback_text`; `422 unknown_ui_component` marks the document `expired` (greyed, label); each actionable component shows a 16 dp progress while in flight and an inline error with Retry on network errors |
| Tests | widget for the three states in `ar` and `en`; semantics labels assert |
| Depends on | D-02 |

### D-04 Migrate the host theme picker to `nexa.ui/1`; remove legacy surfaces

| Field | Content |
|---|---|
| Priority | P2 |
| Target files | `nexa.dart:264-284` (`showThemePicker` builds a `nexa.ui/1` document with `palette` options from `host.theme`), then delete `nexa_surface_controller.dart`, `nexa_surface_view.dart`, `nexa_surface_presentation.dart`, `dynamic_surface.dart`, `demo_surfaces.dart`, `dynamic_ui_gallery_page.dart` after their tests are ported |
| DoD | one renderer; −2 k lines; `dynamic_ui_test.dart` covers the picker |
| Depends on | D-03 |

---

## Phase E — Mute, barge-in and audio reliability

### E-01 Mute finalisation (deliberate handling of the pending utterance)

| Field | Content |
|---|---|
| Priority | P0 (M-07.2, M-07.4) |
| Prerequisite evidence | run **T-M07-01** on the current build first: say a full sentence, tap Mute within 0.3 s of finishing, wait 10 s. Record whether `user_speech_ended` + final `transcript` + a reply arrive. If they arrive, E-01 is reduced to tests + docs; if not, implement the grace window below and file G-02 |
| Target files | `voice_session_machine.dart` (new state `mutePending` or a `SetTransportMuted(deferred: true)` command), `nexa_voice_controller.dart` (`_muteGrace` timer), `nexa_voice_state.dart` (`muted` = user intent, `micOpen` = real track state), capsule/panel (show "Muting…" while grace runs), `NexaVoiceOptions.muteGrace` (default 1200 ms, 0 disables) |
| Design | On `VoiceMuteToggled(true)`: set `muted: true` immediately (UI), and: if phase ∈ {`userSpeaking`, `transcribing`} start a grace timer (≤ `muteGrace`) during which capture continues; the timer is cancelled and the track disabled as soon as `user_speech_ended` **or** a final `transcript` arrives, or the grace elapses. In any other phase disable the track immediately (as today). Unmute during grace cancels the timer and keeps the track enabled. Privacy: the grace is bounded, visible ("Muting…"), and never exceeds 1.2 s. Rationale: the server VAD needs trailing frames to end the turn (audit F-07.3); the client cannot send an end-of-turn signal (contract §4). |
| Pseudocode | ```dart
case SetTransportMuted(muted: true, deferred: true):
  _muteGrace?.cancel();
  _muteGrace = Timer(options.muteGrace, () => unawaited(_applyMute()));
case VoiceUserSpeechEnded() || VoiceTranscriptFinal() when _muteGrace != null:
  _muteGrace!.cancel(); await _applyMute();
Future<void> _applyMute() async { await _transport.setMicrophoneEnabled(enabled: false); _set(state.copyWith(micOpen: false)); }
``` |
| Contracts | none client-side; G-02 requested for the backend to commit on `TrackMuted` (then `muteGrace` can be 0) |
| Tests | machine: new transitions total; controller: grace cancelled by `user_speech_ended`; grace elapses → mute; unmute during grace; mute mid-utterance (phase `userSpeaking`, no events) → mute after grace; reconnect while muted re-applies; existing "mute reaches the microphone in every live state" extended for the deferred path |
| Device acceptance | T-M07-01..06 with `dumpsys audio` + agent event log |
| DoD | all six scripted cases pass on Xiaomi; evidence committed |
| Depends on | C-01 (so the answered turn shows in chat) |
| Rollback | `muteGrace: Duration.zero` restores today's behaviour |

### E-02 Rapid mute/unmute debounce and track-state honesty

| Field | Content |
|---|---|
| Priority | P1 |
| Target files | `nexa_voice_controller.dart` (`setMuted` coalesces toggles within 150 ms; after each transport call read `isMicrophoneEnabled` into `micOpen`), panel/capsule use `micOpen` for the icon |
| Tests | 10 toggles in 1 s → ≤ 2 transport calls; final state matches last intent |
| Depends on | E-01 |

### E-03 Bluetooth, audio route and focus

| Field | Content |
|---|---|
| Priority | P1 (M-12.1, M-12.3) |
| Target files | `host_permission_handler.dart` (`NexaPermission.bluetooth` → `Permission.bluetoothConnect` on Android 12+), `nexa_permission_handler.dart` (enum value), `nexa_voice_controller.dart` (request before `connect` when a BT device is present: use `livekit_client` `Hardware.instance.audioOutputs`/`setPreferSpeakerOutput`), capsule route chip (speaker / earpiece / headset) using `Hardware.instance.onDeviceChange`; focus: `flutter_webrtc` sets communication mode; add a `PhoneStateListener`-free approach: observe `AudioManager.MODE_IN_CALL` in the plugin (already polled by the wake service) and emit `phone_call_started/ended` → controller mutes/ends with `endReason: 'phone_call'` |
| Tests | unit: permission requested once; device T-M12-03/04 |
| Depends on | A-03 |

### E-04 Barge-in evidence and backend request

| Field | Content |
|---|---|
| Priority | P1 (M-08) |
| Target files | `qa_analysis.dart` (report: interruptions with `cancel_id`, `audio_started`, time since `assistant_audio_started`, local level at that moment), `docs/qa/barge-in-evidence.md` template |
| Design | no client gating of audio; deliver the six-scenario evidence to AWS with the G-03 request (min_duration/min_words/false-interruption resume/voice isolation) |
| Depends on | C-04 |

---

## Phase F — Android assistant, wake word, speaker verification

### F-01 Commit the wake-word benchmark (first task of the whole plan)

| Field | Content |
|---|---|
| Priority | P1 |
| Files | the three modified files + `wake_benchmark_page.dart` as they are; add a 3-line README note in `packages/nexa_assistant/README.md` ("Developer benchmark: labelled clips in `files/wake_bench`, model speed test; dev builds only") |
| DoD | `flutter analyze` green; `git status` clean except ignored files |

### F-02 Wake engine interface + Porcupine Arabic spike (behind a flag)

| Field | Content |
|---|---|
| Priority | P1 (M-10) |
| Target files | `engine/WakeDetector.kt` (new interface `fun accept(samples: FloatArray, n: Int)`, `fun reset()`, callback `onDetected(score)`), `engine/DtwWakeDetector.kt` (wrap existing), `engine/PorcupineWakeDetector.kt` (optional dependency `ai.picovoice:porcupine-android`, `.ppn` + `porcupine_params_ar.pv` under `files/models/`, AccessKey from `--dart-define` into the plugin via `configure(porcupineAccessKey:)`, never committed), `WakeListenerService.buildEngine()` chooses by `prefs.detector`, Dart `NexaAssistant.setDetector('dtw'|'porcupine')`, settings page toggle (dev-only until measured) |
| Design | Porcupine runs on the same 16 kHz frames (512-sample frames); the owner-voice check still runs on the segment after a detection (reuse `SpeechSegmenter` output buffered around the detection time). Licence: obtain the console-trained «يا لبيب» keyword and confirm the plan terms before enabling in any shared build; keep DTW as the default until T-M10-02 passes. |
| Tests | Kotlin: interface contract test with a fake detector; benchmark run script `tool/wake_bench.sh` (pull `wake_bench/*.wav`, run both detectors offline on the JVM, print accept/reject matrix) |
| Device acceptance | T-M10-01..03 |
| DoD | benchmark report in `docs/qa/wake-benchmark-<date>.md` with ≥ 20 owner clips, ≥ 20 other-phrase clips, ≥ 1 h TV/noise |
| Depends on | F-01 |
| Out of scope | replacing DTW by default |

### F-03 Self-owned speech-embedding classifier spike

| Field | Content |
|---|---|
| Priority | P2 |
| Design | use the benchmarked mel + Google speech-embedding (already timed on device by `benchModelSpeed`) with a tiny classifier trained on synthetic Arabic TTS (several voices) + consented owner clips; code Apache-2.0 (no openWakeWord pre-trained NC models); training notebook under `tools/wake_training/`; on-device inference via ORT in `EmbeddingWakeDetector.kt` |
| DoD | same benchmark as F-02; decision recorded in `.ai/mobile.md` |
| Depends on | F-02 |

### F-04 Speaker verification: real-voice calibration and consent

| Field | Content |
|---|---|
| Priority | P2 (M-11) |
| Target files | `device_assistant_page.dart` (consent text, delete confirmation), `WakeEngineTest.kt` (real clips from the benchmark), `docs/qa/speaker-calibration-<date>.md` |
| DoD | owner 5×/stranger 3×/noisy 3× table on both devices; default stays off unless FA = 0 and TA ≥ 4/5 |
| Depends on | F-02 |

### F-05 Assistant cold-start conversation policy

| Field | Content |
|---|---|
| Priority | P1 (M-09.2) |
| Target files | `device_assistant.dart` (activation → `coordinator.ensureConversation(reason:'assistant')` when no chat is open or the activation source is `wake`/`system` with the app not visible; else join), panel header shows the conversation title after the first turn |
| Tests | unit with mocked coordinator |
| Depends on | A-01 |

---

## Phase G — Performance, accessibility, release hardening

### G-01 Performance baseline (measure before optimising)

| Field | Content |
|---|---|
| Priority | P1 (M-13) |
| Files | `docs/qa/perf-baseline.md`, `tool/perf.sh` (profile build, `flutter run --profile --trace-startup`, DevTools timeline export) |
| Measure | cold start (`timeToFirstFrame`, `timeToInteractive`), chat scroll jank with 200 messages (integration test with the reference gateway), rebuild counts of the call page (DevTools), memory across 20 call cycles, wake listener 30-min battery (`dumpsys batterystats`) |
| Then | fix only measured offenders in order: h1 (`ValueListenableBuilder` scoping on the call page), h2 (memoise timeline), h5 (defer QA recorder/history load after first frame), h6 (model via on-demand asset or Play Asset Delivery) |
| Depends on | Phases A–E merged |

### G-02 Accessibility device pass

| Field | Content |
|---|---|
| Priority | P1 (M-14) |
| Files | `docs/qa/a11y-<date>.md`; fixes in the SDK widgets found by the pass; widget tests at `textScaler: 2.0` for list, chat, call, settings |
| Depends on | B-01, C-03 |

### G-03 Release hardening (Android)

| Field | Content |
|---|---|
| Priority | P0 for Beta distribution |
| Files | `apps/nexa_example/android/app/build.gradle.kts` (release signing from `key.properties`, `isMinifyEnabled/isShrinkResources`, ABI splits or app bundle), `src/main/AndroidManifest.xml` (`usesCleartextTraffic` only in `debug` manifest), `proguard-rules.pro` (keep ORT, LiveKit), version name/code from CI, `NexaEnvironment.production` policies for the Beta build |
| DoD | `flutter build appbundle --release --dart-define-from-file=…` installs and runs on both devices; no cleartext; size recorded |
| Depends on | none (can run in parallel) |

### G-04 Crash reporting and diagnostics hook

| Field | Content |
|---|---|
| Priority | P1 |
| Design | the SDK already exposes `lifecycle` and `NexaDiagnostics`; add `FlutterError.onError`/`PlatformDispatcher.onError` forwarding in the app to a `CrashSink` interface (no vendor chosen in this plan); keep QA records opt-in |
| Depends on | none |

### G-05 CI gate script

| Field | Content |
|---|---|
| Priority | P1 |
| Files | `tool/ci.sh` = `check.sh` + `flutter build apk --debug` + Kotlin unit tests (`./gradlew :nexa_assistant:testDebugUnitTest`); GitHub Actions workflow file written but **not pushed** |
| Depends on | none |

---

## 2. Designs for the complex operations (reference for all tasks)

### 2.1 Conversation creation and assignment (A-01, B-01, F-05)

States: `none` → (`ensureConversation`) → `creating(client_ref)` → `open(id)`; `open(id)` → (`startNew`) → `none`; `open(a)` → (`open(b)`) → `open(b)` after `sessions.end(reason:'resume')`. Who may call `ensureConversation`: first send in chat, call start (any surface), assistant activation. Who may call `open`: list tap, deep link `/c/:id`. Who may call `startNew`: list FAB, header "new". Invariant: one in-flight create; `client_ref` stable until success; `lastKnownSeq` reset on change; `toolCalls.reset()` and `media.clear()` on change (as today).

### 2.2 Navigation between chat and call (A-02)

Route table and transitions are in A-02. Invariants: at most one `/call` route; the call route always has a conversation id; popping the call route ends the call; `onCallEnded` triggers C-01 reconcile on the chat page; deep links to `/c/:id/call` from the assistant panel go through `ensureConversation` first.

### 2.3 Call state machine (unchanged + additions)

`VoiceSessionMachine` stays table-driven. Additions: C-04 `interruptConfirmed` flag (state object, not a machine state); E-01 deferred mute command; A-04 `background` end reason. The machine remains the only source of the phase; the capsule derives the label from phase + flags + tool activity.

### 2.4 Transcript event reconciliation (C-01)

Sources: live captions (`RealtimeTranscript`/`RealtimeAssistantTranscript`, in-memory, replaced in place), persisted messages (`GET messages`, server `seq`). Rules: persisted wins; live captions are never written to the chat list; after reconcile, the call's local transcript is dropped; dedupe by id, then by (role, text, ±2 s).

### 2.5 Tool UI rendering and action submission (D-02, D-03)

`ui_presented` → parse → `NexaUiDocumentItem` → `NexaUiView`. Action → `NexaUiEvent` → in-flight set → sink (`chat` bloc or coordinator fallback) → `null` (accepted) or gateway code → view state (`sent`, `expired`, `error{retry}`). The document is read-only after `confirm`/`submit` succeeded.

### 2.6 Pending tool-workflow restoration (D-01)

On open: import persisted `{tool_call_id → session_id, status, ui_values}` → `restore(messages)` → `_follow` non-terminal calls with the persisted session id → cards show live status. Never auto-run; approval requires a new user tap.

### 2.7 Audio capture and mute finalisation (E-01, E-02)

See E-01. Observable states: `muted` (intent), `micOpen` (fact), `mutePending` (grace running). Diagnostics: `voice.mute {intent, deferred}`, `voice.mute_applied {after_ms, cause}`.

### 2.8 Barge-in gating (C-04, E-04)

Client: no gating, honest label, evidence. Backend (G-03): thresholds and false-interruption resume. Optional later: a client "hold to talk" mode for noisy places (manual turn mode is a backend feature; not in Beta).

### 2.9 Wake-word lifecycle (F-02)

`WakeListenerService` → `WakeDetector` (DTW | Porcupine | embedding) → detection → optional speaker check → refractory → `ActivationRouter` → host → `coordinator.ensureConversation(reason:'wake')` → call. Service start only while visible; paused during calls, phone calls and enrolment.

### 2.10 Optional speaker verification (F-04)

Unchanged pipeline; consent copy, calibration table, never authorisation.

### 2.11 Reconnection and offline recovery (A-04, C-05)

Chat: existing back-off; voice: existing GET→token→rejoin; additions: immediate recover on resume, deliberate end when backgrounded without FGS, offline banner from `NetworkException`.

## 3. Event schemas and state ownership (summary)

| Data | Owner | Persisted where |
|---|---|---|
| `conversationId`, `client_ref`, `lastKnownSeq` | `ConversationCoordinator` | memory (id also in route) |
| chat messages | `ChatBloc` (reducer) | server; cache (B-02) |
| voice phase/flags/transcript | `NexaVoiceController` | memory |
| tool calls, ui docs, selections | `LabeebToolCallController` | memory + pending store (D-01) |
| history list | `NexaHistoryController` | server + cache per account |
| wake/speaker profile | Kotlin `VoiceProfileStore` | encrypted file |
| call FGS state | `CallForegroundService` | none |

## 4. Error paths (per task, summarised)

`ensureConversation` failure → chat still opens without id (today's behaviour) and shows "tools unavailable"; call start without id proceeds without tools (today). Reconcile fetch failure → diagnostics `chat.reconcile_failed`, silent retry on next resume. FGS start blocked → diagnostics, call continues foreground-only, A-04 ends it after 25 s background. Mute grace never exceeds 1.2 s. Porcupine init failure → fall back to DTW, status `detector_unavailable`.
