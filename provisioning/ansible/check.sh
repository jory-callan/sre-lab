#!/bin/bash
# check.sh — dry-run (仅预览改动，不生效)
# 用法: bash check.sh <playbook>
# 示例: bash check.sh linux-init
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
INVENTORY="$DIR/inventories/production/hosts.ini"

[[ $# -lt 1 ]] && {
    echo "用法: bash check.sh <playbook>"
    echo "  playbook: linux-init | docker | k3s"
    exit 1
}

PLAYBOOK="$1"
shift

echo "▶ dry-run: $PLAYBOOK (--check --diff)"
cd "$DIR"
ansible-playbook "playbooks/${PLAYBOOK}.yml" -i "$INVENTORY" --check --diff "$@"
echo "✅ dry-run 完成"