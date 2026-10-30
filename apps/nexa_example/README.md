# nexa_example — LABEEB | لبيب

**LABEEB | لبيب** is the customer-facing assistant app. It is built on the brand-neutral
**NEXA SDK** (`nexa_sdk`, internal name; package imports, API routes, application and
backend identifiers are unchanged). This app is also the SDK's example host.

## Branding (what the app supplies)

* `lib/brand/labeeb_brand.dart`: name (LABEEB / لبيب), subtitle, logo slot, theme and fonts.
* `lib/brand/labeeb_palette.dart`: LABEEB colours (light/dark scheme and bubble/status roles).
* **Logo:** put the final logo at `assets/brand/labeeb_logo.png` (square, transparent,
  at least 512 px). It is picked up automatically; until then a text mark (L / ل) is shown.
  Launch screens: Android `res/drawable-*/labeeb_launch_logo.png` (then uncomment it in
  `res/drawable*/launch_background.xml`), iOS `ios/Runner/Assets.xcassets/LaunchImage.imageset`.
  App icons: `android/app/src/main/res/mipmap-*` and `ios/Runner/Assets.xcassets/AppIcon.appiconset`.
* The SDK views inherit the app's `ThemeData` (`NexaThemeSource.host`, the default).

## Assistant options (build-time)

* `--dart-define=NEXA_LAUNCH_MODE=chat|voice|home`: chat-first (default), voice-only, or a
  home screen with both entry points.
* `--dart-define=NEXA_SHOW_VOICE=false`, `NEXA_SHOW_NEW_CONVERSATION=false`,
  `NEXA_SHOW_SUGGESTIONS=false`: hide features. They can only hide: voice also needs the
  `liveVoice` capability requested, and the backend enforces what a session may do.

* `lib/assistant/`: what users see: the SDK's `client.assistantView()` (chat, live voice,
  home, navigation between them) with the LABEEB brand, plus the app's settings screen.
* `lib/playground/` and `lib/dev/`: developer-only. The SDK playground (modal and embedded
  chat, voice event log, theme overrides), the token status and diagnostics. These are
  compiled in only when `ExampleConfig.devTools` is on: always in debug builds, and in
  profile/release builds only with `--dart-define=NEXA_DEV_TOOLS=true`. A production build
  has no playground route, no diagnostics and never loads a development token.

## Credentials

A production build gets its SDK session token from the customer's own backend through a
`NexaAuthProvider` (that backend holds the tenant API key and mints the token). That
backend does not exist yet, so a production build shows "Assistant not connected".

For development and device testing, the short-lived **SDK session token** (minted by the
NEXA backend operator, scopes incl. `voice:session`) comes from a **secrets file read at
build time**. It is never typed into the app and never committed:

* `~/.nexa/nexa_dev.json` (recommended, outside the repository, `chmod 600`), or
* `apps/nexa_example/config/nexa_dev.json` (git-ignored). Start from the committed template
  `config/nexa_dev.example.json`.

```json
{
  "NEXA_REAL_BACKEND": "true",
  "NEXA_GATEWAY_URL": "https://52.58.22.19/nexa/api",
  "NEXA_APP_ID": "app_wsyCTDpZNf2yfwbROBcPqQ",
  "NEXA_LANGUAGE": "ar",
  "NEXA_DEV_SDK_TOKEN": "nxs_…",
  "NEXA_DEV_SDK_TOKEN_EXPIRES_AT": "2026-10-27T09:13:24Z"
}
```

The token is compiled into that **debug** build. Anything inside an app binary can be
extracted, so this is only acceptable for a short-lived development token on your own
device: don't share the build, and revoke the token after testing. The tenant API key, or
any long-lived credential, must never go in this file or anywhere in the app.

## Real NEXA backend: test on a physical phone

1. Connect the phone (Android: USB debugging on; iPhone: Developer Mode on, signing team
   `86FVQ9663H` in Xcode). Check with `flutter devices`.
2. Put a fresh token in the secrets file, then from `apps/nexa_example`:
   ```bash
   flutter run -d <device-id> --dart-define-from-file=$HOME/.nexa/nexa_dev.json
   ```
3. The assistant opens in Arabic. Type a message or tap a suggestion: the reply streams in.
4. Tap the voice button (header or composer) for a **live conversation**. Grant the
   microphone when asked. The capsule shows connecting → listening → you speaking →
   thinking → assistant speaking, and the captions show both sides. Speak over the
   assistant to interrupt it. **End**, or closing the page, ends the session (`DELETE`).
5. Errors show a banner with **Try again** (or **Open settings** for a denied microphone).
   An expired token shows "Access expired": rebuild with a fresh token.

TLS is verified normally; the LiveKit URL always comes from the API response.

Known issue: a phone or computer that is itself on the backend's NetBird network may route
media over NetBird and lose audio after ~20 s (backend item B10 in
`.ai/assumptions-and-blockers.md`). Test on a normal mobile or Wi-Fi network.

## QA diagnostics (development builds only)

Every chat session and voice call in a development build is recorded on the device
(`QaRecorder`, `lib/dev/qa/`): timestamped states, request ids and status codes, chat
first-token and total time, voice create / LiveKit join / handshake times, ICE state and
candidate types, microphone and agent-audio tracks, packet counters, agent events with
their `seq` and agent clock (`mono_ms`), interruptions, reconnects and cleanup. **No
tokens, no audio, no message text or transcripts** unless *Settings → Developer → Capture
transcripts (next session)* is switched on for that one session. Production builds
contain none of it.

Store on the device: `<app documents>/nexa_qa/index.jsonl` (one line per session, newest
last, max 40) and `records/<record_id>.jsonl`. On a computer (from `apps/nexa_example`):

```bash
dart run tool/qa.dart pull                 # copy from the connected Android phone → ~/.nexa/qa/<serial>/
dart run tool/qa.dart list                 # recent sessions
dart run tool/qa.dart report latest-voice  # or a record id / ses_… / vs_…; --json, --full
dart run tool/qa.dart note <id> --expected "مرحبا كيف حالك" --feedback "reply was cut off"
dart run tool/qa.dart delete <id>|--all    # on the phone and locally
```

The report separates measured facts from rule-based **hypotheses** (Flutter, AWS
backend, GPU Manager or network) and lists what Flutter cannot measure (e.g. STT/LLM/TTS
stage durations, which the agent events do not expose). Accuracy is only computed
against phrases the tester attached with `note`, and only for sessions with transcript
capture on. `pull` needs a debug build (`adb run-as`); iPhone retrieval is not scripted.

Interactive test: build and run as in the section above, open Settings → Developer, set a
label (and transcript capture if needed), go back, talk/chat, end the call, then
`pull` and `report latest-voice`.

## Other modes

* Local reference gateway (`make gateway`): `flutter run` with no defines.
* No server at all: `--dart-define=NEXA_USE_MOCK=true` (labelled mock transports).
