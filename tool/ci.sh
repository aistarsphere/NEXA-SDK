#!/usr/bin/env bash
# The gate a change must pass before it is merged (plan G-05):
#   format + analyze + every package's tests (check.sh),
#   generated files in sync, a debug APK builds, Kotlin unit tests.
# Needs the Flutter/Android toolchain of .ai/mobile.md §2 and a JDK 17.
set -euo pipefail
cd "$(dirname "$0")/.."

./tool/check.sh

echo "== generated files are up to date"
./tool/gen.sh >/dev/null
if ! git diff --quiet -- packages apps; then
  echo "Generated files differ from the committed ones; run tool/gen.sh and commit:" >&2
  git status --short -- packages apps >&2
  exit 1
fi

echo "== android: debug APK"
(cd apps/nexa_example && flutter build apk --debug)

echo "== android: Kotlin unit tests"
(cd apps/nexa_example/android && ./gradlew :nexa_assistant:testDebugUnitTest)

echo "CI PASSED"
