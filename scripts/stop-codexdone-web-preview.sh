#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="${CODEX_DONE_WEB_PID_FILE:-$ROOT_DIR/.codexdone-web-preview.pid}"
SCREEN_SESSION="${CODEX_DONE_WEB_SCREEN_SESSION:-codexdone-web-preview}"

if [[ ! -f "$PID_FILE" ]]; then
  screen -S "$SCREEN_SESSION" -X quit >/dev/null 2>&1 || true
  printf 'CodexDone Web Preview is not running.\n'
  exit 0
fi

pid="$(cat "$PID_FILE")"
rm -f "$PID_FILE"

if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
  kill "$pid"
  screen -S "$SCREEN_SESSION" -X quit >/dev/null 2>&1 || true
  printf 'Stopped CodexDone Web Preview. PID: %s\n' "$pid"
else
  screen -S "$SCREEN_SESSION" -X quit >/dev/null 2>&1 || true
  printf 'CodexDone Web Preview process is not running.\n'
fi
