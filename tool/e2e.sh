#!/usr/bin/env bash
# End-to-end: starts the reference gateway, runs the example app's
# integration_test on a device/simulator (default: first iOS simulator or
# `-d <id>`), then stops the gateway.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-}"
PORT="${NEXA_E2E_PORT:-8080}"
dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart --port "$PORT" --delta-ms 20 --verbose &
GW=$!
trap 'kill $GW 2>/dev/null || true' EXIT
for i in $(seq 1 30); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done
cd apps/nexa_example
if [ -n "$DEVICE" ]; then
  flutter test integration_test -d "$DEVICE"
else
  flutter test integration_test
fi
