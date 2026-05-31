#!/bin/bash
# MySQL 8.4 安装脚本
#
# 两种模式:
#   standalone: 单实例（manifests/kubectl apply）
#   cluster:   InnoDB Cluster 3 节点（Percona Operator）
#
# 用法:
#   ./install.sh              # 安装 standalone（默认）
#   ./install.sh standalone   # 同上
#   ./install.sh cluster      # 安装 InnoDB Cluster
#
# 注意: standalone 和 cluster 互斥，切换前先 ./uninstall.sh 清理

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_DIR="$SCRIPT_DIR/helm"
OPERATOR_CHART="$HELM_DIR/remote-ps-operator-1.1.0"
OPERATOR_VALUES="$HELM_DIR/values-operator.yaml"
MYSQL_NS="mysql"
OPERATOR_NS="mysql-operator"
OPERATOR_RELEASE="ps-operator"

MODE="${1:-standalone}"

case "$MODE" in
  standalone)
    echo "📦 部署模式: Standalone（原生 manifests）"
    echo ""

    kubectl create namespace "$MYSQL_NS" --dry-run=client -o yaml | kubectl apply -f -

    echo "   创建 Secret..."
    kubectl apply -f "$SCRIPT_DIR/manifests/secret.yaml"

    echo "   创建 ConfigMap..."
    kubectl apply -f "$SCRIPT_DIR/manifests/configmap.yaml"

    echo "   创建 Service..."
    kubectl apply -f "$SCRIPT_DIR/manifests/service.yaml"

    echo "   创建 StatefulSet..."
    kubectl apply -f "$SCRIPT_DIR/manifests/statefulset.yaml"

    echo ""
    echo "⏳ 等待 MySQL 就绪..."
    kubectl rollout status statefulset/mysql -n "$MYSQL_NS" --timeout=180s

    echo ""
    echo "✅ MySQL Standalone 部署完成！"
    echo ""
    echo "📝 连接方式："
    echo "   集群外: mysql -h <任一节点IP> -P 30005 -u root -p'mysql@czw'"
    echo "   集群内: mysql -h mysql.mysql.svc.cluster.local -u root -p'mysql@czw'"
    echo "   密码: mysql@czw"
    ;;

  cluster)
    echo "📦 部署模式: InnoDB Cluster（Percona Operator）"
    echo ""

    # 1. 安装 operator
    if helm list -n "$OPERATOR_NS" 2>/dev/null | grep -qw "$OPERATOR_RELEASE"; then
      echo "✅ Percona Operator 已安装，跳过"
    else
      echo "📦 安装 Percona Operator..."
      if [ ! -d "$OPERATOR_CHART" ]; then
        echo "❌ 未找到离线 Chart: $OPERATOR_CHART"
        exit 1
      fi
      helm upgrade --install "$OPERATOR_RELEASE" "$OPERATOR_CHART" \
        --namespace "$OPERATOR_NS" \
        --create-namespace \
        --values "$OPERATOR_VALUES" \
        --timeout 5m \
        --wait
      echo "⏳ 等待 operator 就绪..."
      kubectl rollout status deployment/mysql-operator -n "$OPERATOR_NS" --timeout=120s
    fi

    # 2. 创建 MySQL 集群
    kubectl create namespace "$MYSQL_NS" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$SCRIPT_DIR/operator/common/"
    kubectl apply -f "$SCRIPT_DIR/operator/cluster/"

    echo ""
    echo "⏳ InnoDB Cluster 部署中（3 节点，需要等待数分钟）..."
    echo "   查看状态: kubectl get perconaservermysql -n $MYSQL_NS -w"
    echo ""
    echo "📝 连接方式："
    echo "   集群外(主库): mysql -h <任一节点IP> -P 30005 -u root -p'mysql@czw'"
    echo "   集群内(主库): mysql -h mysql-cluster-haproxy.mysql.svc.cluster.local -u root -p'mysql@czw'"
    echo "   密码: mysql@czw"
    ;;

  *)
    echo "❌ 无效模式: $MODE"
    echo "   用法: $0 [standalone|cluster]"
    exit 1
    ;;
esac
