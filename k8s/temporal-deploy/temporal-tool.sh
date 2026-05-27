#!/bin/bash
# ==========================================
# Temporal 常用工具脚本
# ==========================================
# 作用：封装常用操作，防止忘记指定 1年 Retention
# ==========================================

# 配置项
TEMPORAL_ADDR="${TEMPORAL_ADDR:-temporal-simple-frontend:7233}"
NAMESPACE="${NAMESPACE:-temporal-simple}"
RETENTION="${RETENTION:-8760h0m0s}"  # 默认 1年

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. 创建 Namespace（自动带 1年 Retention）
create_ns() {
    local ns_name="$1"
    if [ -z "$ns_name" ]; then
        echo -e "${RED}错误：请指定 Namespace 名称！${NC}"
        echo "用法: $0 create-ns <namespace-name>"
        return 1
    fi
    
    echo -e "${YELLOW}正在创建 Namespace: ${ns_name} (Retention: ${RETENTION})...${NC}"
    kubectl exec -n "$NAMESPACE" deploy/temporal-simple-admintools -- \
        temporal operator namespace create "$ns_name" \
        --address "$TEMPORAL_ADDR" \
        --retention "$RETENTION"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Namespace ${ns_name} 创建成功！${NC}"
    else
        echo -e "${RED}❌ Namespace 创建失败！${NC}"
    fi
}

# 2. 查看所有 Namespaces
list_ns() {
    echo -e "${YELLOW}所有 Namespaces:${NC}"
    kubectl exec -n "$NAMESPACE" deploy/temporal-simple-admintools -- \
        temporal operator namespace list --address "$TEMPORAL_ADDR"
}

# 3. 查看某个 Namespace 详情
describe_ns() {
    local ns_name="$1"
    if [ -z "$ns_name" ]; then
        echo -e "${RED}错误：请指定 Namespace 名称！${NC}"
        echo "用法: $0 describe-ns <namespace-name>"
        return 1
    fi
    
    echo -e "${YELLOW}Namespace ${ns_name} 详情:${NC}"
    kubectl exec -n "$NAMESPACE" deploy/temporal-simple-admintools -- \
        temporal operator namespace describe "$ns_name" --address "$TEMPORAL_ADDR"
}

# 4. 删除 Namespace
delete_ns() {
    local ns_name="$1"
    if [ -z "$ns_name" ]; then
        echo -e "${RED}错误：请指定 Namespace 名称！${NC}"
        echo "用法: $0 delete-ns <namespace-name>"
        return 1
    fi
    
    echo -e "${YELLOW}正在删除 Namespace: ${ns_name}...${NC}"
    read -p "确认删除？(y/N) " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        kubectl exec -n "$NAMESPACE" deploy/temporal-simple-admintools -- \
            temporal operator namespace delete "$ns_name" --address "$TEMPORAL_ADDR"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Namespace ${ns_name} 删除成功！${NC}"
        fi
    fi
}

# 5. 更新 Namespace Retention 为 1年
update_retention() {
    local ns_name="$1"
    if [ -z "$ns_name" ]; then
        echo -e "${RED}错误：请指定 Namespace 名称！${NC}"
        echo "用法: $0 update-retention <namespace-name>"
        return 1
    fi
    
    echo -e "${YELLOW}正在更新 Namespace ${ns_name} 的 Retention 为 1年...${NC}"
    kubectl exec -n "$NAMESPACE" deploy/temporal-simple-admintools -- \
        temporal operator namespace update "$ns_name" \
        --address "$TEMPORAL_ADDR" \
        --retention "$RETENTION"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Retention 更新成功！${NC}"
        describe_ns "$ns_name"
    fi
}

# 6. 查看 Pod 状态
status() {
    echo -e "${YELLOW}Pod 状态:${NC}"
    kubectl get pods -n "$NAMESPACE"
}

