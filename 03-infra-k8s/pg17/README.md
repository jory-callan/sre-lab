# PostgreSQL 17

## 部署架构

```
┌─────────────────────────────────────────────────────────────┐
│                   CloudNativePG Operator                    │
│           CNCF 毕业项目，自动管理 PostgreSQL 集群            │
│          ghcr.io/cloudnative-pg/cloudnative-pg              │
└─────────────────────────────────────────────────────────────┘
                              │
                   ┌──────────┴──────────┐
                   ▼                     ▼
 ┌──────────────────────────┐  ┌──────────────────────────────┐
 │  Standalone Mode         │  │  HA Mode                     │
 │  ┌────────────────────┐  │  │  ┌────────────────────────┐  │
 │  │  PostgreSQL 17 x1  │  │  │  │  PostgreSQL 17 x3     │  │
 │  │  5Gi PVC           │  │  │  │  (一主二从流复制)      │  │
 │  └────────┬───────────┘  │  │  │  5Gi PVC × 3          │  │
 │           │               │  │  │  自动故障转移          │  │
 │  NodePort:30006│          │  │  └────────┬───────────────┘  │
 │           │               │  │           │                   │
 │           │               │  │  ┌────────┴───────────────┐  │
 │           │               │  │  │  RW Service (主库)      │  │
 │           │               │  │  │  RO Service (从库)      │  │
 │           │               │  │  └────────┬───────────────┘  │
 └───────────┼───────────────┘  └───────────┼──────────────────┘
             ▼                              ▼
      ┌──────────────┐             ┌────────────────┐
      │ 集群外访问    │             │ 集群外访问      │
      │ psql -P30006 │             │ psql -P30006    │
      └──────────────┘             └────────────────┘
```

## 快速开始

```bash
# Standalone 模式（默认）
./install.sh

# 或 HA 模式（3节点流复制，自动故障转移）
./install.sh ha
```

## 验收确认

```bash
# 查看 Cluster 状态
kubectl get cluster -n pg

# 查看 Pod
kubectl get pods -n pg

# 连接测试（standalone）
psql -h <节点IP> -p 30006 -U postgres -d appdb -c "SELECT version();"
# 密码: pg@czw

# HA 模式查看复制状态
kubectl exec -n pg pg-ha-1 -- psql -c "SELECT * FROM pg_stat_replication;"
```

## 默认密码

| 用户 | 密码 | 说明 |
|------|------|------|
| postgres | pg@czw | 超级管理员 |
| app | pg@czw | 应用用户（仅 appdb 权限） |

## 连接地址

| 模式 | 类型 | 地址 | 端口 |
|------|------|------|------|
| Standalone | 集群外 NodePort | `<节点IP>` | 30006 |
| Standalone | 集群内 | `pg-standalone-rw.pg.svc.cluster.local` | 5432 |
| HA 主库 | 集群外 NodePort | `<节点IP>` | 30006 |
| HA 主库 | 集群内 | `pg-ha-rw.pg.svc.cluster.local` | 5432 |
| HA 只读 | 集群内 | `pg-ha-ro.pg.svc.cluster.local` | 5432 |

## 卸载

```bash
./uninstall.sh       # 卸载 standalone CR，保留 operator
./uninstall.sh ha    # 卸载 HA CR，保留 operator
./uninstall.sh all   # 卸载全部（含 operator）
```
