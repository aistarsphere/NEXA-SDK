# Barge-in evidence (M-08) — template and request to AWS (G-03)

Status: **template, no evidence collected yet.** Nothing below is a result.
The client does not gate or filter call audio and has no interrupt command;
whether speech interrupts the assistant is decided by the agent
(`voice-contract-v1.md`: `interrupted` carries `cancel_id`, `by_turn_id`,
`audio_started`). This file is how we hand the backend measured facts.

## How to collect

1. Debug/profile build with `--dart-define=NEXA_DEV_TOOLS=true`, a recording
   name such as `bargein-<scenario>-<device>` (Settings → developer → QA).
2. Run one scenario per call (below), 3–5 interruptions each, then end the call.
3. Pull and report: `dart run tool/qa.dart pull` then `dart run tool/qa.dart report <id>`.
   The "Barge-in evidence" section lists, per attempt: whether the agent
   confirmed (`interrupted`), `cancel_id`, `by_turn_id`, `audio_started`, how
   many ms into the reply the user spoke, and how long the agent took to
   confirm. Also keep `adb shell dumpsys audio` of the call.
4. Put the report text under `docs/qa/evidence/<date>/bargein-<scenario>.md`.

## Scenarios (T-M08-02)

| # | Scenario | What to do | What we look for |
|---|---|---|---|
| 1 | Quiet room, deliberate interruption | say "stop" mid-reply | confirmed, small confirm delay |
| 2 | Quiet room, cough / "mm-hm" | cough or backchannel mid-reply | unconfirmed is acceptable (not an interruption) |
| 3 | TV / second voice at normal volume | play speech nearby, say nothing | no interruptions; if some, false interruptions |
| 4 | Music | music nearby, say nothing | same |
| 5 | Street / fan noise | noise nearby, say nothing | same |
| 6 | Speaker output (no headset) at high volume | let the assistant talk, say nothing | echo must not interrupt itself |

## Results (fill in)

| Scenario | Device | Attempts | Confirmed | Unconfirmed | False interruptions | Median confirm delay (ms) | Evidence file |
|---|---|---|---|---|---|---|---|
| 1 | | | | | | | |
| 2 | | | | | | | |
| 3 | | | | | | | |
| 4 | | | | | | | |
| 5 | | | | | | | |
| 6 | | | | | | | |

Not measured by the record: the **local microphone level** at each
interruption. Without it, noise and the user's voice cannot be told apart from
the client side; add a level sample to the record before drawing conclusions
about room noise.

## Request to AWS (send together with the results)

1. Expose and document `interruption.min_duration` (LiveKit default 0.5 s) and
   `min_words` (default 0; needs STT) for the Beta agent, and say the values in use.
2. Enable `resume_false_interruption` (`false_interruption_timeout` 2 s) so
   speech the agent decides was not an interruption lets the reply continue.
3. Evaluate voice isolation (noise-cancelling) for the user's track on the server.
4. Add `confidence` or `reason` to `interrupted` so the client can say why.

Client-side stance (unchanged): no gating of call audio, an honest label
("Listening to you…" until the agent confirms, "Interrupted" after).
