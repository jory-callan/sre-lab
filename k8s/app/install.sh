#!/bin/bash
# install.sh — 批量安装所有 app
# Usage: bash install.sh [install|uninstall|purge]
#   install    部署所有 app（幂等）
#   uninstall  卸载所有 app，保留数据
#   purge      完全卸载所有 app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APPS=(
  "kdebug"
  "kite"
)

ACTION="${1:-install}"

for app in "${APPS[@]}"; do
  INSTALL_SCRIPT="$SCRIPT_DIR/$app/test-default/install.sh"
  if [ -f "$INSTALL_SCRIPT" ]; then
    echo "========================================"
    echo "[$ACTION] $app..."
    echo "========================================"
    bash "$INSTALL_SCRIPT" "$ACTION"
    echo ""
  else
    echo "[WARN] $app: 未找到 $INSTALL_SCRIPT，跳过"
  fi
done

echo "========================================"
echo "所有 app 处理完成: $ACTION"
echo "========================================"
