# Tool calling / theme selection trace — Nubia NX679J, build 9d2d55a (profile), production gateway, 2026-11-04

## A. Text chat — "change my application color" (typed)  → WORKS end to end
Log (`[nexa debug]`, app log; session and tool-call ids are not secrets):

    02:29:44 → POST /v1/sdk/sessions/ses_…/messages            (the typed request)
    02:29:44 ← 202
    (assistant listed 7 colours; a theme picker bottom sheet "اختر مظهرًا" with 7 palettes appeared)
    02:30:17 → POST /v1/sdk/sessions/ses_…/messages            (ui_event: user tapped "أخضر / green")
    02:30:18 ← 202
    (app previewed the green theme; card "تغيير ألوان التطبيق — معاينة الألوان الجديدة" with Apply / Not now)
    02:31:09 → POST /v1/sdk/sessions/ses_…/tool-calls/tc_…/approval   (user tapped Apply)
    02:31:10 ← 200
    02:31:10 → GET  /v1/sdk/me/preferences ← 200 ; PUT /v1/sdk/me/preferences ← 200   (colour persisted)
    02:31:10 → POST /v1/sdk/sessions/ses_…/tool-calls/tc_…/result ← 200               (device tool answered once)
    assistant: "تم تطبيق اللون الأخضر على التطبيق بنجاح" (the green colour was applied)

Screenshots: `theme_text_01_picker_selected.png`, `theme_text_02_applied_confirmed.png`.
Reverted afterwards through Settings → Reset (confirmed on screen, "original theme restored").

## B. Voice call (same phone, earlier call in this session) → tool and UI events are REJECTED by Flutter
Lines from the app log during a live call (pid 12135, 02:17:30):

    [nexa warning] voice event rejected: VoiceEventRejected(unknownType: ui_presented)
    [nexa warning] voice event rejected: VoiceEventRejected(unknownType: tool_call_requested)
    [nexa debug]   resume RPC failed: Instance of 'RpcError'

The agent did send the events (they passed the sealed-envelope checks and were parsed); the client's validator
`parseEventV1` (`packages/nexa_core/lib/src/voice/voice_events_v1.dart`) only accepts the types in
`_turnScoped ∪ _sessionScoped`, which do not include `tool_call_*`, `asset_created` or `ui_presented`.
The contract (`docs/contracts/labeeb-sdk-1/contract-1.0.0.json`, "sealed") says these events travel on the same sealed
`nexa.voice.events` topic. So `realtimeEventFromV1`'s mapping to `RealtimeToolEvent` (lines ~450–457) is never reached
with real traffic.

Not captured: the payload of the rejected events, the agent's error when a colour is spoken, and whether the
`resume` RPC failure matters (it logs on every call).
