#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="${TMPDIR:-/tmp}/codexdone-install-tests-$$"
TEST_HOME="$TMP_DIR/home"
INSTALL_DIR="$TEST_HOME/.local/bin"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$1" >&2
  exit 1
}

assert_file_exists() {
  [[ -e "$1" ]] || fail "expected file to exist: $1"
}

assert_executable() {
  [[ -x "$1" ]] || fail "expected executable file: $1"
}

assert_not_exists() {
  [[ ! -e "$1" ]] || fail "expected file to be absent: $1"
}

assert_contains() {
  local file="$1"
  local expected="$2"
  grep -Fq -- "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if [[ -e "$file" ]] && grep -Fq -- "$unexpected" "$file"; then
    fail "expected $file not to contain: $unexpected"
  fi
}

mkdir -p "$TEST_HOME/.codex"
cat >"$TEST_HOME/.codex/config.toml" <<'CONFIG'
model = "gpt-test"
notify = ["/tmp/home/.codex/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient","turn-ended"]
CONFIG

cat >"$TEST_HOME/.codex/AGENTS.md" <<'AGENTS'
## Existing Rule

Keep this rule.
AGENTS

mkdir -p "$TEST_HOME/.codex-done"
printf 'keep=true\n' >"$TEST_HOME/.codex-done/config.json"

CODEX_DONE_HOME="$TEST_HOME" \
CODEX_DONE_INSTALL_DIR="$INSTALL_DIR" \
CODEX_DONE_BUILD_APP=0 \
CODEX_DONE_OPEN_APP=0 \
  "$ROOT_DIR/scripts/install.sh" >/tmp/codexdone-install-test-install.log

assert_file_exists "$INSTALL_DIR/codex-done"
[[ -L "$INSTALL_DIR/codex-done" ]] || fail "expected codex-done symlink"
assert_executable "$TEST_HOME/.codex/codexdone-notify-wrapper.sh"
assert_contains "$TEST_HOME/.codex/config.toml" "codexdone-notify-wrapper.sh"
assert_contains "$TEST_HOME/.codex/config.toml" "--previous-notify"
assert_contains "$TEST_HOME/.codex/config.toml" "SkyComputerUseClient"
assert_contains "$TEST_HOME/.codex/AGENTS.md" "CodexDone Task Completion Notification"
assert_contains "$TEST_HOME/.codex/AGENTS.md" "## Existing Rule"

STUB_COMMAND="$TMP_DIR/codex-done-stub"
cat >"$STUB_COMMAND" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_DONE_STUB_LOG"
STUB
chmod +x "$STUB_COMMAND"
STUB_LOG="$TMP_DIR/codex-done-stub.log"

python3 - "$TEST_HOME/.codex-done/events.jsonl" <<'PY'
import json
import sys
import time
from pathlib import Path

path = Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
event = {
    "id": "recent-other-cwd",
    "timestamp": "2026-07-09T00:00:00Z",
    "epoch": time.time(),
    "eventType": "taskCompleted",
    "project": "OtherProject",
    "rawMessage": "具体总结内容",
    "message": "OtherProject: 具体总结内容",
    "cwd": "/tmp/other-project",
    "pid": 123,
    "source": "codex-done",
    "status": "completed",
}
path.write_text(json.dumps(event, ensure_ascii=False) + "\n", encoding="utf-8")
PY

HOME="$TEST_HOME" \
CODEX_DONE_COMMAND="$STUB_COMMAND" \
CODEX_DONE_STUB_LOG="$STUB_LOG" \
  "$TEST_HOME/.codex/codexdone-notify-wrapper.sh" turn-ended

assert_not_exists "$STUB_LOG"
assert_contains "$TEST_HOME/.codex/codexdone-notify-wrapper.log" "recent codex-done event already exists"

HOME="$TEST_HOME" \
CODEX_DONE_COMMAND="$STUB_COMMAND" \
CODEX_DONE_STUB_LOG="$STUB_LOG" \
CODEX_DONE_NOTIFY_DEDUP_SECONDS=0 \
  "$TEST_HOME/.codex/codexdone-notify-wrapper.sh" turn-ended

assert_file_exists "$STUB_LOG"
assert_contains "$STUB_LOG" "--event taskCompleted Codex 本轮工作已完成"

CODEX_DONE_HOME="$TEST_HOME" \
CODEX_DONE_INSTALL_DIR="$INSTALL_DIR" \
CODEX_DONE_BUILD_APP=0 \
CODEX_DONE_OPEN_APP=0 \
  "$ROOT_DIR/scripts/install.sh" >/tmp/codexdone-install-test-install-again.log

[[ "$(grep -Fo -- "codexdone-notify-wrapper.sh" "$TEST_HOME/.codex/config.toml" | wc -l | tr -d ' ')" == "1" ]] \
  || fail "expected one CodexDone wrapper reference after repeated install"
[[ "$(grep -Fo -- "CodexDone Task Completion Notification" "$TEST_HOME/.codex/AGENTS.md" | wc -l | tr -d ' ')" == "1" ]] \
  || fail "expected one CodexDone AGENTS block after repeated install"

CODEX_DONE_HOME="$TEST_HOME" \
CODEX_DONE_INSTALL_DIR="$INSTALL_DIR" \
  "$ROOT_DIR/scripts/uninstall.sh" >/tmp/codexdone-install-test-uninstall.log

assert_not_exists "$TEST_HOME/.codex/codexdone-notify-wrapper.sh"
assert_not_exists "$INSTALL_DIR/codex-done"
assert_contains "$TEST_HOME/.codex/config.toml" "SkyComputerUseClient"
assert_not_contains "$TEST_HOME/.codex/config.toml" "codexdone-notify-wrapper.sh"
assert_not_contains "$TEST_HOME/.codex/config.toml" "--previous-notify"
assert_contains "$TEST_HOME/.codex/AGENTS.md" "## Existing Rule"
assert_not_contains "$TEST_HOME/.codex/AGENTS.md" "CodexDone Task Completion Notification"
assert_file_exists "$TEST_HOME/.codex-done/config.json"

CODEX_DONE_HOME="$TEST_HOME" \
CODEX_DONE_INSTALL_DIR="$INSTALL_DIR" \
CODEX_DONE_BUILD_APP=0 \
CODEX_DONE_OPEN_APP=0 \
  "$ROOT_DIR/install-codexdone.command" >/tmp/codexdone-install-test-command-install.log

assert_file_exists "$INSTALL_DIR/codex-done"
assert_executable "$TEST_HOME/.codex/codexdone-notify-wrapper.sh"
assert_contains "$TEST_HOME/.codex/config.toml" "codexdone-notify-wrapper.sh"
assert_contains "$TEST_HOME/.codex/AGENTS.md" "CodexDone Task Completion Notification"

CODEX_DONE_HOME="$TEST_HOME" \
CODEX_DONE_INSTALL_DIR="$INSTALL_DIR" \
  "$ROOT_DIR/uninstall-codexdone.command" >/tmp/codexdone-install-test-command-uninstall.log

assert_not_exists "$TEST_HOME/.codex/codexdone-notify-wrapper.sh"
assert_not_exists "$INSTALL_DIR/codex-done"
assert_not_contains "$TEST_HOME/.codex/config.toml" "codexdone-notify-wrapper.sh"
assert_not_contains "$TEST_HOME/.codex/AGENTS.md" "CodexDone Task Completion Notification"

printf 'ok - install scripts verified\n'
