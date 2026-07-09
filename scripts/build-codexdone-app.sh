#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_DIR="$ROOT_DIR/CodexDoneApp"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="CodexDone"
PRODUCT_NAME="CodexDoneApp"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$MACOS_DIR/$APP_NAME"
CLI_SOURCE="$ROOT_DIR/codex-done"
CLI_DESTINATION="$RESOURCES_DIR/codex-done"

swift build --package-path "$PACKAGE_DIR" -c release --product "$PRODUCT_NAME"

BUILT_PRODUCT="$PACKAGE_DIR/.build/release/$PRODUCT_NAME"
if [[ ! -x "$BUILT_PRODUCT" ]]; then
  printf 'Could not find built product at %s\n' "$BUILT_PRODUCT" >&2
  exit 1
fi

if [[ ! -x "$CLI_SOURCE" ]]; then
  printf 'Could not find executable codex-done at %s\n' "$CLI_SOURCE" >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$BUILT_PRODUCT" "$EXECUTABLE_PATH"
cp "$CLI_SOURCE" "$CLI_DESTINATION"
chmod +x "$EXECUTABLE_PATH" "$CLI_DESTINATION"

cat >"$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>local.codexdone.app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

printf 'APPL????' >"$CONTENTS_DIR/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

printf 'Built %s\n' "$APP_DIR"
