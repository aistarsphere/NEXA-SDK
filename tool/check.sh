#!/usr/bin/env bash
# Format check, static analysis and tests for every package.
set -euo pipefail
cd "$(dirname "$0")/.."
echo "== format"
# apps/*/build holds iOS SwiftPM checkouts (third-party Dart); format only sources.
dart format --output=none --set-exit-if-changed packages tools apps/*/lib apps/*/test apps/*/integration_test
echo "== analyze"
flutter analyze packages apps tools
for pkg in packages/nexa_core tools/nexa_reference_gateway; do
  echo "== dart test: $pkg"; (cd "$pkg" && dart test)
done
for pkg in packages/nexa_ui packages/nexa_realtime packages/nexa_sdk apps/nexa_example; do
  echo "== flutter test: $pkg"; (cd "$pkg" && flutter test)
done
echo "ALL CHECKS PASSED"
