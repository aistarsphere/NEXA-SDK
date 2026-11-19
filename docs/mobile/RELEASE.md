# LABEEB Android release build

Written for plan task G-03. Facts below were checked on the built artifacts on
2026-11-04; nothing here has been run on a device yet.

## One-time: the release key

Create `apps/nexa_example/android/key.properties` (never committed; ignored by
`android/.gitignore` together with `*.jks` / `*.keystore`):

```properties
storeFile=/absolute/path/to/labeeb-release.jks
storePassword=…
keyAlias=…
keyPassword=…
```

Create the key once and back it up outside the repository: losing it means
users cannot be updated. Play App Signing is recommended for the store.

## Build

```bash
cd apps/nexa_example
# Beta bundle (store) — uses key.properties, shrinks code and resources
flutter build appbundle --release --dart-define-from-file=$HOME/.nexa/nexa_release.json \
  --build-name=1.1.0 --build-number=<CI run number> --obfuscate --split-debug-info=build/symbols
# Side-load APK for testers (one per ABI; arm64-v8a is the one to hand out)
flutter build apk --release --split-per-abi --dart-define-from-file=…
```

* Without `key.properties` the build **stops** with a message. It never
  produces a debug-signed or unsigned release by accident.
* A local, **non-distributable** release for a test phone (for example
  `flutter run --release`) must say so: `NEXA_DEBUG_SIGN=1 flutter run --release`.
* The version name/number come from the flags (CI sets the number); they
  default to `pubspec.yaml`.
* Keep `build/symbols` and `build/app/outputs/mapping/release/mapping.txt`
  with the build: they de-obfuscate crash reports.
* Release builds contain no developer tools and no in-app token entry; the
  gateway URL, app id and language come from the `--dart-define` file. A
  production build has no credential source until a host backend exists (B2).

## What the release build enforces (checked on the APK, 2026-11-04)

| Check | How | Result |
|---|---|---|
| No cleartext traffic | `aapt2 dump xmltree --file AndroidManifest.xml app-arm64-v8a-release.apk` | `usesCleartextTraffic=false` (debug and profile manifests set `true` for the local gateway) |
| Shrinking on | `isMinifyEnabled`/`isShrinkResources`, `proguard-rules.pro` | built; `mapping.txt` produced |
| Signing refused when missing | `flutter build apk --release` without key | Gradle error, no APK |
| In-call service declared | merged manifest | `CallForegroundService` present, type microphone |

## Size (`--split-per-abi`, debug-signed local build)

| ABI | Size |
|---|---|
| arm64-v8a | 96.7 MB |
| armeabi-v7a | 79.8 MB |
| x86_64 | 108.5 MB |

The size is dominated by the ONNX Runtime and the speaker model (see
`ANDROID-ASSISTANT-REPORT.md`); moving the model to an on-demand asset is task
G-01/h6.

## Not done / not verified

* **Not run on a device.** R8 can remove code reached only by JNI or
  reflection (WebRTC, ONNX Runtime). The keep rules are a first version; a
  release smoke run on the Xiaomi and the Nubia (call, wake phrase, assistant
  panel) is required before distribution (T-M12-06).
* No release key exists yet; no `appbundle` was built (it needs the key).
* `NexaEnvironment`: real-backend builds still use `staging` policies; a
  `production` policy for the Beta build is a product decision (certificate
  pinning, verbose logs off) and is open.
* The gateway is reached by IP (`https://52.58.22.19/nexa/api`); a hostname
  with a normal certificate is a backend item.
