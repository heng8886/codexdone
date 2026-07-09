#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOME_DIR="${CODEX_DONE_HOME:-$HOME}"
INSTALL_DIR="${CODEX_DONE_INSTALL_DIR:-$HOME_DIR/.local/bin}"
CLI_TARGET="$INSTALL_DIR/codex-done"
CLI_SOURCE="$ROOT_DIR/codex-done"
CODEX_DIR="$HOME_DIR/.codex"
CONFIG_PATH="$CODEX_DIR/config.toml"
AGENTS_PATH="$CODEX_DIR/AGENTS.md"
WRAPPER_PATH="$CODEX_DIR/codexdone-notify-wrapper.sh"
REMOVE_CLI=1
REMOVE_WRAPPER=1
UNLOAD_LAUNCH_AGENT=1

usage() {
  cat <<'USAGE'
Usage: scripts/uninstall.sh [--keep-cli] [--keep-wrapper] [--keep-launch-agent]

Safely disables CodexDone user-level Codex integration:
  - removes CodexDone from ~/.codex/config.toml notify
  - removes the CodexDone block from ~/.codex/AGENTS.md
  - removes ~/.codex/codexdone-notify-wrapper.sh
  - removes ~/.local/bin/codex-done only when it points to this checkout
  - preserves ~/.codex-done user config, env, logs, and state

Environment overrides:
  CODEX_DONE_HOME=/tmp/home
  CODEX_DONE_INSTALL_DIR=/custom/bin
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-cli)
      REMOVE_CLI=0
      ;;
    --keep-wrapper)
      REMOVE_WRAPPER=0
      ;;
    --keep-launch-agent)
      UNLOAD_LAUNCH_AGENT=0
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

python3 - "$CONFIG_PATH" "$WRAPPER_PATH" <<'PY'
import json
import sys
from pathlib import Path

config_path = Path(sys.argv[1])
wrapper_path = sys.argv[2]

if not config_path.exists():
    raise SystemExit(0)

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

text = config_path.read_text(encoding="utf-8")
output: list[str] = []

for line in text.splitlines():
    if not is_notify_line(line) or "codexdone-notify-wrapper.sh" not in line:
        output.append(line)
        continue

    values = parse_values(line)
    if values and values[0].endswith("SkyComputerUseClient"):
        stripped = remove_codexdone_previous(values)
        if stripped:
            output.append(toml_notify(stripped))
        else:
            output.append("# CodexDone disabled previous notify: " + line)
    else:
        output.append("# CodexDone disabled notify: " + line)

config_path.write_text("\n".join(output).rstrip() + "\n", encoding="utf-8")
PY

python3 - "$AGENTS_PATH" <<'PY'
import re
import sys
from pathlib import Path

agents_path = Path(sys.argv[1])
if not agents_path.exists():
    raise SystemExit(0)

text = agents_path.read_text(encoding="utf-8")
start = "<!-- codexdone:global-hook:start -->"
end = "<!-- codexdone:global-hook:end -->"
header = "## CodexDone Task Completion Notification"

if start in text and end in text:
    pattern = re.compile(re.escape(start) + r".*?" + re.escape(end) + r"\n?", re.S)
    text = pattern.sub("", text)
elif header in text:
    start_index = text.index(header)
    next_header = text.find("\n## ", start_index + len(header))
    end_index = len(text) if next_header == -1 else next_header
    text = text[:start_index] + text[end_index:]

text = re.sub(r"\n{3,}", "\n\n", text).strip()
if text:
    text += "\n"
agents_path.write_text(text, encoding="utf-8")
PY

if [[ "$REMOVE_WRAPPER" == "1" ]]; then
  rm -f "$WRAPPER_PATH"
fi

if [[ "$REMOVE_CLI" == "1" && -L "$CLI_TARGET" ]]; then
  target="$(readlink "$CLI_TARGET")"
  if [[ "$target" == "$CLI_SOURCE" ]]; then
    rm -f "$CLI_TARGET"
  fi
fi

if [[ "$UNLOAD_LAUNCH_AGENT" == "1" ]]; then
  PLIST_PATH="$HOME_DIR/Library/LaunchAgents/local.codexdone.app.plist"
  GUI_DOMAIN="gui/$(id -u)"
  if [[ -f "$PLIST_PATH" ]]; then
    launchctl bootout "$GUI_DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
    rm -f "$PLIST_PATH"
  fi
fi

cat <<SUMMARY
CodexDone global integration disabled.

Updated:
  config:  $CONFIG_PATH
  rule:    $AGENTS_PATH

Removed when owned by this checkout:
  cli:     $CLI_TARGET
  wrapper: $WRAPPER_PATH

Preserved:
  $HOME_DIR/.codex-done

To install again:
  scripts/install.sh
SUMMARY
