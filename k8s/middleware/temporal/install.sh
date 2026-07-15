#!/bin/bash
# install.sh — Temporal 工作流引擎 (单体模式)
# 用法: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NS="temporal-simple"

kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$SCRIPT_DIR/temporal-simple-mysql.yaml"
kubectl apply -f "$SCRIPT_DIR/temporal-simple.yaml"

echo ""
echo "✅ Temporal 单体模式部署完成"
echo "   Web UI: kubectl port-forward -n $NS svc/temporal-web 8080:80"
echo "   查看: kubectl -n $NS get pods"
