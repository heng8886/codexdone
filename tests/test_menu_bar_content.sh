#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MENU_VIEW="$ROOT_DIR/CodexDoneApp/Sources/CodexDoneApp/Views/MenuBarContentView.swift"
INTEGRATION_VIEW="$ROOT_DIR/CodexDoneApp/Sources/CodexDoneApp/Views/CodexIntegrationSettingsView.swift"

if rg -q 'copyCodexRule|复制 Codex 工作规则' "$MENU_VIEW"; then
  printf 'menu bar still exposes the Codex rule copy action\n' >&2
  exit 1
fi

rg -q 'copyCodexRule' "$INTEGRATION_VIEW"
rg -q '复制工作规则' "$INTEGRATION_VIEW"

printf 'ok - menu bar actions verified\n'
