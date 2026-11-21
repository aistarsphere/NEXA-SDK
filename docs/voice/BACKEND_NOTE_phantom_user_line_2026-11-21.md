# For the backend: a "user" line with no speech (Nubia call, 2026-11-19)

## What was seen
A test call on the Nubia NX679J had no one talking. Even so, the transcript showed a line labelled **"You"** (user)
with the text "ما وصلني الكلام. يمكن صار خطر بالتحويل من الصوت. ممكن تعيد سؤالك.", and the assistant answered it.
The wording reads like a server fallback message for a failed speech-to-text step, not like speech. The server
appears to have stored that fallback under the **user** role. Speech starts (server) = 1 during the call.

## Identifiers (read from the server API on 2026-11-21, read-only)
| Field | Value |
|---|---|
| Conversation | `conv_HSFHJ_710AfPl5QwVWSC6Q` (created 2026-11-19T15:41:47.600Z) |
| SDK session | `ses_XuhjEl4Ov7pW_OE2bUwUtw` |
| User message (the phantom line) | `msg_4zRsmMRO5m0yzm0_ONgDUQ`, seq 908, channel voice, status accepted, **2026-11-19T15:42:12.102263Z**. Its stored text starts with the fallback sentence above (65 chars). |
| Assistant reply | `msg_NsjjbyaqpOch2jm_cTzqfg`, seq 909, same timestamp |
| Voice session | **`vs_0Ag5cQiESjSxDjRAUtsISA`**: from the app's QA record on the phone, `voice.created` at 15:41:52.480Z. The same record gives chat session `ses_TF8XwNh-WuXd9hkQxmBpHw`. |

## Server events of the call (`occurred_at`, server clock, from the agent events the app received)
Source: `docs/qa/evidence/2026-11-19/voice-audio/nubia-NX679J/qa_20261119-154146_voice_9edf.jsonl`. It has no
text: content capture was off, and transcripts appear only as `text_len`.

| occurred_at (UTC) | Event |
|---|---|
| 15:41:55.771 | `agent_ready` (seq 1) |
| 15:41:57.9 approx. | Mic track published (device clock 15:41:56.901; the server clock runs about 1.1 s ahead) |
| **15:42:02.931** | **`user_speech_started`** (seq 6, turn_1) |
| **15:42:09.680** | **`user_speech_ended`** (seq 7): about **6.7 s** of "speech" with nobody talking |
| 15:42:12.080 | `transcript` final, **`language: "en"`**, `text_len: 65`: this is the fallback sentence |
| 15:42:12.096 | `assistant_thinking` |
| 15:42:15.984 | `assistant_audio_started` |
| 15:42:20.809 | `assistant_turn_ended` (completed) |

## Route at the time: loudspeaker (now certain)
During the whole speech window (15:42:02.9–15:42:09.7 server time) the route was **speaker**, `mode in_communication`,
AEC `platform`. The tester switched to the earpiece afterwards, at device time 15:42:10.079, which is about
15:42:11.2 server time. **The switch came after the speech ended, so it is not the trigger.** No agent audio was
playing before that turn: this was the first turn, so echo of the agent is ruled out.

## Reading
VAD fired on about 6.7 s of room noise or ambient sound. STT then produced no real text, and the server emitted its
fallback sentence as the **user's final transcript**, tagged `language: en`, and stored it as the user message. The
agent then answered it as if the user had spoken.

## Questions for the backend
1. Does the STT failure path write a fallback text into the user's transcript or message? If it does, it should
   not be stored or shown as the user's words.
2. What did STT return for 15:42:02.9–15:42:09.7: empty, an error, or non-Arabic noise (`language: en`)?
3. Should a turn with no recognised speech end silently, with no transcript and no reply?

## Separate note: the second call in the same conversation
Session `ses_NS8cEQIPmsbgL2nKjQ8Jyw` ran from 15:44:54 to 15:45:45 UTC. A reinstall of the app ended it (my error,
recorded in the evidence README). It has 3 user lines (15:45:04, :06, :09) and two cancelled assistant replies.
Who spoke in it is not known. It is listed here only so it is not confused with the line above.
