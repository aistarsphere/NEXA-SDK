Client signals end to end (backend release d42c1ba), Nubia NX679J, Android 13, 2026-11-21 ~09:46-09:48 UTC
Build: debug APK of commit 0742f5f, dev token from $HOME/.nexa/nexa_dev.json; installed only after
dumpsys audio showed no mode owner (no call running). Speech source: macOS `say -v Majed` (synthetic
voice from the Mac speaker); no human voice recorded.

Run 1  vs_EIB_IvQjeZSXuosxI1d99w (qa_20261121-094611_voice_39cc.jsonl)
  PASS  agent_ready announces client_signals: listening_control=nexa.voice.listening,
        client_info=nexa.voice.client_info (voice.signals, panel "listening signal").
  PASS  session_state carries capabilities.client_signals at the top level
        (voice.snapshot_caps {capabilities:true, client_signals:true}; panel "caps in snapshot: present").
  FAIL (network) both RPCs failed: code 1502 (response timeout, 5 s) then 1505 (send failed) on retry.
        At the same time the publisher ICE stayed "Checking" for ~14 s, the room reconnected (09:46:34),
        both ICE paths went Disconnected (09:46:42 / :48) and the call ended "disconnected" (09:47:00).
        The server still heard part of the synthetic sentence (a one-word user line plus a reply appears in
        the conversation), but no agent events reached the phone after session_state (speech starts 0).
Run 2  vs_NXAFZKYQFzagoej3UQ4MlA (qa_20261121-094742_voice_f1a5.jsonl)
  BLOCKED room_connect_failed MediaConnectException after 10.5 s; call never connected.

NOT TESTED: mute mid-sentence then a new sentence; listening:false/true acknowledged by the agent;
resume-answer capabilities. Blocked on media connectivity (phone Wi-Fi to LiveKit, or the server),
not on the signals. The same phone and Wi-Fi connected normally on 2026-11-19.
