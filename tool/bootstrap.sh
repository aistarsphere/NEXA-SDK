#!/usr/bin/env bash
# Resolve all workspace packages (one lockfile at the root).
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
