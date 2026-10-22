#!/usr/bin/env bash
# Runs the LOCAL REFERENCE GATEWAY (development infrastructure, not the NEXA
# backend). Default port 8080; pass extra flags through, e.g. --verbose.
set -euo pipefail
cd "$(dirname "$0")/.."
exec dart run tools/nexa_reference_gateway/bin/nexa_reference_gateway.dart "$@"
