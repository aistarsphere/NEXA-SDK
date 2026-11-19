# Technical investigation requests to AWS — mute turn commit (G-02) and barge-in (G-03)

Status: **ready to send, not sent** (the engineering environment has no channel to AWS; send through the existing one).
Both are **read-only investigations**. No production configuration, agent behaviour or quota change is requested or authorised by this message.

## G-02 — a muted microphone track stops the turn from ever closing

**Observed** (Nubia NX679J, production gateway, 2026-11-04; client events with timestamps, `docs/qa/evidence/2026-11-04/mute_T-M07-01.md`):

* Control, microphone never muted: `user_speech_ended` -> final transcript +0.13 s -> `assistant thinking` +0.15 s -> assistant audio +1.14 s.
* Mute tapped 78 ms after the end of speech: the **final transcript arrived while muted, but no reply for 19+ s**; after unmuting, the reply arrived within ~12 s.
* With the client keeping the track open for 1.2 s after Mute (client-side workaround now shipped), the turn closes in ~250 ms and the reply plays while the UI is muted.

**Hypothesis:** the agent's turn detection needs audio frames (trailing silence) to commit the turn; a muted LiveKit track delivers none, so the committed turn waits for the track to resume.

**Please tell us (no change requested):**
1. Which endpointing / turn-detection settings the Beta agent uses (minimum and maximum endpointing delay, semantic turn detector on/off).
2. What the agent does on `TrackMuted` while a user turn is open (does it wait, time out, or commit?), and the timeout if any.
3. Whether committing the open turn on `TrackMuted` is feasible without a contract change (so the client grace could be reduced to 0). If it needs a contract change, the smallest one.
4. For the next device test calls (we will send call ids and UTC windows), the agent-side event log around mute.

## G-03 — barge-in by other voices

**Known** (docs/qa/barge-in-evidence.md; 2026-10-30): a TV or another voice can interrupt the assistant; the client does no gating and has no interrupt command; the agent decides.

**Please tell us (no change requested):**
1. Current values of `interruption.min_duration`, `min_words`, and whether `resume_false_interruption` / `false_interruption_timeout` are enabled.
2. Whether server-side noise cancellation / voice isolation is applied to the user's track, and which.
3. Whether the `interrupted` event can carry `confidence` or `reason`.
4. Whether the agent can bias barge-in toward the enrolled speaker (speaker-aware turn taking) and what audio/identity input that would need. The client holds a local owner-voice profile; we propose **not** sending voice embeddings to the server unless the owner approves it separately.
5. For the six scenarios in docs/qa/barge-in-evidence.md (owner interrupts, soft interruption, another person, TV, assistant echo, noise) we will send call ids and time windows; please share the agent-side interruption decisions for those windows.

Contact for the evidence files: repository `docs/qa/` (paths above).
