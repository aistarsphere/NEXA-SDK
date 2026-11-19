# Device evidence 2026-11-04 — Nubia NX679J (adb bf5c6761, Android 13)

Build: profile APK from commit `34f87db` (dev tools on, token from `~/.nexa/nexa_dev.json`),
installed with `adb install -r`. Network: Wi-Fi (validated). Production gateway.
One live call, started by tapping the header call button, ended from the notification.
Screenshots of the notification shade were deleted: they showed unrelated personal notifications.

## T-M12-02 / A-03 / A-04 — in-call foreground service

| Step | Result | Evidence |
|---|---|---|
| Start a call (app in front) | `CallForegroundService` running, `isForeground=true`, channel `nexa_call`, category `call`, 1 action | `a03_services_foreground.txt` |
| App sent to the background for 40 s (> the 25 s grace) | **call survived**: service still running; microphone capturing (`VOICE_COMMUNICATION` record, not silenced, echo canceller and noise suppression on); green mic indicator in the status area | `a03_services_background_40s.txt`, `a03_audio_background_40s.txt` |
| Notification | posted: id 20033, small icon = resource `0x7f060020` (`nexa_notification_icon`), app name "أمير", title "مكالمة أمير", red action "إنهاء المكالمة" | `a03_notification_dump.txt`, `a03_notification_call_expanded.png` |
| "End call" in the notification | app logged `DELETE /v1/sdk/voice/sessions/vs_…`, WebRTC tracks removed, `CallForegroundService` stopped, no microphone use left | `a03_services_after_end.txt` |

Not covered: the 2-minute duration of the plan, audibility in both directions (nobody listened),
Android 14+ blocked-start behaviour (this phone is Android 13), Xiaomi.

## Defects and open points found

1. **Notification icon badge shows the blue Flutter logo** (white square) on this phone's shade, although the
   system reports our AMEER silhouette resource as the small icon. Likely the OEM shell (Nubia/RedMagic) drawing an
   app-icon badge from an icon cache; not confirmed. The launcher icon of this install was not looked at on the
   phone (no app drawer; not found on the home pages).
2. **The first call attempts did nothing for about 35 s**: two taps on the header call button, one with a 10 s
   wait and one with a 25 s wait, left the list on screen, then a third tap started the call within seconds.
   Possible cause: `openLabeebCall` awaits `ensureConversation` over the network with no feedback or timeout.
   Not reproduced on purpose; needs a log run.
3. Header still shows "لبيب" and the dialect welcome line: from the company profile (`GET /assistant`), not the app.
4. The live transcript captured ambient speech ("شلوك") with nobody speaking to the phone: a backend STT /
   VAD behaviour already known (B11).
