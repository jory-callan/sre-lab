#!/bin/bash
# run.sh — 极简 Ansible playbook 运行入口
# 用法: bash run.sh <playbook>
# 示例: bash run.sh linux-init
#       bash run.sh docker
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
INVENTORY="$DIR/inventories/production/hosts.ini"

[[ $# -lt 1 ]] && {
    echo "用法: bash run.sh <playbook>"
 echo "  playbook: linux-init | docker | k3s | lb"
    echo ""
    echo "卸载（手动运行，不自动执行）:"
    echo "  bash run.sh k3s --tags uninstall -l <host>   # 软卸载，保留数据"
    echo "  bash run.sh k3s --tags purge -l <host>       # 彻底销毁，清理所有数据"
    exit 1
}

PLAYBOOK="$1"
shift

echo "▶ 运行 playbook: $PLAYBOOK"
cd "$DIR"
ansible-playbook "playbooks/${PLAYBOOK}.yml" -i "$INVENTORY" "$@"
echo "✅ $PLAYBOOK 完成"
