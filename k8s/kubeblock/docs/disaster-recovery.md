# 故障模拟与恢复演练

> 本文档定义生产环境常见的故障场景、模拟方法、恢复步骤，
> 以及定期恢复演练的执行方案。

---

## 目录

1. [故障场景矩阵](#1-故障场景矩阵)
2. [场景一：单节点宕机](#2-场景一单节点宕机)
3. [场景二：Pod 意外删除](#3-场景二pod-意外删除)
4. [场景三：主库故障（Master 宕机）](#4-场景三主库故障master-宕机)
5. [场景四：数据误删恢复](#5-场景四数据误删恢复)
6. [场景五：磁盘空间满](#6-场景五磁盘空间满)
7. [场景六：网络分区 / CNS 故障](#7-场景六网络分区--cns-故障)
8. [恢复演练计划](#8-恢复演练计划)
9. [RTO / RPO 评估](#9-rto--rpo-评估)

---

## 1. 故障场景矩阵

| 编号 | 场景 | 影响范围 | 严重级别 | 恢复手段 | 预期 RTO | 预期 RPO |
|------|------|---------|---------|---------|---------|---------|
| F01 | 单 agent 节点宕机 | 该节点上所有 Pod | Critical | Pod 自动漂移 + PDB 保护 | < 2 min | 0（有副本） |
| F02 | Pod 被意外删除 | 单个 Pod | Warning | StatefulSet/PDB 自动重建 | < 30s | 0 |
| F03 | Redis Master 宕机 | 写入中断 | Critical | Sentinel 自动选主 | < 15s | 0 |
| F04 | 数据误删除（DROP/FLUSH） | 全部或部分数据 | Critical | 从备份恢复 | < 30 min | 取决于备份频率 |
| F05 | 磁盘空间满 | 写操作失败 | Critical | 扩容 PVC / 清理日志 | < 10 min | 0 |
| F06 | 网络分区 | 集群不可访问 | Critical | 修复网络 / 切换访问路径 | 取决于网络恢复 | 0（raft 保护） |
| F07 | 数据文件损坏 | 数据库无法启动 | Critical | 从备份恢复 | < 30 min | 取决于备份频率 |

---

## 2. 场景一：单节点宕机

### 场景描述

`agent-1` 节点因硬件故障、内核 panic 或网络中断而完全不可用。

### 预期行为

```
1. Node 状态变为 NotReady（约 40s 后）
2. 该节点上的 Pod 进入 Terminating 或 Unknown
3. PDB 评估：检查 Allowed Disruptions
4. kube-controller-manager 在 agent-2 上重建 Pod
5. Redis: 重建的从库自动同步主库数据
6. MySQL: Raft 自动选主（如果 master 在 agent-1）
```

### 模拟方法

```bash
# 模拟节点宕机（SSH 到节点并停止 kubelet，或者直接封锁节点）
kubectl cordon agent-1

# 删除该节点上所有数据库 Pod，模拟节点无法恢复场景
kubectl delete pod -n redis --field-selector spec.nodeName=agent-1
kubectl delete pod -n valkey --field-selector spec.nodeName=agent-1
kubectl delete pod -n mysql --field-selector spec.nodeName=agent-1
```

### 验证检查项

```bash
# 1. Pod 是否在另一节点重建
kubectl get pods -n redis -o wide

# 2. PDB 是否阻止了过度驱逐
kubectl get pdb -A
# ALLOWED DISRUPTIONS 列不应该为负

# 3. 集群状态是否恢复
kubectl get cluster -A

# 4. Redis 主从是否正常
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" info replication

# 5. MySQL Raft 状态
kubectl exec -n mysql apecloud-mysql-mysql-0 -- mysql -uroot -p"$(kubectl get secret -n mysql mysql-account-root -o jsonpath='{.data.password}' | base64 -d)" -e "SHOW STATUS LIKE '%raft%';"
```

### 恢复步骤

```bash
# 1. 节点恢复后，解除封锁
kubectl uncordon agent-1

# 2. 正常情况下 Pod 不会自动漂移回来（K8s 调度器不主动重平衡）
# 如果需要重新分布，可以手动删除 Pod 强制重建
kubectl delete pod -n redis redis-redis-0   # 会调度到 agent-1
kubectl delete pod -n redis redis-redis-sentinel-0
```

---

## 3. 场景二：Pod 意外删除

### 场景描述

误执行 `kubectl delete pod` 或应用滚动更新导致 Pod 被重建。

### 预期行为

```
1. Pod 被删除
2. StatefulSet Controller 立即创建新 Pod
3. 新 Pod 拉起数据库进程
4. Redis: 从库自动从主库全量同步
5. MySQL: 节点自动加入 Raft 集群
```

### 模拟与验证

```bash
# 1. 模拟删除 Redis 从库
kubectl delete pod -n redis redis-redis-1

# 2. 验证自动重建
kubectl get pods -n redis -w   # 几秒内出现新 Pod

# 3. 等待 Pod Ready
kubectl wait --for=condition=Ready pod/redis-redis-1 -n redis --timeout=120s

# 4. 验证数据同步
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" info replication
# 输出应显示 connected_slaves: 1

# 5. 验证 PDB 没有被违反
kubectl get pdb -n redis redis-pdb
# ALLOWED DISRUPTIONS 应该 >= 0
```

---

## 4. 场景三：主库故障（Master 宕机）

### 场景描述

Redis/Valkey 的 master 实例进程崩溃，只读操作正常但写操作失败。

### 预期行为（Redis Sentinel 自动故障转移）

```
1. Sentinel 检测到 master 主观下线（down-after-milliseconds）
2. Sentinel 集群投票确认客观下线（quorum >= 2）
3. Sentinel 选出一个新 master（从 slave 中选举）
4. Sentinel 通知所有 slave 切换复制目标到新 master
5. 应用端通过 Sentinel 发现新 master 地址
```

### 模拟方法

```bash
# 1. 确认当前 master
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" info replication | grep role

# 2. 强制杀掉 master 进程
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" DEBUG SLEEP 30
# 或在容器内 kill redis-server 进程
kubectl exec -n redis redis-redis-0 -- kill -9 $(kubectl exec -n redis redis-redis-0 -- pgrep redis-server)
```

### 验证检查项

```bash
# 1. 查看 Sentinel 事件日志
kubectl logs -n redis redis-redis-sentinel-0 | grep -i "failover\|switch-master\|+sdown\|+odown"

# 2. 查看自动故障转移结果
kubectl exec -n redis redis-redis-sentinel-0 -- redis-cli -p 26379 SENTINEL master redis

# 3. 确认新 master
kubectl exec -n redis redis-redis-1 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" info replication | grep role

# 4. 确认原 master 恢复后变为 slave
sleep 30
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" info replication | grep role
# 应该输出 role:slave
```

### 主动切换（计划内维护）

```bash
# Redis Sentinel 手动切换
kubectl exec -n redis redis-redis-sentinel-0 -- redis-cli -p 26379 SENTINEL FAILOVER redis

# MySQL 手动主从切换
kubectl exec -n mysql apecloud-mysql-mysql-0 -- mysql -uroot -p"$(kubectl get secret -n mysql mysql-account-root -o jsonpath='{.data.password}' | base64 -d)" -e "SELECT switchover('$TARGET_INSTANCE');"
```

---

## 5. 场景四：数据误删恢复

### 场景描述

执行了 `FLUSHALL`、`DROP TABLE` 或 `DELETE` 误删了大量数据。

### 恢复策略

```
策略 A：从全量备份恢复到新集群 → 导出数据 → 导入原集群
策略 B：PITR 恢复到误删前的时间点（仅 Redis AOF 模式支持）
策略 C：跨集群恢复（恢复为独立集群，应用切换数据源）
```

### 恢复步骤（从全量备份）

```bash
# 1. 查找最近的可用备份
kubectl get backup -n redis
# NAME                           METHOD     STATUS      TIME
# redis-redis-backup-datafile... datafile   Completed   2026-07-20 03:00

# 2. 创建恢复集群
kubectl apply -n redis -f - <<EOF
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: redis-restore-temp
  namespace: redis
spec:
  restore:
    source:
      apiGroup: dataprotection.kubeblocks.io
      kind: Backup
      name: redis-redis-backup-datafile-202607200300
      namespace: redis
  terminationPolicy: Delete
  clusterDef: redis
  topology: replication
  componentSpecs:
    - name: redis
      serviceVersion: "7.2.4"
      disableExporter: false
      replicas: 1
      resources:
        limits:
          memory: 512Mi
      volumeClaimTemplates:
        - name: data
          spec:
            storageClassName: "nfs-client"
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 5Gi
    - name: redis-sentinel
      replicas: 1
      resources:
        limits:
          memory: 256Mi
      volumeClaimTemplates:
        - name: data
          spec:
            storageClassName: "nfs-client"
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 1Gi
EOF

# 3. 等待恢复完成
kubectl get cluster -n redis redis-restore-temp -w

# 4. 从恢复集群导出数据
kubectl exec -n redis redis-restore-temp-redis-0 -- \
  redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" \
  --rdb /tmp/dump.rdb

# 5. 导入到原集群（仅限恢复场景，生产操作需谨慎）
# kubectl cp ... / redis-cli --pipe

# 6. 清理临时恢复集群
kubectl delete cluster -n redis redis-restore-temp
```

### 恢复步骤（MySQL）

```bash
# 1. 选择最近的 xtrabackup 备份
kubectl get backup -n mysql

# 2. 恢复到原集群（需先停止当前集群）
# 注意：KubeBlocks 的 restore 默认创建新集群，不是原地恢复

kubectl apply -n mysql -f - <<EOF
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: mysql-restore-temp
  namespace: mysql
spec:
  restore:
    source:
      apiGroup: dataprotection.kubeblocks.io
      kind: Backup
      name: apecloud-mysql-mysql-backup-xtrabackup-202607200320
      namespace: mysql
  terminationPolicy: Delete
  clusterDef: apecloud-mysql
  topology: apecloud-mysql
  componentSpecs:
    - name: mysql
      serviceVersion: "8.0.30"
      disableExporter: false
      replicas: 1
      resources:
        limits:
          memory: 2Gi
      volumeClaimTemplates:
        - name: data
          spec:
            storageClassName: "nfs-client"
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 10Gi
EOF

# 3. 数据导出
kubectl exec -n mysql mysql-restore-temp-mysql-0 -- \
  mysqldump -uroot -p"$(kubectl get secret -n mysql mysql-account-root -o jsonpath='{.data.password}' | base64 -d)" \
  --all-databases > /tmp/mysql-restore.sql

# 4. 导入到原集群
# kubectl cp /tmp/mysql-restore.sql mysql/mysql-pod-0:/tmp/
# kubectl exec mysql-pod-0 -- mysql -uroot -p<password> < /tmp/mysql-restore.sql
```

---

## 6. 场景五：磁盘空间满

### 场景描述

数据量增长或日志累积导致 PVC 空间不足，数据库写入失败。

### 模拟方法

```bash
# 写一个大文件填充 Redis 存储
kubectl exec -n redis redis-redis-0 -- dd if=/dev/zero of=/tmp/fill bs=1M count=4000 2>/dev/null || true
```

### 恢复步骤

```bash
# 1. 检查当前 PVC 使用量
kubectl exec -n redis redis-redis-0 -- df -h /data
kubectl get pvc -n redis

# 2. VolumeExpand（在线扩容）
kubectl patch cluster redis -n redis --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "redis",
        "volumeClaimTemplates": [
          {
            "name": "data",
            "spec": {
              "resources": {
                "requests": {
                  "storage": "10Gi"    # 从 5Gi 扩到 10Gi
                }
              }
            }
          }
        ]
      }
    ]
  }
}'

# 3. 验证扩容
kubectl get pvc -n redis -w
# 注意：NFS 支持在线扩容，不需要重启 Pod

# 4. 清理日志
# Redis 的 logfile 在 /data/running.log
kubectl exec -n redis redis-redis-0 -- truncate -s 0 /data/running.log
```

---

## 7. 场景六：网络分区 / CNS 故障

### CiliumNetworkPolicy 误阻断排查

```bash
# 1. 临时禁用网络策略
kubectl delete cnp --all -n redis

# 2. 验证数据库是否恢复访问
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" ping

# 3. 重新启用网络策略
kubectl apply -f k8s/kubeblock/common/network-policy/redis-network-policy.yaml

# 4. 如果策略导致问题，检查 Cilium 日志
kubectl logs -n kube-system -l k8s-app=cilium -c cilium-agent --tail=50 | grep -i "deny\|drop\|policy"
```

---

## 8. 恢复演练计划

### 8.1 演练频率建议

| 演练内容 | 建议频率 | 负责人 |
|---------|---------|--------|
| Pod 意外删除自动恢复 | 每月 | 应用运维 |
| 单节点宕机 Pod 漂移 | 每季度 | 平台运维 |
| Redis Sentinel 自动选主 | 每季度 | 应用运维 |
| 数据恢复（从备份） | **每季度** | DBA / 应用运维 |
| 完整容灾切换 | 每年 | 全团队 |

### 8.2 数据恢复演练脚本

每季度执行的标准化恢复演练：

```bash
#!/bin/bash
# recovery-drill.sh — 标准化恢复演练脚本
set -euo pipefail

DRILL_NS="drill-$(date +%Y%m%d)"
BACKUP_NS="${1:-redis}"  # redis / valkey / mysql

echo "=== 恢复演练开始: $(date) ==="
echo "目标实例: $BACKUP_NS"

# 1. 创建隔离 namespace
kubectl create namespace "$DRILL_NS" --dry-run=client -o yaml | kubectl apply -f -

# 2. 查找最新备份
LATEST_BACKUP=$(kubectl get backup -n "$BACKUP_NS" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1].metadata.name}')
echo "使用备份: $LATEST_BACKUP"

# 3. 执行恢复（构造恢复 Cluster）
kubectl apply -n "$DRILL_NS" -f - <<EOF
apiVersion: apps.kubeblocks.io/v1
kind: Cluster
metadata:
  name: drill-restore-$BACKUP_NS
  namespace: $DRILL_NS
spec:
  restore:
    source:
      apiGroup: dataprotection.kubeblocks.io
      kind: Backup
      name: $LATEST_BACKUP
      namespace: $BACKUP_NS
  terminationPolicy: Delete
  clusterDef: $BACKUP_NS
  topology: replication
  componentSpecs:
    - name: $BACKUP_NS
      serviceVersion: "7.2.4"
      disableExporter: false
      replicas: 1
      resources:
        limits:
          memory: 512Mi
      volumeClaimTemplates:
        - name: data
          spec:
            storageClassName: "nfs-client"
            accessModes:
              - ReadWriteOnce
            resources:
              requests:
                storage: 5Gi
EOF

# 4. 等待就绪（计时）
echo "等待恢复完成..."
START_TIME=$(date +%s)
kubectl wait --for=condition=Ready cluster/drill-restore-$BACKUP_NS -n "$DRILL_NS" --timeout=300s 2>/dev/null || true
END_TIME=$(date +%s)
RTO=$((END_TIME - START_TIME))

# 5. 验证数据
echo "验证数据可访问..."
case "$BACKUP_NS" in
  redis|valkey)
    kubectl exec -n "$DRILL_NS" drill-restore-$BACKUP_NS-$BACKUP_NS-0 -- \
      redis-cli PING
    ;;
  mysql)
    kubectl exec -n "$DRILL_NS" drill-restore-$BACKUP_NS-mysql-0 -- \
      mysql -uroot -e "SELECT 1 AS test;"
    ;;
esac

# 6. 清理
kubectl delete cluster -n "$DRILL_NS" drill-restore-$BACKUP_NS --now --wait=false
kubectl delete namespace "$DRILL_NS" --now --wait=false

echo "=== 恢复演练完成 ==="
echo "RTO: ${RTO}s"
echo "结果: ✅ 成功"
```

```bash
# 执行演练
bash recovery-drill.sh redis
bash recovery-drill.sh mysql
```

### 8.3 演练报告模板

每次演练后应记录：

```markdown
# 恢复演练报告

日期：YYYY-MM-DD
演练编号：DR-YYYY-MM-XX
实例：Redis
参与人：@xxx @xxx

## 结果

- [✅/❌] Pod 删除自动恢复（RTO: Xs）
- [✅/❌] 数据恢复（RTO: Xs，数据量: X MB）
- [✅/❌] Sentinel 选主（RTO: Xs）

## 问题记录

1. 问题描述：
   原因分析：
   改进措施：

## 结论

- 本次演练总体结果：[成功/部分成功/失败]
- 需要跟进的改进项：[...]
```

---

## 9. RTO / RPO 评估

### 当前配置下的理论值

| 组件 | 故障类型 | RTO（预期恢复时间） | RPO（最大数据丢失） |
|------|---------|-------------------|-------------------|
| **Redis** | 主库宕机（Sentinel 选主） | 5~15s | 0（同步复制） |
| **Redis** | 从库故障（自动重建） | 30s ~ 2min | 0 |
| **Redis** | 全节点故障（从备份恢复） | 15~30min | 取决于备份频率（当前最大 6h） |
| **Valkey** | 同上（兼容 Redis） | 同上 | 同上 |
| **MySQL** | 单节点故障（Raft 选主） | 10~30s | 0 |
| **MySQL** | 全节点故障（从备份恢复） | 20~40min | 取决于备份频率（当前最大 24h） |
| **MySQL** | PITR 时间点恢复 | 30~60min | < 1s（如有 binlog 归档） |

### RPO 优化建议

| 措施 | 当前 | 改进后 | 改进方式 |
|------|------|--------|---------|
| Redis AOF 增量频率 | 每 6h | 每 1h | 修改 backup-enable.yaml |
| MySQL binlog 归档 | 未启用 | 启用后 RPO < 1s | 启用 archive-binlog method |
| 全量备份频率 | 每日 | 每日两次 | 增加 cron 条目 |

---

## 附录：快速诊断命令

```bash
# 查看集群实时状态
kubectl get cluster -A -w

# 查看集群事件
kubectl describe cluster -n <ns> <name> | grep -A5 "Events:"

# 查看组件日志
kubectl logs -n <ns> <pod-name> -c <container>

# Redis 实时健康
redis-cli -h <svc-ip> -a <password> ping
redis-cli -h <svc-ip> -a <password> info replication
redis-cli -h <svc-ip> -a <password> info memory
redis-cli -h <svc-ip> -a <password> SLOWLOG GET 5

# Sentinel 状态
redis-cli -h <sentinel-svc> -p 26379 SENTINEL masters
redis-cli -h <sentinel-svc> -p 26379 SENTINEL get-master-addr-by-name <master-name>

# MySQL 健康
mysql -h <svc-ip> -uroot -p<password> -e "SHOW DATABASES;"
mysql -h <svc-ip> -uroot -p<password> -e "SHOW STATUS LIKE '%raft%';"
mysql -h <svc-ip> -uroot -p<password> -e "SHOW SLAVE STATUS\G"

# VictoriaMetrics 查询
curl -s "http://vmsingle-monitoring.monitoring.svc:8428/api/v1/query?query=redis_up"
curl -s "http://vmsingle-monitoring.monitoring.svc:8428/api/v1/query?query=mysql_up"
```
