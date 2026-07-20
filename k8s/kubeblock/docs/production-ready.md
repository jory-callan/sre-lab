# 运维手册（Operations Runbook）

> 日常运维操作参考手册。
> 架构说明见 [architecture.md](architecture.md)，
> 备份存储切换见 [backup-storage.md](backup-storage.md)，
> 故障恢复见 [disaster-recovery.md](disaster-recovery.md)。

---

## 1. 部署顺序

```bash
# ─── 基础环境（一次性）─────────────────────────────────────────────
# 1. 安装 KubeBlocks Operator + CRD
cd operator && bash install.sh && cd -

# 2. 创建备份存储仓库
kubectl apply -f common/backuprepo/credential-secret.yaml
kubectl apply -f common/backuprepo/backuprepo.yaml

# 3. 确认 Operator 就绪
kubectl get pods -n operators -w

# ─── 数据库实例（可并行）───────────────────────────────────────────
kubectl apply -f redis/test-default/cluster.yaml
kubectl apply -f valkey/test-default/cluster.yaml
kubectl apply -f apecloud-mysql/test-default/cluster.yaml

# 等待就绪
kubectl get cluster -A -w

# ─── 高可用 & 安全 ─────────────────────────────────────────────────
kubectl apply -f common/pdb/
kubectl apply -f common/network-policy/

# ─── 监控体系 ──────────────────────────────────────────────────────
kubectl apply -f common/grafana/

# 每个实例的 Pod 级抓取
kubectl apply -f redis/test-default/vmpodscrape.yaml
kubectl apply -f valkey/test-default/vmpodscrape.yaml
kubectl apply -f apecloud-mysql/test-default/vmpodscrape.yaml

# 每个实例的 Service 级抓取（Prometheus 兼容模式）
kubectl apply -f redis/test-default/vmservicescrape.yaml
kubectl apply -f valkey/test-default/vmservicescrape.yaml
kubectl apply -f apecloud-mysql/test-default/vmservicescrape.yaml

# 告警规则
kubectl apply -f redis/test-default/vmrule-alerts.yaml
kubectl apply -f valkey/test-default/vmrule-alerts.yaml
kubectl apply -f apecloud-mysql/test-default/vmrule-alerts.yaml

# ─── 备份调度 ──────────────────────────────────────────────────────
kubectl apply -f redis/test-default/backup-enable.yaml
kubectl apply -f valkey/test-default/backup-enable.yaml
kubectl apply -f apecloud-mysql/test-default/backup-enable.yaml

# ─── 验证全部就绪 ──────────────────────────────────────────────────
kubectl get backuprepo,cluster,pdb,cnp,vmpodscrape,vmservicescrape,vmrule -A
```

---

## 2. 日常巡检

```bash
# 每日常规检查
alias dr="kubectl get cluster,backup,pdb -A"
dr

# 查看 Pod 分布
kubectl get pods -A -o wide | grep -E 'redis|valkey|mysql|NAMESPACE'

# 节点资源
kubectl top node
kubectl top pod -n redis

# 备份状态检查
kubectl get backup -A
kubectl get backupschedule -A

# 监控目标
kubectl get vmpodscrape -A
kubectl get vmservicescrape -A

# 查看最近 5 次备份记录
kubectl get backup -A --sort-by=.metadata.creationTimestamp | tail -5
```

---

## 3. 备份操作

### 查看备份

```bash
kubectl get backup -n redis
# NAME                                       METHOD     STATUS      SIZE    AGE
# redis-redis-backup-datafile-202607200300   datafile   Completed   12Mi    12h

# 查看备份详情
kubectl describe backup -n redis redis-redis-backup-datafile-202607200300

# 查看备份在 MinIO 中的实际文件
POD=$(kubectl get pod -n minio -l app=minio -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n minio "$POD" -c minio -- sh -c " \
  mc alias set myminio http://localhost:9000 svc-poweruser ZYz04aZn0xQpzn8l 2>/dev/null && \
  mc du myminio/kubeblocks-backup --recursive \
"
```

### 手动触发备份

