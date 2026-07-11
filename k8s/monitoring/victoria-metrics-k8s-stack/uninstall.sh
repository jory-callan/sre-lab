#!/bin/bash
# uninstall.sh — victoria-metrics-k8s-stack 卸载
# 用法: bash uninstall.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="vm-stack"

echo ">> 卸载 VictoriaLogs Collector ..."
helm uninstall vmlogs-collector -n "$NAMESPACE" --ignore-not-found --wait

echo ">> 卸载 VictoriaLogs ..."
helm uninstall victorialogs -n "$NAMESPACE" --ignore-not-found --wait

echo ">> 卸载 victoria-metrics-k8s-stack ..."
helm uninstall victoriametrics -n "$NAMESPACE" --ignore-not-found --wait

echo ">> 删除命名空间 $NAMESPACE ..."
kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait=true

echo ""
echo "✅ victoria-metrics-k8s-stack 已完全卸载"
