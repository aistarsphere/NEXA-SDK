# AMEER voice calls — capture quality, phantom transcripts and interruptions (plan, 2026-11-19)

> **SUPERSEDED (2026-11-19, owner decision).** The on-device primary-speaker gate in §3.1 is not
> built: no on-device ML models, so the app stays light on low-end phones. The client keeps the
> standard AEC/NS/AGC (no Krisp, no AudioProcessor); voice isolation, VAD gating and interruption policy
> are the server's job. What replaced this plan: immediate mute, "speaking" until the server confirms an
> interruption, the speaker/earpiece choice with the real route and mode, phone-call hold, and
> capability-gated listening-control and client-info signals (`docs/voice/client-signals-proposal.md`).
> Manual tests: `docs/qa/VOICE_AUDIO_TEST_SHEET_2026-11-19.md`. Kept for its research and measurements.

Status: research and plan only. No code was changed. Nothing here is measured yet except where a
round-4 record is cited (`docs/qa/evidence/2026-11-19/voice-call-device.txt`).

## 1. The three problems and where each one lives

| Problem | Seen | Root cause | Where it must be fixed |
|---|---|---|---|
| A. Words transcribed while nobody speaks | reported by the owner; the classic speech-model phantom phrases | the speech-to-text model is given silence or noise and invents text | **backend** (speech detection before STT, filters). The phone can reduce what it sends |
| B. The assistant is interrupted by noise or by other people | round 4: "interrupted" on room speech | the server treats any detected speech as a barge-in | **backend** policy; the phone can supply a "this is the primary speaker" signal |
| C. Other people's speech becomes the user's turn | round 4: room conversation was transcribed as "You" | one microphone, no notion of who the user is | **both**: a primary-speaker signal from the phone, used by the backend |

## 2. Facts about the current app (verified in code)

- Call capture: WebRTC with echo cancellation, noise suppression, automatic gain control, high-pass filter
  (`packages/nexa_realtime/lib/src/livekit_audio_setup.dart:25-30`). Automatic gain raises quiet, distant voices.
- The app does not cut the assistant's audio itself. On the server's `user_speech_started` it only changes the
  screen to "interrupted" (`voice_session_machine.dart:163-173`; `nexa_voice_controller.dart:446-447`, "local only").
  The real interruption is decided by the server.
- The phone already ships a speech detector (Silero, 2.3 MB) and a speaker model (CAM++, 29.6 MB) with an
  encrypted owner profile, used today only by the wake listener (`packages/nexa_assistant/android/.../assets`).
- During a call the app never sees the microphone audio: WebRTC owns the recording. The installed
  `flutter_webrtc` 1.6.2 has a native hook for exactly this, `AudioProcessingController.capturePostProcessing`
  with `ExternalAudioFrameProcessing.process(...)`, which receives the audio **after** echo cancellation and may
  change it in place. `livekit_client` 2.13.1 also has a read-only `AudioFrameCapture`.
- A second parallel recorder is not an option: it would hear the assistant's own voice (no echo cancellation).
- The LiveKit server looks self-hosted. LiveKit's Krisp "background voice cancellation" needs LiveKit Cloud,
  so it is treated as unavailable unless the owner says otherwise.

## 3. Recommended design: a primary-speaker gate on the phone, a policy on the server

Principle: the phone produces a **signal**; the server **decides**. The phone only attenuates audio when it is
confident, and always fails open (if anything is missing or unsure, audio passes unchanged).

### 3.1 On the phone (Android first)

A native audio processor registered on the WebRTC capture path, running on each 10 ms frame after echo
cancellation:

1. **Speech detector** (Silero, 32 ms windows, about 1 ms of CPU per window on a phone-class core; to be measured).
   Output: speech / no speech, with 200–300 ms hang-over.
2. **Smart gate ("smart mute")**. While no speech: attenuate by about 18–25 dB (not hard zero), so the server
   receives near-silence instead of room noise. Open within one window (≤ 40 ms) when speech starts; close after
   the hang-over. Soft attenuation and fast opening avoid clipped first syllables; a hard track mute is rejected
   because it clips onsets and fails closed.
3. **Primary-speaker score** (only when the owner has a voice profile and has opted in). Every 0.5–1 s of
   detected speech, compute the speaker embedding and its similarity to the profile. Output per speech segment:
   `primary` / `other` / `unknown`. Short segments (< 1 s) stay `unknown`.
4. **Near/far cue** (cheap, no profile needed): level of the segment relative to the user's running speech level.
   A segment much quieter than the user's own speech is marked `far` (TV, people across the room, a phone on
   speaker nearby).
