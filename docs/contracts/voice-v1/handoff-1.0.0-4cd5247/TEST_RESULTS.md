# Contract test results

Run on the backend branch `integration/phase4-3-phase5-voice`, base commit `dd558d6` plus the Phase 5.3A changes
(committed together; the exact commit is `backend_commit` in `MANIFEST.json`). Linux, Python 3.12.3,
livekit-server 1.13.10, livekit-agents 1.8.8, PostgreSQL 16. Models are deterministic **mocks**; no GPU, no network services.

| Suite | Result |
|---|---|
| Contract fixtures against real gateway + LiveKit + worker + Postgres (`tests/voice_gateway/test_contract_fixtures.py`, 5 tests; fixtures regenerated once, then re-verified in 6+ consecutive runs) | 5 passed |
| Gateway voice suite (incl. the above and the dispatch-reliability tests) | 46 passed |
| Voice (contracts, signing, real WebRTC, security, load policy) | 83 passed |
| Chat, hardening, config, lock, deploy, hygiene, handoff-archive tests | 224 passed |
| `ruff format --check`, `ruff check`, strict `mypy` | clean |

Scenarios covered by the contract tests: successful provisioning; agent joined (`agent_state: joined`); capacity refusal
(`503`, `Retry-After`, full cleanup, refund); agent lost mid-call; invalid / missing / expired credential; missing scope;
missing headers; invalid language; capability not granted; foreign-tenant session (identical to unknown); duplicate session;
refresh limit; refresh after end (`410`); quota exceeded at creation and during the call; signed-event verification on real
events; replay and forgery rejection (duplicate seq, other session, tampered body, algorithm substitution, wrong key);
network recovery via token refresh + `resume` RPC; normal termination and idempotent DELETE.

Not run / not covered: the Flutter SDK Phase 5.2 branch (not accessible here), a real device, real STT/TTS/LLM, a deployed
gateway, Docker builds, CI.
