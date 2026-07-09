#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT_DIR/codex-done"
INSTALL_DIR="${CODEX_DONE_INSTALL_DIR:-$HOME/.local/bin}"
TARGET="$INSTALL_DIR/codex-done"

if [[ ! -x "$SOURCE" ]]; then
  printf 'codex-done is not executable at %s\n' "$SOURCE" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"
ln -sf "$SOURCE" "$TARGET"

printf 'Installed codex-done symlink:\n%s -> %s\n' "$TARGET" "$SOURCE"
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    printf '\nAdd this directory to PATH if needed:\nexport PATH="%s:$PATH"\n' "$INSTALL_DIR"
    ;;
esac
