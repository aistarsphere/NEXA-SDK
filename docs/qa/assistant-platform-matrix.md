# Android assistant, wake phrase and lock screen: what is real (Nubia NX679J, Android 13, 2026-11-04)

Legend: **V** working and device-verified · **C** working under conditions · **I** implemented, not device-verified · **U** unsupported by OS/OEM · **B** still broken/open.

## The six capabilities are different things
| | Capability | State on the Nubia | Evidence |
|---|---|---|---|
| A | Select AMEER as the default assistant | **V** — the app cannot request the role: Android logs `Role is not requestable: android.app.role.ASSISTANT` (Android 13). The wizard opens Android's own "Digital assistant app" picker (`Settings$ManageAssistActivity`, resolved before launch); AMEER is listed there (service registration correct). After choosing, `cmd role get-role-holders ASSISTANT` = AMEER and `settings secure assistant` = AMEER. | logcat, `dumpsys role`, screenshots |
| B | Invoke through the system gesture/button | **V** — `KEYCODE_ASSIST` from the home screen opened AMEER's panel (VoiceInteractionSession window). | logcat |
| C | Keep an authorised service alive with the screen off | **C** — the wake listener (foreground service, `microphone`) kept listening with `mWakefulness=Dozing`: 5/6 spoken phrases detected, screen stayed off. Only after AMEER was opened by the user since the last install/restart. | dry-run decisions |
| D | Start microphone capture from the background | **U/C** — Android 13: allowed only while the app is "in use"; Android 14+: refused from the background. After a force-stop the phrase does nothing (0 decisions): Android does not restart it. The plugin refuses to start it from the background and says why (`background_start_blocked`). | force-stop test |
| E | Always-on hotword (DSP) | **U** — needs a system/privileged app and OEM sound models (`dumpsys voiceinteraction`: no KeyphraseSoundModels). The app's software listener is the supported equivalent. | dumpsys |
| F | Activate from the lock screen | **V (assist and wake)** — with the screen off and `isKeyguardShowing=true`: the assist key and the spoken phrase both woke the screen and showed AMEER's lock gate ("Unlock your phone to continue. Nothing is shown before that."). Nothing private is displayed; voice does not unlock the phone. | screenshots `docs/qa/evidence/2026-11-04/assistant_*.png` |

## Scenarios
| # | Scenario | Result |
|---|---|---|
| 1 | App open, unlocked | **V** (earlier sessions) |
| 2 | App backgrounded, screen on | **V** — 5/8 phrases (Mac TTS voice never trained on) |
| 3 | Screen off, listening enabled | **V** — 5/6 and 8/8 on two runs; screen stayed Dozing in the clean run |
| 4 | Locked, assistant role active | **V** — gesture and wake both show the lock gate |
| 5 | System assist gesture | **V** |
| 6 | Locked, no active listening service | **C** — assist gesture still works (system-bound); the wake phrase does nothing |
| 7 | Process killed (force-stop) | **U** — Android does not restart the listener; AMEER must be opened once |
| 8 | Reboot | **I** — boot receiver only re-arms the preference; the listener restarts only when AMEER is opened (Android 13) and, on 14+, never from the background. Not rebooted here |
| 9 | Battery saver | **I** — wizard shows the state; not exercised |
| 10 | Microphone permission revoked | **I** — tested in Dart (step returns to to-do); `permission_denied` path in the service not exercised on the phone |
| 11 | AMEER removed as default assistant | **V** — role check reads `False` on the next resume; unit-tested; also seen when the Google app held the role |

## The setup wizard
Facts come from `AssistantCapabilities.collect` (RoleManager, settings resolvers, permissions, power, keyguard) on every resume; a step is **verified** only from system state or evidence that something really happened (an assist invocation, a wake, a wake while locked). A vendor background screen is offered only if `resolveActivity` finds it (none exists on the Nubia → written instructions, never a blind launch). Hidden/privileged shortcuts (accessibility, device admin, unrestricted battery) are not used.

## Wake phrases
| Phrase | Model | Status |
|---|---|---|
| يا أمير | `yaameer.bin` | experimental |
| أمير (no «يا») | `amir.bin` | experimental |
| عباس | `abbas.bin` | experimental |
All three are heads on the same speech-embedding features, **trained on synthetic speech only**. Switching a phrase changes the head the detector loads (`setWakePhrase` → `ACTION_RELOAD` → `buildNeural`); the wake test (`wakeTest`) runs the real detector for 10 s and reports detections and the best score without opening anything. Offline, trained on Piper and tested on the macOS voice: «أمير» recall 0.54-0.68 with 34-130 false wakes/hour of adversarial near-miss audio; «عباس» 0.68-0.89 with 17-32/h. «أمير» is the weakest (two short syllables, shared with «يا أمير», «أميرة», «أمين»). **None is marked validated.**
Custom phrases: the text is validated (grapheme count >= 3, <= 20 characters / 3 words, no digits/symbols/emoji/hidden bidi controls, no mixed scripts, >= 2 syllables, not a very common word, not a repeated sound, not already installed; diacritics/tatweel/alef variants normalised), but **no model can be built on the phone**, so the screen says "not available yet" and offers nothing to enable. A trained head needs `tools/wake_training/phrase_models.py` plus consented real recordings.

## Not verified / open
Real Iraqi voices (wake recall, false wakes per hour, speaker FRR/FAR); Samsung and Pixel/AOSP; Android 14+ behaviour on hardware; CPU/battery drain of the listener; reboot; Android 15+. No OEM claim beyond the Nubia.
