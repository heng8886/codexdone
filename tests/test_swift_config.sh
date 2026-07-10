#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT="$(mktemp "${TMPDIR:-/tmp}/codexdone-swift-config.XXXXXX")"

cleanup() {
  rm -f "$OUTPUT"
}
trap cleanup EXIT

swiftc \
  "$ROOT_DIR/CodexDoneApp/Sources/CodexDoneCore/CodexDoneConfig.swift" \
  "$ROOT_DIR/CodexDoneApp/Sources/CodexDoneCore/NotificationSwitch.swift" \
  "$ROOT_DIR/tests/NotificationMasterSwitchConfigCheck.swift" \
  -o "$OUTPUT"

"$OUTPUT"
