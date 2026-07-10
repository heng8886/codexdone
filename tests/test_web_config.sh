#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
CONFIG_PATH="$TMP_DIR/config.json"
SERVER_LOG="$TMP_DIR/server.log"
PORT="$(python3 - <<'PY'
import socket

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
SERVER_PID=""

cleanup() {
  if [[ -n "$SERVER_PID" ]]; then
    kill "$SERVER_PID" >/dev/null 2>&1 || true
    wait "$SERVER_PID" >/dev/null 2>&1 || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

printf '%s\n' '{"version":1,"alert":{"mode":"voice","desktopNotification":true,"mobilePush":false}}' >"$CONFIG_PATH"

CODEX_DONE_CONFIG="$CONFIG_PATH" \
CODEX_DONE_WEB_PORT="$PORT" \
node "$ROOT_DIR/CodexDoneWebPreview/server.js" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!

ACTUAL_PORT=""
for _ in $(seq 1 50); do
  ACTUAL_PORT="$(sed -n 's|.*http://127\.0\.0\.1:\([0-9][0-9]*\).*|\1|p' "$SERVER_LOG" | tail -n 1)"
  if [[ -n "$ACTUAL_PORT" ]]; then
    break
  fi
  sleep 0.1
done

if [[ -z "$ACTUAL_PORT" ]]; then
  cat "$SERVER_LOG" >&2
  printf 'Web Preview did not report its listening port\n' >&2
  exit 1
fi

curl -fsS "http://127.0.0.1:$ACTUAL_PORT/api/config" >"$TMP_DIR/legacy-response.json"

python3 - "$TMP_DIR/legacy-response.json" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    response = json.load(handle)
if response["config"]["alert"].get("enabled") is not True:
    raise SystemExit("legacy Web Preview config did not default enabled")
PY

curl -fsS \
  -H 'Content-Type: application/json' \
  -d '{"config":{"version":1,"alert":{"enabled":false,"mode":"voice","desktopNotification":true,"mobilePush":false}}}' \
  "http://127.0.0.1:$ACTUAL_PORT/api/config" >"$TMP_DIR/save-response.json"

curl -fsS "http://127.0.0.1:$ACTUAL_PORT/api/status" >"$TMP_DIR/status-response.json"

python3 - "$TMP_DIR/save-response.json" "$CONFIG_PATH" "$TMP_DIR/status-response.json" <<'PY'
import json
import sys

for path in sys.argv[1:3]:
    with open(path, "r", encoding="utf-8") as handle:
        value = json.load(handle)
    config = value.get("config", value)
    if config["alert"].get("enabled") is not False:
        raise SystemExit(f"disabled Web Preview state was not preserved in {path}")

with open(sys.argv[3], "r", encoding="utf-8") as handle:
    status = json.load(handle)
if status.get("notificationsEnabled") is not False:
    raise SystemExit("status API did not report persisted disabled state")
PY

if ! grep -Fq '<span>通知总开关</span><strong>${persistedNotificationsEnabled()' "$ROOT_DIR/CodexDoneWebPreview/public/app.js"; then
  printf 'Web status page does not use persisted notification state\n' >&2
  exit 1
fi

if ! grep -Fq '通知已暂停，未发送测试提醒' "$ROOT_DIR/CodexDoneWebPreview/public/app.js"; then
  printf 'Web test actions do not explain paused suppression\n' >&2
  exit 1
fi

printf 'ok - Web Preview notification switch verified\n'
