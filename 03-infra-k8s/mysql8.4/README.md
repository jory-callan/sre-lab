# MySQL 8.4

## 部署架构

```
┌─────────────────────────────────────────────────────────────────┐
│                     Percona PS Operator                         │
│              percona-server-mysql-operator:1.1.0                │
│         监听 PerconaServerMySQL CR，自动管理 MySQL 实例          │
└─────────────────────────────────────────────────────────────────┘
                               │
                    ┌──────────┴──────────┐
                    ▼                     ▼
     ┌──────────────────────┐  ┌──────────────────────────┐
     │  Standalone Mode     │  │  Cluster Mode             │
     │  ┌────────────────┐  │  │  ┌────────────────────┐  │
     │  │  MySQL 8.4 x1  │  │  │  │  MySQL 8.4 x3      │  │
     │  │  5Gi PVC       │  │  │  │  (group-replication)│  │
     │  └────────────┬───┘  │  │  │  5Gi PVC × 3       │  │
     │               │       │  │  └────────┬───────────┘  │
     │  NodePort:30005│       │  │  ┌────────────────────┐  │
     │               │       │  │  │  HAProxy x3        │  │
     │               │       │  │  │  (读写分离)         │  │
     │               │       │  │  └────────┬───────────┘  │
     │               │       │  │  ┌────────────────────┐  │
     │               │       │  │  │  MySQL Router x3   │  │
     │               │       │  │  └────────────────────┘  │
     │               │       │  │  NodePort:30005          │
     └───────────────┼───────┘  └────────┬─────────────────┘
                     ▼                   ▼
              ┌──────────────┐ ┌──────────────────────┐
              │ 集群外访问    │ │ 集群外访问（主库）    │
              │ mysql -P30005│ │ mysql -P30005         │
              └──────────────┘ └──────────────────────┘
```

## 快速开始

```bash
# Standalone 模式（默认）
./install.sh

# 或 InnoDB Cluster 模式
./install.sh cluster
```

## 验收确认

```bash
# 查看 CR 状态
kubectl get perconaservermysql -n mysql

# 查看 Pod
kubectl get pods -n mysql

# 连接测试（standalone）
mysql -h <节点IP> -P 30005 -u root -p'mysql@czw' -e "SELECT VERSION();"

# 连接测试（cluster）
mysql -h <节点IP> -P 30005 -u root -p'mysql@czw' -e "SELECT * FROM performance_schema.replication_group_members;"
```

## 默认密码

| 用户 | 密码 | 说明 |
|------|------|------|
| root | mysql@czw | 超级管理员 |
| monitor | mysql@czw | 监控用户 |
| operator | mysql@czw | Operator 管理用户 |
| replication | mysql@czw | 复制用户 |

## 连接地址

| 模式 | 类型 | 地址 | 端口 |
|------|------|------|------|
| Standalone | 集群外 NodePort | `<节点IP>` | 30005 |
| Standalone | 集群内 | `mysql-standalone-primary.mysql.svc.cluster.local` | 3306 |
| Cluster | 集群外 NodePort | `<节点IP>` | 30005 |
| Cluster 主库 | 集群内 | `mysql-cluster-haproxy.mysql.svc.cluster.local` | 3306 |
| Cluster 只读 | 集群内 | `mysql-cluster-haproxy.mysql.svc.cluster.local` | 3307 |

## 卸载

```bash
./uninstall.sh           # 卸载 standalone CR，保留 operator
./uninstall.sh cluster   # 卸载 cluster CR，保留 operator
./uninstall.sh all       # 卸载全部（含 operator）
```