# 7. 查看 Server 日志
logs() {
    echo -e "${YELLOW}Server 日志（最后 50 行）:${NC}"
    kubectl logs -n "$NAMESPACE" deploy/temporal-simple-server --tail=50
}

# 8. 进入 Admin Tools
shell() {
    echo -e "${YELLOW}进入 Admin Tools Shell...${NC}"
    kubectl exec -it -n "$NAMESPACE" deploy/temporal-simple-admintools -- sh
}

# 9. 开启端口转发
port-forward() {
    echo -e "${YELLOW}正在开启端口转发...${NC}"
    echo "- Web UI: http://localhost:8080"
    echo "- Frontend: localhost:7233"
    
    # 在后台运行
    kubectl port-forward -n "$NAMESPACE" svc/temporal-simple-web 8080:8080 > /tmp/temporal-web.log 2>&1 &
    PID_WEB=$!
    
    kubectl port-forward -n "$NAMESPACE" svc/temporal-simple-frontend 7233:7233 > /tmp/temporal-frontend.log 2>&1 &
    PID_FRONTEND=$!
    
    echo -e "${GREEN}✅ 端口转发已开启！${NC}"
    echo "  Web UI PID: $PID_WEB"
    echo "  Frontend PID: $PID_FRONTEND"
    echo ""
    echo "停止方法："
    echo "  kill $PID_WEB $PID_FRONTEND"
}

# 10. 快速验证
verify() {
    echo -e "${YELLOW}=== 1. Pod 状态 ===${NC}"
    kubectl get pods -n "$NAMESPACE"
    
    echo -e "\n${YELLOW}=== 2. Namespace 列表 ===${NC}"
    list_ns
    
    echo -e "\n${YELLOW}=== 3. 测试 Namespace（检查默认 Retention） ===${NC}"
    local test_ns="verify-$(date +%s)"
    create_ns "$test_ns" > /dev/null 2>&1
    describe_ns "$test_ns" | grep "RetentionTtl"
    delete_ns "$test_ns" > /dev/null 2>&1
    
    echo -e "\n${GREEN}✅ 验证完成！${NC}"
}

# 帮助信息
usage() {
    echo "Temporal 常用工具脚本"
    echo "========================="
    echo "用法: $0 <command> [args]"
    echo ""
    echo "Commands:"
    echo "  create-ns <name>       - 创建 Namespace（自动 1年 Retention）"
    echo "  list-ns                - 列出所有 Namespaces"
    echo "  describe-ns <name>    - 查看 Namespace 详情"
    echo "  delete-ns <name>      - 删除 Namespace"
    echo "  update-retention <name> - 更新 Namespace Retention 为 1年"
    echo "  status                - 查看 Pod 状态"
    echo "  logs                  - 查看 Server 日志"
    echo "  shell                 - 进入 Admin Tools"
    echo "  port-forward          - 开启端口转发（Web UI 和 Frontend）"
    echo "  verify                - 快速验证部署"
    echo "  help                  - 显示帮助"
    echo ""
    echo "环境变量（可选）："
    echo "  TEMPORAL_ADDR - Temporal Server 地址（默认：temporal-simple-frontend:7233）"
    echo "  NAMESPACE    - Kubernetes Namespace（默认：temporal-simple）"
    echo "  RETENTION    - 默认 Retention（默认：8760h0m0s）"
}

# 主函数
main() {
    case "$1" in
        create-ns) create_ns "$2" ;;
        list-ns) list_ns ;;
        describe-ns) describe_ns "$2" ;;
        delete-ns) delete_ns "$2" ;;
        update-retention) update_retention "$2" ;;
        status) status ;;
        logs) logs ;;
        shell) shell ;;
        port-forward) port-forward ;;
        verify) verify ;;
        help|--help|-h) usage ;;
        *)
            echo -e "${RED}错误：未知命令 $1${NC}"
            usage
            return 1
            ;;
    esac
}

main "$@"
