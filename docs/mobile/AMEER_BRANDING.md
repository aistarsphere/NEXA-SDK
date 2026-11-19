# AMEER — official logo and brand integration

Status 2026-11-04. The approved logo is integrated in the Android app. The Company
Dashboard is **not** in this workspace: only its contract and handoff are
documented here (§7). Facts in §10 were checked; anything not checked is in §11.

## 1. Source of truth

| | |
|---|---|
| Approved asset | `apps/nexa_example/assets/new_logo.png` |
| Note | The brief named `assets/new logo.png` (with a space). The file in the repository is `new_logo.png`, under the app's `assets/` folder. It is the only copy and is never edited or bundled. |
| Format | PNG, RGBA, 1536 × 1024 (3:2), transparent background |
| Visible symbol | x 344–1195, y 130–866 (≈ 851 × 736 px) once the invisible margin (alpha < 8) is trimmed; the soft glow is part of the logo and is kept |
| Look | copper / bronze "A", a thin glow, no text |

The asset is suitable for icon formats after **non-destructive preparation** only:
trim the invisible margin, scale uniformly, centre on a canvas. Nothing is
redrawn, recoloured, stretched, shadowed or given effects. The 3:2 file is not
used as-is because launcher icons are square.

## 2. Generated assets

All assets come from one script, so they can be regenerated exactly:

```bash
pip install pillow                      # once
python3 tool/branding/generate_ameer_assets.py --preview /tmp/ameer_preview
```

`--preview` writes contact sheets (adaptive icon under circle / squircle /
rounded masks with the safe circle drawn, themed monochrome, light and dark
splash, notification icon). Re-run the script after any change to the source;
`apps/nexa_example/test/branding_test.dart` fails if the outputs break the rules
below.

| Output | Location (under `apps/nexa_example/`) |
|---|---|
| In-app logo, 1024² transparent | `assets/brand/ameer_logo.png` |
| Adaptive foreground, 108 dp per density | `android/app/src/main/res/drawable-{m,h,xh,xxh,xxxh}dpi/ic_launcher_foreground.png` |
| Adaptive monochrome (themed icon) | `…/drawable-*dpi/ic_launcher_monochrome.png` |
| Adaptive definition | `…/mipmap-anydpi-v26/ic_launcher.xml`, `ic_launcher_round.xml` |
| Legacy icons (API < 26), 48 dp | `…/mipmap-*dpi/ic_launcher.png`, `ic_launcher_round.png` |
| Splash icon, 288 dp canvas | `…/drawable-*dpi/ic_splash_icon.png` |
| Notification small icon, 24 dp | `…/drawable-*dpi/nexa_notification_icon.png` |
| Store icon, 512² | `android/app/src/main/ic_launcher-playstore.png` |

## 3. Launcher icon rules

* **Adaptive icon (API 26+)**: background `@color/ic_launcher_background`
  `#2E1C13` (the palette's deep brown, `LabeebPalette.light.onPrimaryContainer`);
  foreground = the logo on a transparent 108 dp canvas; monochrome = alpha-only
  silhouette. Declared in `mipmap-anydpi-v26/ic_launcher.xml` (and `_round`).
* **Safe area**: every visible pixel (alpha ≥ 24) of the foreground lies inside the
  66 dp safe circle (the script fits the symbol by its farthest pixel, 98 % of
  the radius). The symbol is about 43 % of the icon width, which is the cost of
  never being clipped by a circular, squircle or rounded mask.
* **Monochrome**: white on transparent, derived from the logo's own alpha and
  brightness (only the deepest shadow fold becomes see-through, so the ribbon
  stays readable). It is not the multicolour image reused as a mask.
* **Legacy icons**: rounded square and round, the symbol on the same brown.
* Application id, signing and build types are unchanged.

## 4. Splash screen

* **Android 12+** (`values-v31/styles.xml`, `values-night-v31/styles.xml`):
  `windowSplashScreenBackground` = `@color/labeeb_launch_background` and
  `windowSplashScreenAnimatedIcon` = `@drawable/ic_splash_icon` (a static image,
  no animation, no added duration; it closes with the first Flutter frame).
  The icon sits inside the 192 dp circle of the 288 dp canvas.
* **Android 11 and older / window background**: `drawable/launch_background.xml`
  (and `drawable-v21`) = background colour + the same icon centred.
* **Light / dark**: the background is `#F7F3F0` (`values/colors.xml`) or `#110D0B`
  (`values-night/colors.xml`), the existing palette surfaces.
* Flutter has no separate start-up or loading screen to brand: the first frame
  replaces the splash directly.

## 5. Notification icon

* The plugin (`nexa_assistant`) asks `Notifications.smallIcon(context)` for the
  small icon of **every** notification (wake listener, in-call service,
  activation, reboot notice). It uses `drawable/nexa_notification_icon` when the
  host app ships one and falls back to the plugin's microphone glyph.
* AMEER ships `nexa_notification_icon` (24 dp, white silhouette with crisp
  alpha, derived from the logo; centred in an ≈ 21 dp box).
* `res/raw/keep.xml` stops the release resource shrinker from removing it (it is
  looked up by name).
* Channels, notification ids, actions and behaviour are unchanged.

## 6. In-app branding and naming

* **Component**: `AmeerLogo` (`apps/nexa_example/lib/brand/ameer_logo.dart`)
  draws `assets/brand/ameer_logo.png` with `BoxFit.contain` in a square slot,
  never tinted, with the semantic label "AMEER" (`semanticLabel: null` for
  decorative use). `Labeeb.brand.logoBuilder` supplies it to the SDK, so the
  SDK's `NexaBrandMark` shows it in the assistant header, the conversation list
  and chat headers (dropped only when the title is narrower than 120 dp so the
  name still fits), and the home screen.
* Also shown: Settings → About (logo + name + version) and the "not connected"
  screen. The SDK stays brand-neutral.
* **Names**: user-facing name is **AMEER / أمير** (`Labeeb.nameEn`,
  `Labeeb.nameAr`, `AppStrings`, `DeviceAssistantStrings`, Android
  `@string/app_name` = AMEER, `values-ar` = أمير). The class `Labeeb`, packages
  (`nexa_*`), `com.nexa.nexa_example`, API paths, backend ids and migration files
  keep their names on purpose.
* **Wake phrase**: it remains **«يا لبيب»**. It is a setting of the on-device
  detector and the owner's enrolled samples (`DeviceAssistant.wakePhrase`,
  `AssistantPrefs.phraseLabel`, the enrolment screen, the benchmark page); the
  words the user is told to say must match what the detector was trained and
  enrolled on. Changing it to «يا أمير» is a separate functional task (new
  enrolment, benchmark, detector decision F-02/F-03). Visible references that
  still say the old phrase: `device_assistant_strings.dart`,
  `device_assistant_page.dart`, `assistant_page.dart` and `main.dart` comments,
  `wake_benchmark_page.dart`. **Wake-word recognition is not updated by this
  change.**
