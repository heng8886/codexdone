#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/CodexDone.app"
APP_EXECUTABLE="$APP_DIR/Contents/MacOS/CodexDone"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/local.codexdone.app.plist"
GUI_DOMAIN="gui/$(id -u)"

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  "$ROOT_DIR/scripts/build-codexdone-app.sh"
fi

if [[ ! -x "$APP_EXECUTABLE" ]]; then
  printf 'CodexDone app executable not found at %s\n' "$APP_EXECUTABLE" >&2
  exit 1
fi

mkdir -p "$PLIST_DIR"
cat >"$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>local.codexdone.app</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP_EXECUTABLE</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>EnvironmentVariables</key>
  <dict>
    <key>CODEX_DONE_SHOW_SETTINGS_ON_LAUNCH</key>
    <string>0</string>
  </dict>
  <key>StandardOutPath</key>
  <string>$HOME/Library/Logs/CodexDone.out.log</string>
  <key>StandardErrorPath</key>
  <string>$HOME/Library/Logs/CodexDone.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout "$GUI_DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "$GUI_DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$GUI_DOMAIN/local.codexdone.app" >/dev/null 2>&1 || true

printf 'Installed and loaded LaunchAgent:\n%s\n' "$PLIST_PATH"
