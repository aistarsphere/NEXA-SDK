#!/usr/bin/env bash
# Repeatable code generation: freezed/json/retrofit/injectable + gen-l10n.
set -euo pipefail
cd "$(dirname "$0")/.."
for pkg in packages/nexa_core packages/nexa_sdk; do
  echo "== build_runner: $pkg"
  (cd "$pkg" && dart run build_runner build --delete-conflicting-outputs)
done
echo "== gen-l10n: packages/nexa_ui"
(cd packages/nexa_ui && flutter gen-l10n)
