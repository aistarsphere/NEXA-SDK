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
| device.camera.capture | WORKS to the review step. In-app camera with "camera on" badge and "nothing is shared until Use photo", OS permission, shutter, Retake / Use photo; cancel answered `cancelled` (result 200). Upload not run (403 above) and no room photo sent. | log |
| device.microphone.record_sample | Consent sheet renders ("only what you record now is captured... used to create your voice print", 5-10 s), cancel answered (result 200). **Not recorded**: it is a biometric voice print, so I did not enrol one on the production backend without the owner. | log |

## Defects found
1. **Choice sheet hid the Apply card** (fixed). After choosing a palette the bottom sheet stayed open over the conversation; the Apply card (approval deadline ~60 s) sat behind it and expired ("request expired"). Fix: an overlay now closes when a device tool call starts waiting for approval (`_CloseOnApproval`, test first). Re-verified on the phone: sheet closed itself, Apply card visible, applied.
2. **Pickers silently did nothing (fixed, root cause found with traces on the Nubia).** The call page saved the chat's presenter on open and restored it on close. Opening a call from the list pushes the chat and the call together, so the chat installed its presenter first or in between; closing the call then restored an older, empty presenter. Every later device-UI tool (photo, file, camera) ran with no screen (`_run ... shown=false`) and waited for the deadline. Chrome/Maps were a red herring (the call had been opened first). Fix: the call page now adds an overlay presenter and removes only itself (`addPresenter`); test first. Re-verified: list → call → close → file tool opens the system picker.
3. Upload 403 (token), see above. Not an app defect; needs `assets:write` on the dev app id.
