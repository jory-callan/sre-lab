# Temporal 常用命令速查表
# ==========================================
# 部署信息
# ==========================================
# - 命名空间: temporal-simple
# - Web UI Service: temporal-simple-web
# - Frontend Service: temporal-simple-frontend
# - MySQL Service: temporal-simple-mysql
# ==========================================

# ==========================================
# 一、快速开始（最常用）
# ==========================================

# 1. 开启端口转发（Web UI + Frontend）
kubectl port-forward -n temporal-simple svc/temporal-simple-web 8080:8080
kubectl port-forward -n temporal-simple svc/temporal-simple-frontend 7233:7233
# 然后浏览器访问: http://localhost:8080

# 2. 查看 Pod 状态
kubectl get pods -n temporal-simple

# 3. 查看 Server 日志
kubectl logs -n temporal-simple deploy/temporal-simple-server -f --tail=50

# 4. 进入 Admin Tools
kubectl exec -it -n temporal-simple deploy/temporal-simple-admintools -- sh

# ==========================================
# 二、Namespace 操作（重要！）
# ==========================================

# 注意：推荐用封装脚本 temporal-tool.sh！防止忘记 1年 Retention！
# 用法: ./temporal-tool.sh create-ns <name>

# 2.1 列出所有 Namespaces
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal operator namespace list \
  --address temporal-simple-frontend:7233

# 2.2 查看 Namespace 详情
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal operator namespace describe default \
  --address temporal-simple-frontend:7233

# 2.3 创建 Namespace（手动指定 1年 Retention！）
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal operator namespace create my-namespace \
  --address temporal-simple-frontend:7233 \
  --retention 8760h0m0s  # 1年 = 8760小时

# 2.4 更新 Namespace Retention 为 1年
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal operator namespace update my-namespace \
  --address temporal-simple-frontend:7233 \
  --retention 8760h0m0s

# 2.5 删除 Namespace
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal operator namespace delete my-namespace \
  --address temporal-simple-frontend:7233

# ==========================================
# 三、Workflow 操作
# ==========================================

# 3.1 列出 Workflows
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal workflow list \
  --address temporal-simple-frontend:7233 \
  --namespace default

# 3.2 查看 Workflow 详情
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal workflow describe <workflow-id> \
  --address temporal-simple-frontend:7233 \
  --namespace default

# 3.3 终止 Workflow
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal workflow terminate <workflow-id> \
  --address temporal-simple-frontend:7233 \
  --namespace default

# ==========================================
# 四、排查问题
# ==========================================

# 4.1 查看所有 Pod 详情
kubectl describe pods -n temporal-simple

# 4.2 查看 Server 事件
kubectl get events -n temporal-simple --sort-by='.lastTimestamp'

# 4.3 查看 Service
kubectl get svc -n temporal-simple

# 4.4 查看 ConfigMap
kubectl get configmap -n temporal-simple
kubectl describe configmap temporal-simple-config -n temporal-simple

# ==========================================
# 五、部署管理
# ==========================================

# 5.1 重启 Server（加载新配置）
kubectl rollout restart deployment/temporal-simple-server -n temporal-simple
kubectl rollout status deployment/temporal-simple-server -n temporal-simple --timeout=120s

# 5.2 重启 Web UI
kubectl rollout restart deployment/temporal-simple-web -n temporal-simple

# 5.3 重启 MySQL
kubectl rollout restart deployment/temporal-simple-mysql -n temporal-simple

# 5.4 部署（重新应用配置）
kubectl apply -f /root/temporal-deploy/temporal-simple.yaml

# 5.5 删除整个部署（谨慎！）
kubectl delete namespace temporal-simple

# ==========================================
# 六、封装脚本使用（推荐！）
# ==========================================
# 先给脚本执行权限: chmod +x /root/temporal-deploy/temporal-tool.sh

# 6.1 创建 Namespace（自动 1年 Retention！）
./temporal-tool.sh create-ns my-namespace

# 6.2 列出 Namespaces
./temporal-tool.sh list-ns

# 6.3 查看 Namespace 详情
./temporal-tool.sh describe-ns my-namespace

# 6.4 快速验证部署
./temporal-tool.sh verify

# 6.5 开启端口转发
./temporal-tool.sh port-forward

# 6.6 查看帮助
./temporal-tool.sh help

# ==========================================
# 七、生产验证检查清单
# ==========================================
# 部署后按以下步骤检查：
#
# 1. [ ] 所有 Pod 都是 Running/Completed
# 2. [ ] 能访问 Web UI: http://localhost:8080
# 3. [ ] 能创建 Namespace，Retention 是 1年
# 4. [ ] Server 日志没有 ERROR
# 5. [ ] admin-tools 能正常执行命令
# 6. [ ] MySQL 正常运行
#
# ==========================================

# ==========================================
# 八、开发环境 → 生产环境升级
# ==========================================
# 只需要修改副本数！
#
# 编辑 temporal-simple.yaml，找到:
#   spec:
#     replicas: 1  # 改成 3-5
#
# 然后重新部署: kubectl apply -f /root/temporal-deploy/temporal-simple.yaml
#
# ==========================================
