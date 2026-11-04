# Tool calling, every type — Nubia NX679J, production gateway, 2026-11-04 (typed chat)

Build: profile APK after V-06 (`6d225a8`). Session declared 8 client tools:
`device.location.get_current, maps.open_directions, device.camera.capture, device.photo.pick,
device.file.pick, browser.open_url, app.theme.apply, device.microphone.record_sample`.
`device.network.get_status`, `device.share.content`, `device.app.open_settings`,
`app.theme.reset` are not declared (limit 8): asking "am I online" gets "I have no tool for that".

| Tool | Result on the phone | Evidence |
|---|---|---|
| device.location.get_current | WORKS. Consent card, OS permission, approval 200, result 200, the assistant named the place. First try expired (409): ~35 s between the call and my taps; the OS permission dialog counts toward the server deadline. | log |
| maps.open_directions | WORKS. Places search card, consent card, Google Maps opened with the route, result 200. | log |
| browser.open_url | WORKS. Chrome opened, result 200. A made-up URL is refused by the agent (only links it returned). | log |
| device.file.pick | Picker opens; cancel answered `cancelled` (result 200). Upload not tested: see 403 below. | log |
| device.photo.pick | Picker opens, a photo was chosen, upload `POST /conversations/{id}/assets` → **403**. The dev token has no `assets:write` (known since 2026-10-28). The agent then tells the user about "permission restrictions". | log |
| app.theme.apply | WORKS (palette picker → preview → Apply → preferences saved → result 200). | `tools_theme_*.png` |
| app.theme.list_palettes (server) | WORKS (list + choice surface). | screenshot |
| web / places search (server tools) | WORKS (result cards). | screenshots |
| device.camera.capture, device.microphone.record_sample | Not run in this pass. | |

## Defects found
1. **Choice sheet hid the Apply card** (fixed). After choosing a palette the bottom sheet stayed open over the conversation; the Apply card (approval deadline ~60 s) sat behind it and expired ("request expired"). Fix: an overlay now closes when a device tool call starts waiting for approval (`_CloseOnApproval`, test first). Re-verified on the phone: sheet closed itself, Apply card visible, applied.
2. **Picker did not open twice** (photo, then file) in a session that had gone to Chrome and Maps and come back. Not reproduced afterwards (fresh start, home and reopen: pickers open). Open; suspect the shared engine's activity binding after returning from another app.
3. Upload 403 (token), see above. Not an app defect; needs `assets:write` on the dev app id.