```bash
# Redis 全量
kubectl create -n redis -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: redis-manual-$(date +%Y%m%d-%H%M%S)
spec:
  backupMethod: datafile
  backupPolicyName: redis-redis-backup-policy
  deletionPolicy: Delete
EOF

# MySQL 全量
kubectl create -n mysql -f - <<EOF
apiVersion: dataprotection.kubeblocks.io/v1alpha1
kind: Backup
metadata:
  name: mysql-manual-$(date +%Y%m%d-%H%M%S)
spec:
  backupMethod: xtrabackup
  backupPolicyName: apecloud-mysql-mysql-backup-policy
  deletionPolicy: Delete
EOF
```

### 恢复数据

参考各实例目录下的 `restore.yaml` 或 [disaster-recovery.md](disaster-recovery.md) 场景四。

---

## 4. 扩缩容操作

### 水平扩缩（副本数）

```bash
# Redis 从 2 副本扩到 3 副本
kubectl patch cluster redis -n redis --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "redis",
        "replicas": 3
      }
    ]
  }
}'

# 查看滚动过程
kubectl get pods -n redis -w

# 缩容回 2
kubectl patch cluster redis -n redis --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "redis",
        "replicas": 2
      }
    ]
  }
}'

# MySQL 缩容
# 注意：Raft 集群缩容只能偶数变奇数（3→1），不能 3→2
kubectl patch cluster apecloud-mysql -n mysql --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "mysql",
        "replicas": 1
      }
    ]
  }
}'
```

### 垂直扩缩（资源）

```bash
# Redis 内存从 512Mi 升到 1Gi
kubectl patch cluster redis -n redis --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "redis",
        "resources": {
          "limits": {
            "memory": "1Gi"
          }
        }
      }
    ]
  }
}'
```

### 存储扩容

```bash
# Redis data 从 5Gi 升到 10Gi
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
                  "storage": "10Gi"
                }
              }
            }
          }
        ]
      }
    ]
  }
}'

# 验证 PVC 自动扩容
kubectl get pvc -n redis -w
```

---

## 5. 版本升级

```bash
# 1. 查看当前版本
kubectl get cluster -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.componentSpecs[0].serviceVersion}{"\n"}{end}'

# 2. 升级（以 Valkey 8.1.8→9.0.0 为例）
kubectl patch cluster valkey -n valkey --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "valkey",
        "serviceVersion": "9.0.0"
      }
    ]
  }
}'

# 3. 监控滚动升级
kubectl get pods -n valkey -w

# 4. 确认升级完成
kubectl get cluster valkey -n valkey -o jsonpath='{.status.phase}'

# 5. 如果升级失败回滚
kubectl patch cluster valkey -n valkey --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "valkey",
        "serviceVersion": "8.1.8"
      }
    ]
  }
}'
```

---

## 6. 节点维护

```bash
# 1. 维护前检查 PDB
kubectl get pdb -A
# 确认每行 ALLOWED DISRUPTIONS >= 1

# 2. 封节点 + 排空
kubectl cordon agent-1
kubectl drain agent-1 --ignore-daemonsets --delete-emptydir-data

# 3. 执行维护操作
# 硬件更换 / 内核升级 / kubelet 升级...

# 4. 恢复节点
kubectl uncordon agent-1

# 5. 确认 Pod 重新调度
kubectl get pods -A -o wide | grep agent-1
# 新 Pod 可能不会自动漂回被 drain 的节点
# 如果需要重新分布，手动删除特定 Pod 触发重建
```

---

## 7. 配置变更

通过 `config-instance.yaml` 修改数据库配置：

```bash
# 1. 编辑 ConfigMap
kubectl edit configmap redis7-config-template -n operators

# 2. 触发配置热加载
kubectl patch cluster redis -n redis --type='merge' -p='{
  "spec": {
    "componentSpecs": [
      {
        "name": "redis"
      }
    ]
  }
}'
# 或者直接重启 Pod（部分配置需要重启生效）
kubectl delete pod -n redis redis-redis-0

# 3. 验证配置生效
kubectl exec -n redis redis-redis-0 -- redis-cli -a "$(kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d)" CONFIG GET maxmemory
```

