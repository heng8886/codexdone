#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_SCRIPT="$ROOT_DIR/scripts/install.sh"
status=0

printf '\nCodexDone 一键安装\n'
printf '项目目录：%s\n\n' "$ROOT_DIR"

if [[ ! -x "$INSTALL_SCRIPT" ]]; then
  printf '找不到可执行安装脚本：%s\n' "$INSTALL_SCRIPT" >&2
  status=1
else
  cd "$ROOT_DIR" || status=1
  if [[ "$status" -eq 0 ]]; then
    "$INSTALL_SCRIPT"
    status=$?
  fi
fi

printf '\n'
if [[ "$status" -eq 0 ]]; then
  printf 'CodexDone 安装完成。\n'
else
  printf 'CodexDone 安装失败，退出码：%s\n' "$status" >&2
fi

if [[ -t 0 ]]; then
  printf '\n按回车键关闭窗口...'
  read -r _ || true
fi

exit "$status"
