# MySQL 8.4

## 部署架构

### Standalone 模式（原生 manifests）
```
┌────────────────────────────────┐
│   MySQL 8.4 单实例             │
│   percona/percona-server:8.4.8 │
│   5Gi PVC (local-path)         │
│   NodePort: 30005              │
│   部署方式: kubectl apply       │
└────────────────────────────────┘
```

### Cluster 模式（Percona Operator）
```
┌─────────────────────────────────────────────┐
│         Percona PS Operator v1.1.0          │
└─────────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │  InnoDB Cluster x3   │
         │  group-replication    │
         │  5Gi PVC × 3         │
         │  HAProxy + Router    │
         │  NodePort: 30005     │
         └──────────────────────┘
```

## 快速开始

```bash
# Standalone 模式（默认）
./install.sh

# Cluster 模式
./install.sh cluster
```

## 验收确认

```bash
# Standalone
kubectl get pods -n mysql
mysql -h <节点IP> -P 30005 -u root -p'mysql@czw' -e "SELECT VERSION();"

# Cluster
kubectl get perconaservermysql -n mysql
mysql -h <节点IP> -P 30005 -u root -p'mysql@czw' -e "SELECT * FROM performance_schema.replication_group_members;"
```

## 默认密码

| 用户 | 密码 | 说明 |
|------|------|------|
| root | mysql@czw | 超级管理员 |

## 连接地址

| 模式 | 类型 | 地址 | 端口 |
|------|------|------|------|
| Standalone | 集群外 NodePort | `<节点IP>` | 30005 |
| Standalone | 集群内 | `mysql.mysql.svc.cluster.local` | 3306 |
| Cluster 主库 | 集群外 NodePort | `<节点IP>` | 30005 |
| Cluster 主库 | 集群内 | `mysql-cluster-haproxy.mysql.svc.cluster.local` | 3306 |
| Cluster 只读 | 集群内 | `mysql-cluster-haproxy.mysql.svc.cluster.local` | 3307 |

## 卸载

```bash
./uninstall.sh           # 卸载 standalone
./uninstall.sh cluster   # 卸载 cluster（含 operator）
./uninstall.sh all       # 卸载全部
```
