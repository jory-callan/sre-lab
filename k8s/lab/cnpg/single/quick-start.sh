#!/bin/bash
# CNPG 单实例快速验证
# 使用方法: bash quick-start.sh

set -euo pipefail

echo "═══ CNPG 单实例快速验证 ═══"

# 1. 创建 namespace
kubectl create namespace pg-test --dry-run=client -o yaml | kubectl apply -f -

# 2. 部署单实例 PG
echo "→ 部署单实例 PostgreSQL..."
kubectl apply -f cluster.yaml

# 3. 等待 Pod 就绪
echo "→ 等待 Pod 就绪..."
kubectl wait pod -l app.kubernetes.io/name=pg-single \
  -n pg-test --for=condition=Ready --timeout=120s

# 4. 验证连接
echo "→ 验证连接..."
POD=$(kubectl -n pg-test get pod -l app.kubernetes.io/name=pg-single -o name | head -1)
kubectl -n pg-test exec "$POD" -- psql -U postgres -c "SELECT version();"

# 5. 验证基本功能
echo "→ 创建测试表..."
kubectl -n pg-test exec "$POD" -- psql -U postgres <<-EOSQL
  CREATE TABLE IF NOT EXISTS test_hello (
    id SERIAL PRIMARY KEY,
    msg TEXT,
    ts TIMESTAMP DEFAULT NOW()
  );
  INSERT INTO test_hello (msg) VALUES ('CNPG works!');
  SELECT * FROM test_hello;
EOSQL

echo ""
echo "✓ 单实例验证通过"
echo ""
echo "清理: kubectl delete -f cluster.yaml"
