#!/bin/bash
# install.sh — MySQL 8.4
# 用法: bash install.sh [standalone|cluster]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-standalone}"
MYSQL_NS="mysql"

case "$MODE" in
  standalone)
    kubectl create namespace "$MYSQL_NS" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$SCRIPT_DIR/manifests/"
    kubectl rollout status statefulset/mysql -n "$MYSQL_NS" --timeout=180s
    echo ""
    echo "✅ MySQL Standalone 部署完成"
    echo "   连接: mysql -h mysql.${MYSQL_NS}.svc.cluster.local -u root -p'mysql@czw'"
    ;;

  cluster)
    OPERATOR_NS="mysql-operator"
    CHART_VERSION="1.1.0"
    CHART_FILE="$SCRIPT_DIR/helm/ps-operator-${CHART_VERSION}.tgz"

    if [ ! -f "$CHART_FILE" ]; then
      echo ">> 下载 Percona Operator chart ${CHART_VERSION} ..."
      helm repo add percona https://percona.github.io/percona-helm-charts/ 2>/dev/null || true
      helm pull percona/ps-operator --version "$CHART_VERSION" --destination "$SCRIPT_DIR/helm/"
      mv "$SCRIPT_DIR/helm/ps-operator-${CHART_VERSION}.tgz" "$CHART_FILE" 2>/dev/null || true
    fi

    if ! helm list -n "$OPERATOR_NS" 2>/dev/null | grep -q ps-operator; then
      echo ">> 安装 Percona Operator ..."
      helm upgrade --install ps-operator "$CHART_FILE" \
        --namespace "$OPERATOR_NS" --create-namespace \
        --values "$SCRIPT_DIR/helm/values-operator.yaml" \
        --timeout 5m --wait
      kubectl rollout status deployment/mysql-operator -n "$OPERATOR_NS" --timeout=120s
    fi

    kubectl create namespace "$MYSQL_NS" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$SCRIPT_DIR/operator/common/"
    kubectl apply -f "$SCRIPT_DIR/operator/cluster/"

    echo ""
    echo "✅ MySQL InnoDB Cluster 部署完成"
    echo "   连接: mysql -h mysql-cluster-haproxy.${MYSQL_NS}.svc.cluster.local -u root -p'mysql@czw'"
    echo "   查看: kubectl get perconaservermysql -n $MYSQL_NS -w"
    ;;

  *)
    echo "用法: $0 [standalone|cluster]"
    exit 1
    ;;
esac
