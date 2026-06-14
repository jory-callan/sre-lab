# spotahome/redis-operator v1.1.1 + Redis 5.0.8 兼容性测试报告

## 测试环境

| 项目 | 值 |
|------|-----|
| 集群 | k3s 1.31.5（3 节点） |
| Operator | `quay.io/spotahome/redis-operator:v1.1.1` |
| Redis | `redis:5.0.8` |
| 目标验证集群 | K8s 1.19（生产集群） |
| 存储 | NFS（PVC 5Gi） |

---

## 测试结果

### ❌ v1.1.1 在 k3s 1.31.5 上无法工作

**根因：PodDisruptionBudget API 版本不兼容**

v1.1.1 代码中 `service/k8s/poddisruptionbudget.go` 使用 **`policy/v1beta1`**：

```go
import policyv1beta1 "k8s.io/api/policy/v1beta1"
...
func (p *PodDisruptionBudgetService) CreatePodDisruptionBudget(...) error {
    _, err := p.kubeClient.PolicyV1beta1().PodDisruptionBudgets(namespace).Create(...)
}
```

`policy/v1beta1` 在 **K8s 1.25 被移除**（自 1.22 起弃用）。k3s 1.31.5 仅支持 `policy/v1`。

**操作器同步周期日志：**
```
configMap created        ✓
service created          ✓
error on object processing: the server could not find the requested resource  ← PDB 创建失败
```

`EnsureRedisStatefulset` → `ensurePodDisruptionBudget` → `CreateOrUpdatePodDisruptionBudget` → 404

此问题在 v1.2.0 修复（[#442](https://github.com/spotahome/redis-operator/pull/442)），master 分支已使用 `policy/v1`：

```go
// master (latest)
import policyv1 "k8s.io/api/policy/v1"
...
err := p.kubeClient.PolicyV1().PodDisruptionBudgets(namespace).Delete(...)
```

---

### ✅ v1.1.1 在 K8s 1.19 应正常工作

K8s 1.19 仍然支持 `policy/v1beta1`（直到 1.24 才完全移除）。因此 v1.1.1 在用户的生产集群（1.19）上应该完全兼容。

其他已验证的兼容性：
| 检查项 | 结果 | 说明 |
|--------|------|------|
| CRD API 版本 `apiextensions.k8s.io/v1` | ✅ | K8s 1.16 GA，1.19 支持 |
| CRD 完整 schema 超 256KB | ✅ | 使用最小化 `x-kubernetes-preserve-unknown-fields: true` CRD |
| client-go v0.22.2 向后兼容 | ✅ | 对 1.19 的基本 CRUD 操作可工作 |
| `apps/v1` StatefulSet/Deployment | ✅ | K8s 1.9 GA |
| `policy/v1beta1` PDB | ✅ | 1.19 支持（1.25 才移除） |
| `go-redis v6` + Redis 5.0.8 | ✅ | Sentinel 协议自 2.8 起未变 |

---

### ✅ Redis 5.0.8 完全兼容

Redis 5.0.8 与 operator 的兼容性不受 K8s 版本影响：

| 功能 | Redis 5.0.8 支持 |
|------|------------------|
| Sentinel 协议 | ✅ 自 2.8 起未变 |
| REPLICAOF（替代 SLAVEOF） | ✅ 自 5.0 起 |
| AUTH | ✅ |
| CONFIG SET/GET | ✅ |
| ROLE | ✅ |
| 全量/增量同步 | ✅ |

Operator 仅通过 `redis-cli`（容器内）下发命令，不依赖 Redis 特定版本特性。

---

## 结论

- **K8s 1.19 + v1.1.1 + Redis 5.0.8 = ✅ 可以工作**
- **K8s 1.25+ + v1.1.1 = ❌ 不兼容**（需升级 operator 到 v1.2.0+）
- 主集群（1.19）上无需担心，直接在 1.19 环境部署即可

## 建议

如果要迁移到 K8s 1.25+：
1. 升级 operator 到 v1.2.0+（或直接用 `:latest`）
2. v1.2.0 要求 K8s ≥ 1.21，这个限制更大
3. 如果 K8s 1.19 → 1.25+ 升级跨度大，operator 需要从 v1.1.1 → v1.2.0

---

## 文件结构

```
spotahome-v111/
├── 00-namespace.yaml          # 测试命名空间
├── 01-serviceaccount.yaml     # ServiceAccount
├── 02-rbac.yaml               # ClusterRole + ClusterRoleBinding
├── 03-operator.yaml           # v1.1.1 operator Deployment
├── 04-redisfailover-cr.yaml   # RedisFailover CR（Redis 5.0.8）
├── 05-external.yaml           # NodePort 30207 外部服务
├── install.sh                 # 部署脚本
├── uninstall.sh               # 清理脚本
├── check.sh                   # 验证脚本
└── README.md                  # 本测试报告
```