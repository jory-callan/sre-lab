#!/bin/bash
# install.sh - 部署 act_runner + ci-deployer SA
# 用法: bash install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── ci-deployer ServiceAccount (集群级) ──────────────
kubectl apply -f "$SCRIPT_DIR/ci-deployer.yaml"

# ── act_runner ───────────────────────────────────────
kubectl apply -f "$SCRIPT_DIR/runner.yaml"

# ── 等待 runner 就绪 ─────────────────────────────────
kubectl -n gitea-runner rollout status deploy/gitea-runner --timeout=120s

echo ""
echo "✅ Runner 部署完成"
echo ""
echo "   检查: kubectl -n gitea-runner get pods"
echo "   日志: kubectl -n gitea-runner logs deploy/gitea-runner --tail=20"
echo ""
echo "   ci-deployer token (存到 Gitea Secret KUBE_TOKEN):"
echo "   kubectl -n kube-system get secret ci-deployer-token -o jsonpath='{.data.token}' | base64 -d"
echo ""
