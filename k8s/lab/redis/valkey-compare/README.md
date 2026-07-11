# Valkey 与 OT-Container-KIT 对比

## 项目定位

| 维度 | OT-Container-KIT (redis-operator) | Valkey Operator (hyperspike) |
|------|-----------------------------------|------------------------------|
| 类型 | Redis Operator | Valkey Operator |
| GitHub Stars | ~1,389 | ~302 |
| 最新版本 | v0.25.0 (稳定) | v0.0.61 (开发中) |
| API 版本 | v1beta2 | v1alpha1 |
| 所属组织 | OT-Container-KIT (社区) | hyperspike (社区) |
| 官方性 | 成熟社区 | 非 valkey-io/Linux Foundation 官方 |
| 支持模式 | Standalone/Replication/Sentinel/Cluster | Cluster (主推) |
| 镜像源 | quay.io ✅ | docker.io ⚠️ |

## 当前结论：Operator 不动，运行引擎可换

**OT-Container-KIT 的 Operator 框架是成熟的**——1.4k stars，CRD 稳定 v1beta2，
经过 chaos-test 验证过的故障切换。**Valkey Operator 还要等**——API v1alpha1，
300 stars，核心功能（零停机升级、数据持久化管理）还在开发中。

但你**不需要等 Valkey Operator**就能用 Valkey。因为 Valkey 7.x/8.x 和 Redis 7.x
是二进制协议兼容的 drop-in replacement：

```
# redis-operator 管理的 RedisReplication CR
spec:
  kubernetesConfig:
    image: quay.io/opstree/redis:v7.0.15
    # 改为 ↓
    image: docker.io/valkey/valkey:8.1    # drop-in 替换
```

Operator 框架不变，运行引擎换成 Valkey。

## 什么时候切？

| 条件 | 现在 (2026-07) | 后续 |
|------|---------------|------|
| OT-Container-KIT | ✅ 稳定使用 | 继续使用 |
| Valkey 镜像替换 | ⚠️ 可做，但需自建 Nexus proxy 代理 docker.io | 尝试 |
| Valkey Operator | ❌ 太早 | 等 v1.0 GA 后再评估 |
| Tanzu for Valkey (商业) | ✅ 已 GA v3.4 | 需要 Broadcom 授权 |

## 迁移风险

- **镜像切换**：低。Valkey 和 Redis 7.x 协议完全兼容
- **Operator 切换**：高。CRD 不兼容，需要完整的数据迁移
- **持久化格式**：Valkey 7.x 直接读取 RDB/AOF（兼容），8.x 需验证

## 参考

- [Valkey 项目](https://valkey.io/)
- [hyperspike/valkey-operator](https://github.com/hyperspike/valkey-operator)
- [Valkey Operator 技术现状分析](https://blog.gitcode.com/3ca3f51319eb72f8bada72d97ff3e91f.html)
