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
| Voice session (`vs_…`) | Not exposed by the messages API. The backend can map it from the SDK session or the conversation. On the device it is in the app's local history; it can be read when the phone is connected. |

## Call times (UTC; the device clock is UTC+3)
* About 15:41:47: call started (the conversation was created).
* 15:42:12.10: server wrote the user line and the reply.
* About 15:42:47: the tester tapped End call.

## Route at the time
The output was the **loudspeaker** (the default; the panel showed `route speaker`, `mode in_communication`, AEC
platform). The tester switched to the earpiece at about 15:42:11.5 UTC, about 0.6 s before the server wrote the
line, so any audio that produced it was captured on the loudspeaker route. Mic and audio values are in
`docs/qa/evidence/2026-11-19/voice-audio/nubia-NX679J/`.

## Questions for the backend
1. Does the STT failure path write a fallback text into the user's transcript or message? If it does, it should
   not be stored or shown as the user's words.
2. What did VAD/STT receive at that moment: room noise, or an empty or failed STT result?

## Separate note: the second call in the same conversation
Session `ses_NS8cEQIPmsbgL2nKjQ8Jyw` ran from 15:44:54 to 15:45:45 UTC. A reinstall of the app ended it (my error,
recorded in the evidence README). It has 3 user lines (15:45:04, :06, :09) and two cancelled assistant replies.
Who spoke in it is not known. It is listed here only so it is not confused with the line above.
