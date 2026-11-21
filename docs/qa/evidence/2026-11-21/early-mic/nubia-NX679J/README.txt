Early microphone (commit a6d2ea1 + review fixes), Nubia NX679J, debug build, 2026-11-21 15:40 UTC
Voice session vs_DyHohT8UBo2JOu_xSKy9Xw. One call, ~15 s, nobody spoke, ended by the tester.
Install was gated: dumpsys audio showed MODE_NORMAL with no mode owner before installing.
Files: qa_20261121-154023_voice_aba0.jsonl (content capture off, no text), call_listening_panel.png.

ORDER (device clock)                                         RESULT
15:40:32.979 room connected
15:40:33.044 audio_state mode in_communication, speaker, AEC platform   (set before the publish)
15:40:33.045 voice.early_mic
15:40:33.249 microphone track published (mic_applied 202 ms)
15:40:34.630 agent_ready -> listening_after_mic wait_ms 0 -> phase listening
=> listening_before_mic_ms = -1381: the track existed 1.38 s before "listening".   PASS
=> no listening:true signal sent at call start.                                    PASS

AUDIO DELIVERY                                                BLOCKED (network)
The publisher peer connection went to ICE "Checking" at 15:40:35.075 and never reached
Connected. out_packets and pub_tx_bytes stayed 0 for the whole call. The subscriber side
worked (agent audio received, in_packets 60). So no microphone audio reached the server.
Same fault this morning with the OLD code (09:46 call: publisher stuck in Checking ~14 s,
out_packets 0), so it is not caused by this change. The client_info RPC failed again
(1502 then 1505). LiveKit carries RPCs on the publisher's data channel, so a publisher
that never connects would explain those failures (inference, not proven).

NOT TESTED: a word spoken right at "listening" appearing in the transcript (needs a person
and a working publish path). iOS.
