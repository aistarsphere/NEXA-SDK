#!/usr/bin/env bash
# End-to-end on a device/simulator: starts the reference gateway (and a local
# livekit-server when installed), runs the example app's integration tests,
# then stops everything. Usage: tool/e2e.sh [device-id] [test-file]
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:-}"
TARGET="${2:-integration_test}"
PORT="${NEXA_E2E_PORT:-8080}"
LK_PORT="${NEXA_E2E_LIVEKIT_PORT:-7880}"
GW_FLAGS=(--port "$PORT" --delta-ms 20 --verbose)
LK_PID=""
if command -v livekit-server >/dev/null 2>&1; then
  if ! curl -sf "http://127.0.0.1:$LK_PORT/" >/dev/null 2>&1; then
    livekit-server --dev --bind 127.0.0.1 >/tmp/nexa-livekit.log 2>&1 &
    LK_PID=$!
    for i in $(seq 1 30); do curl -sf "http://127.0.0.1:$LK_PORT/" >/dev/null && break; sleep 1; done
  fi
  GW_FLAGS+=(--livekit-url "ws://127.0.0.1:$LK_PORT" --agent-audio "$PWD/tools/nexa_reference_gateway/assets/agent_tone.ogg")
  # Android emulators reach the host through 10.0.2.2.
  case "$DEVICE" in emulator-*) GW_FLAGS+=(--livekit-public-url "ws://10.0.2.2:$LK_PORT");; esac
else
  echo "livekit-server not installed: voice e2e will be skipped by the gateway (403)"
fi
dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart "${GW_FLAGS[@]}" &
GW=$!
trap 'kill $GW 2>/dev/null || true; [ -n "$LK_PID" ] && kill $LK_PID 2>/dev/null || true' EXIT
for i in $(seq 1 30); do curl -sf "http://127.0.0.1:$PORT/healthz" >/dev/null && break; sleep 1; done
# iOS simulator: pre-grant the microphone so the OS prompt does not block.
if [ -n "$DEVICE" ] && xcrun simctl list devices booted 2>/dev/null | grep -q "$DEVICE"; then
  xcrun simctl privacy "$DEVICE" grant microphone com.nexa.nexaExample || true
fi
# Android emulators: `flutter test` reinstalls the app (resetting runtime
# permissions), so keep granting the microphone in the background until the
# run ends; the journey test uses an always-granting NexaPermissionHandler so
# no OS dialog appears.
GRANT_PID=""
case "$DEVICE" in emulator-*)
  ( for i in $(seq 1 300); do
      adb -s "$DEVICE" shell pm grant com.nexa.nexa_example android.permission.RECORD_AUDIO >/dev/null 2>&1 || true
      sleep 2
    done ) &
  GRANT_PID=$!;;
esac
trap 'kill $GW 2>/dev/null || true; [ -n "$LK_PID" ] && kill $LK_PID 2>/dev/null || true; [ -n "$GRANT_PID" ] && kill $GRANT_PID 2>/dev/null || true' EXIT
cd apps/nexa_example
# iOS simulators deadlock CoreAudio when WebRTC opens the microphone
# (SetProperty RPC timeout); run the voice journey muted there and prove the
# microphone path on Android / physical devices.
DEFINE_FLAG=""
if [ "${NEXA_E2E_START_MUTED:-}" = "1" ]; then DEFINE_FLAG="--dart-define=NEXA_E2E_START_MUTED=true"; fi
if [ -n "$DEVICE" ]; then
  flutter test "$TARGET" -d "$DEVICE" $DEFINE_FLAG
else
  flutter test "$TARGET" $DEFINE_FLAG
fi
