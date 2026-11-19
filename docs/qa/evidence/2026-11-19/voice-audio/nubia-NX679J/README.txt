Voice audio smoke check on a real device — 2026-11-19 ~18:41–18:42 (device clock)

Device: nubia NX679J (adb bf5c6761), Android 13. Mid/high-end Android.
Build: debug APK of commit a1d34d7 (+ debug-panel LTR fix), dev token from
$HOME/.nexa/nexa_dev.json, installed with `adb install -r` (app data kept).
Before installing: no audio-mode owner, launcher in front (no call running).
Account: the owner's dev account (real backend). One call of ~49 s was made;
no one spoke on purpose (an automated session, no human at the mic). The room's
noise level is unknown. The call adds one voice conversation to the account
(not deleted).

What was checked (screenshots in this folder):
1-connecting-speaker.png  native plugin answers: mode (actual) in_communication,
                          AEC/NS/AGC = platform/platform/software, route speaker,
                          focus held, bluetooth none (no permission). Output
                          button visible next to mute.
2-earpiece.png            output button -> route earpiece, choice earpiece,
                          mode stays in_communication. First mic enable
                          (track publish) took 2073 ms.
3-after-mute-unmute.png   mute 84 ms, unmute 105 ms (budget 1 s).
4-ended.png               call ended; panel gone. dumpsys audio afterwards:
                          mode owner None, focus stack empty (focus released).

Observation (not explained, server side):
  speech starts (server) = 1 and a transcript line labelled "You" reading
  "ما وصلني الكلام. يمكن صار خطر بالتحويل من الصوت. ممكن تعيد سؤالك." although
  nobody spoke on purpose; the assistant answered it. Either room noise was
  transcribed, or the server put a fallback text in the user's transcript.
  Needs the server trace for this call.

Not tested here (manual sheet rows remain NOT TESTED): T1 echo (10 runs per
route), T2 with speech/noise while muted, T3 wired/Bluetooth, T4 phone call /
WhatsApp call / background / network drop, T5 10-minute performance (needs a
profile build), T6 across all of these. iPhone and a low-end Android: no device.
