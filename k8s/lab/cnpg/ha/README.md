# CNPG 1主2从 HA 集群验证

## 架构

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  PostgreSQL  │     │  PostgreSQL  │     │  PostgreSQL  │
│  Master      │◄────│  Replica     │◄────│  Replica     │
│  (同步)      │     │  (同步/异步) │     │  (异步)      │
└──────┬───────┘     └─────────────┘     └─────────────┘
       │
       ├── 9187 (metrics) → ServiceMonitor → VMAgent
       │
       └── MinIO (barman backup)
            ├── WAL 归档 (实时)
            └── 基础备份 (每日, 7天保留)
```

## 组件

| 文件 | 说明 |
|------|------|
| `cluster.yaml` | 3 节点 HA Cluster CR，MinIO 备份，预建应用数据库 |
| `secret.yaml` | MinIO 备份凭据 |
| `app-creds.yaml` | 业务应用（Gitea/Kite）数据库密码 |
| `monitoring.yaml` | ServiceMonitor 配置 |
| `chaos-test.sh` | 混沌测试脚本 |

## 验证步骤

```bash
# 1. 部署
kubectl apply -k .

# 2. 等待所有 Pod 就绪（约 2-3 分钟）
kubectl wait pod -l app.kubernetes.io/name=postgres \
  -n postgres --for=condition=Ready --timeout=180s

# 3. 检查复制状态
kubectl -n postgres exec postgres-1 -- psql -U postgres \
  -c "SELECT pid, usename, application_name, state, sync_state FROM pg_stat_replication;"

# 4. 验证预建数据库
kubectl -n postgres exec postgres-1 -- psql -U postgres \
  -c "\l gitea" -c "\l kite"

# 5. 运行混沌测试
bash chaos-test.sh all
```