> 详细说明见各实例的 `config.md`。

---

## 8. 网络策略管理

```bash
# 查看当前策略
kubectl get cnp -A

# 临时放通特定来源（以 redis 为例）
kubectl patch cnp redis-network-isolation -n redis --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/ingress/-",
    "value": {
      "fromEndpoints": [{"matchLabels": {"io.kubernetes.pod.namespace": "your-ns"}}],
      "toPorts": [{"ports": [{"port": "6379", "protocol": "TCP"}]}]
    }
  }
]'

# 临时全部放通（排障）
kubectl delete cnp redis-network-isolation redis-egress -n redis
# 排障完成后重新 apply
kubectl apply -f common/network-policy/redis-network-policy.yaml
```

---

## 9. 日志与监控

```bash
# 查看数据库日志
kubectl logs -n redis redis-redis-0 -c redis           # Redis 日志
kubectl logs -n mysql apecloud-mysql-mysql-0 -c mysql   # MySQL 日志

# 查看 metrics 是否被采集
kubectl port-forward -n monitoring svc/vmagent-monitoring 8429:8429
# 浏览器访问 http://localhost:8429/targets

# 查看告警规则
kubectl get vmrule -A

# 查看告警历史
kubectl port-forward -n monitoring svc/vmalertmanager-monitoring 9093:9093
# 浏览器访问 http://localhost:9093

# 访问 Grafana
kubectl port-forward -n monitoring svc/vm-grafana 8080:80
# 浏览器访问 http://localhost:8080
```

---

## 10. 生产就绪清单

### 初始部署后验证

```markdown
- [ ] Operator 安装完成且 Running
- [ ] BackupRepo Ready
- [ ] 三个 Cluster 均 Running
- [ ] PDB 已创建，ALLOWED DISRUPTIONS >= 1
- [ ] VMPodScrape + VMServiceScrape 已创建且 operational
- [ ] VMRule 已创建
- [ ] CiliumNetworkPolicy 已创建
- [ ] Grafana Dashboard 已加载
- [ ] BackupSchedule 已启用
- [ ] 数据访问通过 kdebug 或其他 namespace 验证
```

### 每季度检查

```markdown
- [ ] 恢复演练执行
- [ ] 备份文件完整性检查（随机恢复验证）
- [ ] 安全补丁 / 版本升级评估
- [ ] 磁盘空间趋势评估
- [ ] 监控告警覆盖度评审
```

---

## 11. 常见运维问答

### Q: 如何查看数据库密码？
```bash
# Redis
kubectl get secret -n redis redis-redis-account-default -o jsonpath='{.data.password}' | base64 -d
# 默认用户名: default, 密码: 如上

# MySQL
kubectl get secret -n mysql mysql-account-root -o jsonpath='{.data.password}' | base64 -d
# 默认用户名: root, 密码: 如上
```

### Q: Cluster 状态是 Failed，怎么办？
```bash
kubectl describe cluster <name> -n <ns>
# 查看 Events: 段，找到具体错误原因
# 常见原因：
# - 反亲和导致 Pod 无法调度 → 改为 preferred
# - PVC 空间不足 → 扩容
# - 镜像拉取失败 → 检查镜像地址
```

### Q: 如何连接数据库进行调试？
```bash
# 使用 kdebug namespace 中的调试 Pod
kubectl exec -it -n kdebug deploy/kdebug -- redis-cli -h redis-redis-redis.redis.svc -a <password>

kubectl exec -it -n kdebug deploy/kdebug -- mysql -h apecloud-mysql-mysql.mysql.svc -uroot -p<password>
```

### Q: 如何临时停止一个集群？
```bash
kubectl patch cluster redis -n redis --type='merge' -p='{"spec": {"componentSpecs": [{"name": "redis", "stopped": true}]}}'
# 启动：
kubectl patch cluster redis -n redis --type='merge' -p='{"spec": {"componentSpecs": [{"name": "redis", "stopped": false}]}}'
```
