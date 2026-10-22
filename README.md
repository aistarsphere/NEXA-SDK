# NEXA Flutter SDK (Phase 4.1 — chat vertical slice)

Embeddable chat SDK for third-party Flutter apps. Monorepo (pub workspace):

| Package | Purpose |
|---|---|
| `packages/nexa_core` | Pure-Dart contracts: config, auth, events + sequencer + reducer, tools, errors, transports, voice state machine, labelled mocks |
| `packages/nexa_ui` | Coffee & Mocha Material 3 Expressive theme, Noto Sans / Tajawal, en+ar localisation, chat components |
| `packages/nexa_sdk` | Public API (`Nexa`, `NexaClient`), DI, session, `ChatBloc` (streaming, stop, retry, reconnect), HTTP transport (SSE + long-poll), screens |
| `apps/nexa_example` | Host app: modal + embedded chat, runtime language/theme, host-side auth provider, on-device journey test |
| `tools/nexa_reference_gateway` | **Development infrastructure, not a backend.** Local executable implementing the proposed gateway contract with scripted replies |

```bash
./tool/bootstrap.sh   # flutter pub get (workspace)
./tool/gen.sh         # freezed / json / retrofit / injectable / gen-l10n
./tool/check.sh       # format + analyze + all tests (incl. SDK ↔ reference-gateway contract tests)
make gateway          # run the reference gateway on 127.0.0.1:8080
cd apps/nexa_example && flutter run        # talks to the gateway above over HTTP/SSE
make e2e              # on-device journey: tool/e2e.sh [device-id]
```

Example app switches: `--dart-define=NEXA_GATEWAY_URL=http://host:port`,
`--dart-define=NEXA_USE_MOCK=true` (in-memory mock, no server).

## Integrate in 5 lines

```dart
final nexa = await Nexa.initialize(
  config: NexaConfig(applicationId: 'app_…', gatewayBaseUri: Uri.parse('https://gw…'), languageTag: 'ar'),
  auth: MyBackendAuthProvider(),           // returns a short-lived session token from YOUR backend
);
await nexa.openChat(context);              // or: nexa.chatView() inside your own layout
```

## Status (read before quoting)

* **Implemented Flutter SDK behaviour:** session lifecycle, streaming replies,
  stop, retry with idempotency, automatic reconnect with back-off, auth
  renewal (proactive + once after 401), quota and expiry states, tool
  confirmation round trip, en/ar + RTL, light/dark, reduced motion,
  live-region announcements.
* **Validated against:** the local reference gateway only (`tools/`), over
  real sockets, in `packages/nexa_sdk/test/integration` and
  `apps/nexa_example/integration_test`.
* **Proposed, unconfirmed by backend:** `docs/contracts/nexa-gateway-api.proposed.yaml` (0.2.0).
* **Missing:** a real NEXA gateway / staging environment, tenant session-token
  minting, GPU-backed inference, realtime voice, CI.

Not production ready. Read `.ai/flutter-architecture.md` and
`.ai/assumptions-and-blockers.md` before contributing; decisions are in
`docs/adr/`.
