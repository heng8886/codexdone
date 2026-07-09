#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
UNINSTALL_SCRIPT="$ROOT_DIR/scripts/uninstall.sh"
status=0

printf '\nCodexDone 一键卸载/恢复\n'
printf '项目目录：%s\n\n' "$ROOT_DIR"

if [[ ! -x "$UNINSTALL_SCRIPT" ]]; then
  printf '找不到可执行卸载脚本：%s\n' "$UNINSTALL_SCRIPT" >&2
  status=1
else
  cd "$ROOT_DIR" || status=1
  if [[ "$status" -eq 0 ]]; then
    "$UNINSTALL_SCRIPT"
    status=$?
  fi
fi

printf '\n'
if [[ "$status" -eq 0 ]]; then
  printf 'CodexDone 全局接入已停用。\n'
else
  printf 'CodexDone 卸载/恢复失败，退出码：%s\n' "$status" >&2
fi

if [[ -t 0 ]]; then
  printf '\n按回车键关闭窗口...'
  read -r _ || true
fi

exit "$status"
