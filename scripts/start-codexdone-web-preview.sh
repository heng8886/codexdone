#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER="$ROOT_DIR/CodexDoneWebPreview/server.js"
PORT="${CODEX_DONE_WEB_PORT:-51429}"
PID_FILE="${CODEX_DONE_WEB_PID_FILE:-$ROOT_DIR/.codexdone-web-preview.pid}"
LOG_FILE="${CODEX_DONE_WEB_LOG:-$ROOT_DIR/.codexdone-web-preview.log}"
SCREEN_SESSION="${CODEX_DONE_WEB_SCREEN_SESSION:-codexdone-web-preview}"

if [[ "${1:-}" == "--foreground" ]]; then
  exec node "$SERVER"
fi

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(cat "$PID_FILE")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" >/dev/null 2>&1; then
    printf 'CodexDone Web Preview is already running. PID: %s\n' "$existing_pid"
    grep -Eo 'http://127\.0\.0\.1:[0-9]+' "$LOG_FILE" | tail -n 1 || true
    exit 0
  fi
  rm -f "$PID_FILE"
fi

if command -v screen >/dev/null 2>&1; then
  screen -S "$SCREEN_SESSION" -X quit >/dev/null 2>&1 || true
  printf -v screen_command 'cd %q && CODEX_DONE_WEB_PORT=%q node %q >%q 2>&1' "$ROOT_DIR" "$PORT" "$SERVER" "$LOG_FILE"
  screen -dmS "$SCREEN_SESSION" bash -lc "$screen_command"
else
  CODEX_DONE_WEB_PORT="$PORT" nohup node "$SERVER" >"$LOG_FILE" 2>&1 &
  pid="$!"
  disown "$pid" 2>/dev/null || true
  printf '%s\n' "$pid" >"$PID_FILE"
fi

sleep 1

url="$(grep -Eo 'http://127\.0\.0\.1:[0-9]+' "$LOG_FILE" | tail -n 1 || true)"
if [[ -n "$url" ]]; then
  actual_port="${url##*:}"
  pid="$(lsof -nP -t -iTCP:"$actual_port" -sTCP:LISTEN | head -n 1 || true)"
fi

if [[ -z "${pid:-}" ]] || ! kill -0 "$pid" >/dev/null 2>&1; then
  rm -f "$PID_FILE"
  printf 'CodexDone Web Preview failed to start. Log:\n' >&2
  sed -n '1,120p' "$LOG_FILE" >&2
  exit 1
fi

printf '%s\n' "$pid" >"$PID_FILE"
printf 'CodexDone Web Preview started. PID: %s\n' "$pid"
printf '%s\n' "$url"
