# ADR 0001 — Phase 4 Flutter SDK Foundation

Date: 2026-10-22 · Status: accepted (Phase 4)

## Context

NEXA needs an embeddable Flutter chat SDK for third-party apps. Inputs at the
start of this phase: a written design contract (Coffee & Mocha, M3
Expressive, Noto Sans / Tajawal; Design QA 3.1 conditional pass), the GPU
Manager OpenAPI 1.2.0 and its handover notes. There was **no** existing
Flutter code, **no** NEXA backend, and the interactive prototype was not
available as an artefact in this environment.

## Decisions

1. **Pub workspace monorepo, three packages + example** (`nexa_core`,
   `nexa_ui`, `nexa_sdk`, `apps/nexa_example`). `nexa_tools` and
   `nexa_realtime` from the proposal are folded into `nexa_core` because they
   are small, pure-Dart contracts that version together; a separate realtime
   package is justified only when a concrete transport brings platform
   dependencies. Melos is unnecessary: Dart 3.12 workspaces resolve all
   packages with one `pub get`.
2. **Dependency direction**: `nexa_sdk → nexa_ui → nexa_core`. `nexa_core` has
   no Flutter dependency. Nothing depends on the example.
3. **Stack**: flutter_bloc 9, dio 5 + retrofit 4, freezed 3 + json_serializable,
   get_it 9 + injectable 3 (isolated `GetIt.asNewInstance()` per client),
   go_router only in the example app. Sibling projects in this workspace use
   the same stack, which keeps team conventions consistent.
4. **Auth model**: host backend mints short-lived session credentials;
   `NexaAuthProvider` is the only auth surface. No secret fields exist in
   `NexaConfig`; its validator rejects credential-looking metadata.
5. **Event model**: typed sealed `ConversationEvent` union with gateway
   sequence numbers; `EventSequencer` (dedupe/reorder/gap) + pure
   `ConversationReducer`. Widgets consume `ConversationState` only.
6. **Transport**: `ChatTransport` interface; `GatewayChatTransport` (proposed
   long-poll HTTP) and `MockChatTransport` (explicitly labelled mock).
7. **Voice**: pure `VoiceSessionMachine` + `RealtimeVoiceTransport`
   interface + mock. No real audio or network code in this phase.
8. **Tools**: typed `ToolResult`/`ToolAction` unions, validated before render.
9. **Theme**: tokens live in one file (`mocha_palette.dart`) pending a
   prototype export; contrast enforced by tests. Fonts bundled.
10. **Localization**: gen-l10n in `nexa_ui` (en, ar); the chat view installs
    its own `Localizations` + `Directionality` scope so hosts need no setup.

## Consequences

* Everything a backend engineer needs is in `docs/contracts/`; the SDK does
  not change when the gateway is implemented, only `GatewayChatTransport`
  gets validated.
* Token-level streaming depends on the GPU Manager exposing partial text in
  job events; the SDK handles both fine- and coarse-grained deltas.
* Design tokens are provisional until the prototype export is available.
