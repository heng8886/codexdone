#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${CODEX_DONE_HOME:-$HOME}"
INSTALL_DIR="${CODEX_DONE_INSTALL_DIR:-$HOME_DIR/.local/bin}"
CLI_SOURCE="$ROOT_DIR/codex-done"
CLI_TARGET="$INSTALL_DIR/codex-done"
CODEX_DIR="$HOME_DIR/.codex"
CONFIG_PATH="$CODEX_DIR/config.toml"
AGENTS_PATH="$CODEX_DIR/AGENTS.md"
WRAPPER_PATH="$CODEX_DIR/codexdone-notify-wrapper.sh"
SKY_CLIENT="$CODEX_DIR/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
APP_DIR="$ROOT_DIR/dist/CodexDone.app"
BUILD_APP="${CODEX_DONE_BUILD_APP:-1}"
OPEN_APP="${CODEX_DONE_OPEN_APP:-1}"

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [--no-build] [--no-open]

Installs CodexDone for the current user:
  - links codex-done into ~/.local/bin
  - installs ~/.codex/codexdone-notify-wrapper.sh
  - connects Codex notify to the wrapper
  - adds the global CodexDone instruction block to ~/.codex/AGENTS.md
  - optionally builds and opens dist/CodexDone.app

Environment overrides:
  CODEX_DONE_HOME=/tmp/home
  CODEX_DONE_INSTALL_DIR=/custom/bin
  CODEX_DONE_BUILD_APP=0
  CODEX_DONE_OPEN_APP=0
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-build)
      BUILD_APP=0
      ;;
    --no-open)
      OPEN_APP=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [[ ! -x "$CLI_SOURCE" ]]; then
  printf 'codex-done is not executable at %s\n' "$CLI_SOURCE" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$CODEX_DIR"
ln -sf "$CLI_SOURCE" "$CLI_TARGET"

cat >"$WRAPPER_PATH" <<WRAPPER
#!/usr/bin/env bash
set -u

SKY_CLIENT="\${CODEX_DONE_SKY_CLIENT:-$SKY_CLIENT}"
CODEX_DONE_COMMAND="\${CODEX_DONE_COMMAND:-$CLI_TARGET}"
LOG_FILE="\${HOME}/.codex/codexdone-notify-wrapper.log"
EVENT_NAME="\${1:-turn-ended}"
MESSAGE="\${CODEX_DONE_NOTIFY_MESSAGE:-Codex 本轮工作已完成}"

log() {
  printf '[%s] %s\\n' "\$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "\$*" >> "\${LOG_FILE}" 2>/dev/null || true
}

recent_codexdone_event_exists() {
  python3 - "\${HOME}/.codex-done/events.jsonl" <<'PY'
import json
import os
import sys
import time
from pathlib import Path

events_path = Path(sys.argv[1])
window = float(os.environ.get("CODEX_DONE_NOTIFY_DEDUP_SECONDS", "30"))

if window <= 0 or not events_path.exists():
    sys.exit(1)

try:
    lines = events_path.read_text(encoding="utf-8").splitlines()
except OSError:
    sys.exit(1)

now = time.time()
for line in reversed(lines[-50:]):
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        continue

    epoch = float(event.get("epoch") or 0)
    age = now - epoch
    if age > window:
        break

    if event.get("source") == "codex-done":
        sys.exit(0)

sys.exit(1)
PY
}

log "notify hook received event=\${EVENT_NAME} cwd=\${PWD}"

SHOULD_SKIP_DEFAULT_CODEX_DONE=0
case "\${EVENT_NAME}" in
  turn-ended|taskCompleted|completed|done|"")
    if recent_codexdone_event_exists; then
      SHOULD_SKIP_DEFAULT_CODEX_DONE=1
    fi
    ;;
esac

if [[ -x "\${SKY_CLIENT}" ]]; then
  if [[ "\${EVENT_NAME}" == "turn-ended" && "\$#" -lt 2 ]]; then
    log "skip original notify client because payload was not supplied"
  else
    "\${SKY_CLIENT}" "\$@" >> "\${LOG_FILE}" 2>&1 || log "original notify client failed"
  fi
fi

case "\${EVENT_NAME}" in
  turn-ended|taskCompleted|completed|done|"")
    if [[ "\${SHOULD_SKIP_DEFAULT_CODEX_DONE}" == "1" ]]; then
      log "skip default codex-done because a recent codex-done event already exists"
      exit 0
    fi

    if [[ -x "\${CODEX_DONE_COMMAND}" ]]; then
      "\${CODEX_DONE_COMMAND}" --event taskCompleted "\${MESSAGE}" >> "\${LOG_FILE}" 2>&1 || log "codex-done command failed"
    elif command -v codex-done >/dev/null 2>&1; then
      codex-done --event taskCompleted "\${MESSAGE}" >> "\${LOG_FILE}" 2>&1 || log "codex-done command failed"
    else
      log "codex-done command not found"
    fi
    ;;
  *)
    log "skip codex-done for unsupported event=\${EVENT_NAME}"
    ;;
