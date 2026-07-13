#!/bin/bash
# uninstall.sh - 移除 act_runner + ci-deployer SA
# 用法: bash uninstall.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

kubectl delete -f "$SCRIPT_DIR/runner.yaml" --ignore-not-found
kubectl delete -f "$SCRIPT_DIR/ci-deployer.yaml" --ignore-not-found

echo "✅ Runner 已移除"
