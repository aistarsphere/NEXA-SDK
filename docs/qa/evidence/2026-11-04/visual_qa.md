# Visual QA on the Nubia NX679J (Android 13, Arabic, dark) — 2026-11-04

Screens checked: conversation list, chat (empty and with a message), call (failed and healthy),
Settings (top and About), "AMEER as assistant" settings, notification shade.

| # | Finding | Severity | State |
|---|---|---|---|
| 1 | **Call screen: the controls panel floated in the middle with a blank band below.** A regression from the 200 %-text change: the banner area was a `Flexible` and took half of the free height even when empty. | high | **Fixed** (`nexa_voice_capsule.dart`: the panel keeps its natural height at the bottom; banners and captions share the area above, banners capped at half and scrolling). Test: 6 layout cases (listening / reconnecting / mic denied × 1x / 2x) assert the controls are in the bottom 18 %. Re-checked on the phone: `visual_call_screen_after_fix.png`. |
| 2 | **A rate-limited call said only "Something went wrong. Please try again."** (backend 429 on creating the voice session) | medium | **Fixed**: the call error banner now says "Too many requests. Please wait a moment." (en and ar). |
| 3 | Settings → colour theme still named "لبيب موكا" (LABEEB Mocha) | low | **Fixed**: "AMEER Mocha" / "أمير موكا"; a test fails if an old name returns in visible labels. |
| 4 | Header name "لبيب" and the dialect welcome line | info | Not an app defect: they come from the company profile for this application (`GET /assistant`); change them in the Company Dashboard. |
| 5 | Notification icon badge is the Flutter logo on this phone's shade | medium | Open, see `README.md` point 1 (not confirmed to be the OEM shell). |
| 6 | Dev-only rows (SDK token, diagnostics) are English inside the Arabic UI | none | By design (debug/profile builds only). |
| 7 | The 429 call failure also leaves the retry hint pointing at a "Try again" button while the main button reads "Start voice" | low | Open (copy only). |

Layout checks that passed: RTL back arrow and actions, chat empty state, composer, conversation list with two
entries, Settings sections, About (AMEER logo, name, version), the "AMEER as assistant" page.

200 % text: automated on small-phone sizes for list, chat, call, settings in en and ar
(`apps/nexa_example/test/text_scale_test.dart`, 8 tests) and for the banner and capsule components;
not yet checked on the phone with the system font size at 200 % or with TalkBack.