esac

exit 0
WRAPPER
chmod 755 "$WRAPPER_PATH"

python3 - "$CONFIG_PATH" "$WRAPPER_PATH" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
wrapper_path = sys.argv[2]

def is_notify_line(line: str) -> bool:
    return line.lstrip().startswith("notify =")

def parse_values(line: str) -> list[str]:
    if "=" not in line:
        return []
    raw = line.split("=", 1)[1].strip()
    try:
        values = json.loads(raw)
    except json.JSONDecodeError:
        return []
    return values if isinstance(values, list) and all(isinstance(v, str) for v in values) else []

def toml_notify(values: list[str]) -> str:
    return "notify = " + json.dumps(values, separators=(",", ":"))

def direct_values() -> list[str]:
    return [wrapper_path, "turn-ended"]

def is_codexdone(value: str) -> bool:
    return wrapper_path in value or "codexdone-notify-wrapper.sh" in value

def remove_codexdone_previous(values: list[str]) -> list[str]:
    output: list[str] = []
    index = 0
    while index < len(values):
        if values[index] == "--previous-notify" and index + 1 < len(values) and is_codexdone(values[index + 1]):
            index += 2
            continue
        output.append(values[index])
        index += 1
    return output

text = config_path.read_text(encoding="utf-8") if config_path.exists() else ""
lines = text.splitlines()
output: list[str] = []
replaced = False

for line in lines:
    if not is_notify_line(line):
        output.append(line)
        continue

    replaced = True
    if is_codexdone(line):
        output.append(line)
        continue

    values = parse_values(line)
    if values and "SkyComputerUseClient" in values[0]:
        values = remove_codexdone_previous(values)
        values.extend(["--previous-notify", json.dumps(direct_values(), separators=(",", ":"))])
        output.append(toml_notify(values))
    else:
        output.append("# CodexDone saved previous notify: " + line)
        output.append(toml_notify(direct_values()))

if not replaced:
    output.append(toml_notify(direct_values()))

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")
PY

python3 - "$AGENTS_PATH" <<'PY'
import sys
from pathlib import Path

agents_path = Path(sys.argv[1])
start = "<!-- codexdone:global-hook:start -->"
end = "<!-- codexdone:global-hook:end -->"
header = "CodexDone Task Completion Notification"
block = f"""{start}
## {header}

Whenever you complete a stage of work and are about to send the final reply, run `codex-done` if it is available. Use one short sentence to summarize what was completed.

Examples:

```bash
codex-done "本阶段工作已经完成"
codex-done --event testPassed "测试已通过"
codex-done --event testFailed "测试失败，需要查看日志"
codex-done --event needsAttention "需要你确认下一步"
```

If `codex-done` is unavailable or the notification fails, do not interrupt the task; reply normally and mention the notification failure briefly.
{end}
"""

text = agents_path.read_text(encoding="utf-8") if agents_path.exists() else ""
if start not in text and header not in text:
    if text and not text.endswith("\n"):
        text += "\n"
    if text:
        text += "\n"
    text += block + "\n"
    agents_path.parent.mkdir(parents=True, exist_ok=True)
    agents_path.write_text(text, encoding="utf-8")
PY

if [[ "$BUILD_APP" == "1" ]]; then
  if ! "$ROOT_DIR/scripts/build-codexdone-app.sh"; then
    printf 'Warning: app build failed; CLI and Codex hook installation still completed.\n' >&2
  fi
fi

if [[ "$OPEN_APP" == "1" && -d "$APP_DIR" ]]; then
  open "$APP_DIR" >/dev/null 2>&1 || true
fi

cat <<SUMMARY
CodexDone install complete.

CLI:
  $CLI_TARGET -> $CLI_SOURCE

Codex global hook:
  config:  $CONFIG_PATH
  wrapper: $WRAPPER_PATH
  rule:    $AGENTS_PATH

Next:
  - Open CodexDone and run Codex 集成 > 链路诊断 > 测试全局 hook.
  - If Apple Messages is enabled, macOS may ask for permission to control Messages.
  - If your shell cannot find codex-done, add this to your shell config:
    export PATH="$INSTALL_DIR:\$PATH"

Restore/disable:
  scripts/uninstall.sh
SUMMARY