5. **Hints to the server** on the existing data channel, new message `client_audio_hint`:
   `{seq, t_ms, speech: bool, speaker: primary|other|unknown, near: bool, level_dbfs}`. Only these values leave
   the phone; never audio beyond the call audio itself, never embeddings.
6. **Optional stronger mode** ("only my voice", a setting, off by default): segments scored `other` with high
   confidence are attenuated too. This is the only mode in which the phone itself removes another person's
   speech; it needs real-voice evidence before it is offered.
7. **Automatic gain experiment**: A/B `autoGainControl: false` (or a fixed gain). Expected effect: distant
   voices stay quiet and fall under the server's speech threshold.

Rules that apply (standing): opt-in for anything using the voice profile; on-device only; the score never
authorises anything; without a profile everything behaves as a plain speech gate; iOS has no implementation
yet (the plugin is Android-only), so the server policy must work without hints.

### 3.2 Screen behaviour

- Show "interrupted" only on the server's `interrupted` event, not on `user_speech_started` (already filed as
  M-08). On `user_speech_started` while the assistant speaks, show nothing or a subtle "listening" cue.

### 3.3 On the server

See the prompt in section 6. Summary: speech detection before STT, phantom-text filters, a barge-in policy
with minimum duration and words, false-interruption resume, an end-of-turn model, and use of the phone's hints.

## 4. Measurement before and after (required before any claim)

Scenario clips, replayed offline through the gate first (as done for the wake gate), then on the device:

| Scenario | What must happen |
|---|---|
| Silence, 5 min | 0 user turns, 0 interruptions |
| Steady noise (fan, car) | 0 user turns |
| TV or radio speech in the room | no user turn while the user is silent; no interruption of the assistant |
| Two people talking nearby | as above |
| A phone on speaker next to the device | as above |
| User speaks over noise | turn captured, first word intact |
| User says a short "yes" / "لا" | captured (must not be gated out) |
| User interrupts the assistant with a full sentence | assistant stops within the target time |
| User says "mm", "أها" while the assistant speaks | assistant continues |

Metrics: phantom turns per silent minute; false interruptions per minute of assistant speech; share of
non-user words in "You" turns; clipped onsets (first-word errors); added latency; CPU and battery of the gate.
Real owner voice is required for the speaker rows; synthetic voices prove only the plumbing.

## 5. Order of work

1. Backend: speech gate before STT, phantom filters, barge-in policy (section 6). Biggest effect, no app release.
2. App: "interrupted" only on the server event; automatic gain A/B. Small.
3. App: native capture processor with speech gate and `speech`/`near` hints (no profile needed). Offline replay,
   then device numbers.
4. Backend: consume hints.
5. App: primary-speaker score and hint (opt-in), with the owner's real voice tests.
6. Optional "only my voice" mode, only if step 5 measures well.

Risks: gating out quiet real speech (mitigated by soft attenuation, fail-open and the short-word test);
speaker score unreliable on short or noisy speech (kept a soft signal); CPU of the speaker model in a call
(run at most once per second of speech; measure); behaviour differences on other phones (only the Nubia is
available).

## 6. Prompt for the backend team

