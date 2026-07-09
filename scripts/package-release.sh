#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/CodexDone.app"
RELEASE_DIR="${CODEX_DONE_RELEASE_DIR:-$ROOT_DIR/dist/releases}"
VERSION="${1:-${CODEX_DONE_RELEASE_VERSION:-}}"

usage() {
  cat <<'USAGE'
Usage: scripts/package-release.sh [version]

Builds dist/CodexDone.app and creates a zip package plus sha256 checksum under
dist/releases. The optional version is used in the output filename.

Examples:
  scripts/package-release.sh
  scripts/package-release.sh v0.1.0
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if [[ -z "$VERSION" ]]; then
  if git -C "$ROOT_DIR" rev-parse --short HEAD >/dev/null 2>&1; then
    VERSION="$(date +%Y%m%d)-$(git -C "$ROOT_DIR" rev-parse --short HEAD)"
  else
    VERSION="$(date +%Y%m%d)"
  fi
fi

SAFE_VERSION="${VERSION//\//-}"
PACKAGE_NAME="CodexDone-macos-$SAFE_VERSION"
ZIP_PATH="$RELEASE_DIR/$PACKAGE_NAME.zip"
SHA_PATH="$ZIP_PATH.sha256"

"$ROOT_DIR/scripts/build-codexdone-app.sh"

if [[ ! -d "$APP_DIR" ]]; then
  printf 'App bundle not found: %s\n' "$APP_DIR" >&2
  exit 1
fi

mkdir -p "$RELEASE_DIR"
rm -f "$ZIP_PATH" "$SHA_PATH"

(
  cd "$ROOT_DIR/dist"
  ditto -c -k --keepParent "CodexDone.app" "$ZIP_PATH"
)

shasum -a 256 "$ZIP_PATH" >"$SHA_PATH"

cat <<SUMMARY
Release package created:
  $ZIP_PATH
  $SHA_PATH

Upload both files to a GitHub Release.
SUMMARY
