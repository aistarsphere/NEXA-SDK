# NEXA voice API handoff for the Flutter team

Start with `voice-contract-v1.md` (canonical), then:
| File | Purpose |
|---|---|
| `voice-contract-v1.md` | endpoints, fields, events, ordering, timestamps, tokens, termination, quota, reconnect; PROPOSED items isolated in §10 |
| `error-catalogue.md` | every error code with action and evidence |
| `event-verification.md` | exact signature verification procedure + test vectors |
| `session-lifecycle.md` | sequence diagram, who ends a call, cleanup obligations |
| `sdk-compatibility-matrix.md` | comparison with SDK `main` @ `9bec0b3` (verified) and requirements for the 5.2 branch (unverified) |
| `security-assessment.md` | controls, residual risks, owner decisions (none approved) |
| `fixtures/` | sanitized request/response/event fixtures generated from real runs, plus verification vectors |
| `TEST_RESULTS.md` | contract test results for the handoff commit |
| `MANIFEST.json` | commit, file list, sha256 (in the archive) |

Placeholders in fixtures: `vs_<id>`, `<livekit-join-jwt>`, `<iso8601-utc>`, `<number>`, `<ed25519-public-key:…>`, `wss://<livekit-host>`.
Regenerating (backend side only): `NEXA_REGEN_FIXTURES=1 pytest tests/voice_gateway/test_contract_fixtures.py`.