```
Context
AMEER is a voice assistant. The mobile app publishes one microphone track to the LiveKit room and receives
signed events (user_speech_started, user_speech_ended, transcript, assistant_thinking, assistant_audio_started,
assistant_turn_ended, interrupted). Field observations on 2026-11-19 with a healthy system:
- room conversation near the phone was transcribed as the user's turns;
- the assistant was interrupted by speech that was not addressed to it;
- text appears for moments in which nobody spoke (phantom transcripts);
- a spoken weather question called web.search instead of weather.forecast.
The app sends audio after echo cancellation and noise suppression. It will later also send hints (item 6).
Implement the following in the voice agent pipeline (both the Realtime and the standard STT->LLM->TTS paths).
Keep the event contract backwards compatible; every new field or message must be optional.

1. Speech gate before STT
- Run a voice activity detector (for example Silero) on the incoming track. Send audio to STT only for
  detected speech segments, with about 300 ms of pre-roll and 300-500 ms of post-roll.
- Minimum speech duration for a user turn: 250-300 ms. Activation threshold configurable (start at 0.5-0.6).
- Never feed silence or long noise-only windows to the speech model.

2. Phantom transcript filters (after STT)
- Drop a final transcript when the model's own confidence says "no speech" (for Whisper-family models:
  no_speech_prob above about 0.6 together with a low average log-probability, or a very high compression
  ratio); do not rely on these thresholds alone, item 1 is the main defence.
- Do not condition a segment on previous text (stops repeated-phrase loops).
- Drop transcripts that are empty, punctuation only, or that match a maintained list of known phantom phrases
  for Arabic and English (for example "thanks for watching" and its Arabic forms, subtitle credits, music
  tags) when the segment is short or its energy is low.
- Drop a transcript whose text is implausibly long for its audio duration.
- Log every dropped transcript with its reason and scores (no audio, no text in production logs beyond a hash).

3. Barge-in policy (interrupting the assistant)
- While the assistant is speaking, user_speech_started must not stop the assistant by itself.
  Interrupt only when detected speech lasts at least 500-700 ms AND at least 2 words are recognised
  (or one word from a stop list: "stop", "wait", "كافي", "لحظة", "اسكت", "وقف").
- Backchannels ("mm", "aha", "أها", "اي", "تمام", "ok") must not interrupt.
- False-interruption recovery: if the assistant was paused and no valid user turn follows within about 2 s,
  resume the interrupted speech from where it stopped.
- Send the `interrupted` event only when the interruption is confirmed, never on speech start.
- Reference: LiveKit Agents exposes these ideas as interruption min_duration, min_words,
  false_interruption_timeout, resume_false_interruption and an "adaptive" mode; verify names against the
  version in use. If the agent is custom, implement the same behaviour.

4. End of turn
- Do not end the user's turn on the first short pause. Use a semantic end-of-turn model if available, or
  endpointing of at least 600-800 ms of silence, extended when the partial text is clearly unfinished.

5. Echo safety
- While the assistant's audio is playing, raise the speech threshold for barge-in, so residual echo of the
  assistant's own voice cannot interrupt it.

6. Client hints (new, optional)
- Accept data messages `client_audio_hint` from the app on the events topic:
  {seq, t_ms, speech: bool, speaker: "primary"|"other"|"unknown", near: bool, level_dbfs: number}.
- Policy when hints are present: a segment marked speaker="other" or near=false must not interrupt the
  assistant and should not open a user turn unless it contains the assistant's name or lasts longer than a
  configurable limit; speaker="primary" may use the shorter barge-in thresholds. Missing or "unknown" hints:
  behave as in items 1-5. Hints are advisory and must never be used for authentication or authorisation.
- Echo back in `user_speech_started` an optional field `source: "primary"|"other"|"unknown"` so the app can
  show the right state.

7. Optional, if resources allow
- Server-side noise or background-voice suppression before the speech gate (a speech-enhancement model);
  measure its effect on Arabic recognition before enabling it.
- Server-side speaker tracking inside the call: take the first clear user turn as the reference voice and
  down-weight segments from a clearly different voice. Embeddings stay in memory for the call only.

8. Tool choice
- A weather question must call weather.forecast, not web.search; review tool descriptions and add a test.

9. Configuration and telemetry
- All thresholds configurable per application without a deploy.
- Counters per call: user turns, dropped phantom transcripts by reason, barge-ins confirmed, barge-ins
  rejected, false-interruption resumes, mean time from end of user speech to first assistant audio.

Acceptance tests (run with recorded clips published into a room)
- 5 minutes of silence: 0 user turns, 0 interrupted events.
- 5 minutes of steady noise: 0 user turns.
- TV speech at conversation distance while the assistant speaks: 0 interruptions.
- User says a full sentence while the assistant speaks: assistant audio stops within 800 ms of the end of
  the second word.
- User says "mm" / "أها" while the assistant speaks: assistant continues.
- User says a single "نعم" / "لا" in a quiet moment: captured as a turn.
- Latency from end of user speech to first assistant audio does not grow by more than 200 ms.
Report the numbers before and after the change.
```

## 7. Sources

- LiveKit noise and echo cancellation: https://docs.livekit.io/transport/media/noise-cancellation
- LiveKit turn-taking tuning: https://docs.livekit.io/agents/logic/turns/tuning/
- LiveKit turn-handling options: https://docs.livekit.io/reference/agents/turn-handling-options/
- LiveKit adaptive interruption handling: https://docs.livekit.io/agents/logic/turns/adaptive-interruption-handling.md
- Whisper phantom text in silence: https://www.dograh.com/feeds/blog/whisper-hallucination-silence ,
  https://arxiv.org/pdf/2609.04561
- Personal VAD (speaker-conditioned speech detection): https://google.github.io/speaker-id/publications/PersonalVAD ,
  https://arxiv.org/abs/2204.03793v3
