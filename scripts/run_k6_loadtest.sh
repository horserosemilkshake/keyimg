#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:4000}"
VUS="${VUS:-100}"
DURATION="${DURATION:-20s}"
PAYLOAD_BYTES="${PAYLOAD_BYTES:-256}"

if ! command -v k6 >/dev/null 2>&1; then
  echo "k6 is not installed."
  echo "Install: https://k6.io/docs/get-started/installation/"
  exit 1
fi

BASE_URL="$BASE_URL" \
VUS="$VUS" \
DURATION="$DURATION" \
PAYLOAD_BYTES="$PAYLOAD_BYTES" \
  k6 run loadtest/k6_images.js