* Not changed: iOS (`Runner` icons, display name), the dev playground screens,
  historical docs and QA logs that say LABEEB.

## 7. Company Dashboard contract

The dashboard is not part of this repository, and no backend was changed.

Architecture: **AMEER example application → registered application logo →
dashboard displays that logo.** Nothing hardcodes AMEER for other companies.

* The contract already exists: `labeeb.sdk/1` `GET /v1/sdk/assistant` returns
  `{application_id, application_name, assistant: {assistant_name, accent_color,
  logo_url, welcome_message}}`; `logo_url` is the **https** logo the company sets
  for **that application**. The mobile client reads it as
  `LabeebAssistantProfile.logoUrl` (`Labeeb.profile`).
* Required action, outside this workspace (Company Dashboard / AWS):
  1. In the dashboard, open the application registered for the AMEER example
     app (app id `app_wsyCTDpZNf2yfwbROBcPqQ` in the voice-capable dev setup).
  2. Upload `assets/brand/ameer_logo.png` (1024² transparent PNG) through the
     dashboard's existing application-logo upload, which stores it and sets
     that application's `logo_url`. Do not ship the file inside the dashboard
     for all applications.
  3. Check that the dashboard shows it wherever it shows the selected
     application's icon (list, details, settings, selector, headers, preview) and
     that other applications still show their own logo.
* Handoff asset: `apps/nexa_example/assets/brand/ameer_logo.png`; original in
  `apps/nexa_example/assets/new_logo.png`.
* The mobile app currently shows its bundled AMEER logo and does not display a
  server-supplied `logo_url`; rendering a company-set logo in the app is a
  possible later change and would leave the approved bundled logo as fallback.

## 8. Using the component

```dart
const AmeerLogo(size: 48);                    // spoken as "AMEER"
const AmeerLogo(size: 72, semanticLabel: null); // decorative
```

Do not recolour, crop, round or add shadows to it. Do not use it for other
applications, companies or tenants.

## 9. Documents updated

`.ai/mobile.md` points here. The audit and plan are unchanged.

## 10. Verification (2026-11-04)

| # | Check | Result |
|---|---|---|
| 1 | Source exists, RGBA, transparent corners | passed (`branding_test`) |
| 2 | Icon resources generated | 32 files; sizes per density asserted |
| 3 | Adaptive safe zone | every density: all visible pixels inside the 66 dp circle (asserted); visually checked under circle, squircle and rounded masks |
| 4 | Light / dark splash | resources asserted; both rendered on the emulator (light shown fully; dark captured during the transition) |
| 5 | Notification icon | white silhouette with transparency at every density (asserted); present in the release APK; **not** seen in a posted notification |
| 6 | In-app rendering | widget tests (header, About, not-connected, square un-tinted logo); header and splash seen on the emulator |
| 7 | Dashboard | not accessible: contract and handoff only |
| 8 | `flutter analyze packages apps tools` | no issues |
| 9 | Widget tests | `branding_test`, `assistant_test`, `device_assistant_test`, `router_test` (41 together), SDK navigation and list tests (12) |
| 10 | Debug APK | built |
| 11 | Release | `NEXA_DEBUG_SIGN=1 flutter build apk --release --split-per-abi --target-platform android-arm64` built (97.7 MB, debug-signed, local only); a signed release needs the release key (`docs/mobile/RELEASE.md`) |
| 12 | Device | **emulator only** (`sdk_gphone16k_arm64`, Android 16 / API 36): launcher label and icon in the app drawer, light and dark splash, app header. Not run on the Xiaomi or the Nubia |
| – | Kotlin | `:nexa_assistant:testDebugUnitTest` green; built APK declares `app_name` AMEER, `application-label-ar` أمير, adaptive icon with background, foreground and monochrome, `nexa_notification_icon` kept by the shrinker |

## 11. Known limitations

* No physical-phone check; themed (monochrome) icons were not seen on a launcher
  that supports them (Android 13+), only rendered in the preview.
* The notification icon was verified as a resource, not as a posted notification
  on API 24–36.
* The icon uses a dark-brown background for contrast; a light background would
  make the glow disappear and was not chosen.
* The logo symbol is about 43 % of the launcher icon width (safe-area rule).
* The wake phrase, iOS, the dashboard and the playground screens are unchanged
  (see §6, §7).
* Preparing the source needs Pillow; the generator is a script, not a Flutter
  package.
