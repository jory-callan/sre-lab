# Redis Cluster — KubeBlocks 管理

基于 KubeBlocks 的 Redis 复制集群，1 主节点 + 2 从节点 + 3 哨兵。

## 版本

| 组件 | 版本 |
|------|------|
| Redis | 7.2.11 |
| KubeBlocks | 1.0.0 |

## 前置条件

需要先安装 KubeBlocks operator：

```bash
cd ../../operators/kubeblocks && bash install.sh
```

## 部署

```bash
bash install.sh
```

## 卸载

```bash
bash uninstall.sh
```

## 连接

```bash
# 通过 Sentinel 获取主节点信息
redis-cli -h redis-kb-redis-sentinel.redis.svc.cluster.local -p 26379 SENTINEL get-master-addr-by-name mymaster

# 直接连接 Redis 主节点
redis-cli -h redis-kb-redis.redis.svc.cluster.local -p 6379 -a 'redis@czw'

# 通过 Sentinel 连接（自动发现主节点）
redis-cli -h redis-kb-redis-sentinel.redis.svc.cluster.local -p 26379
```

## 架构说明

使用 KubeBlocks Redis 的 `replication` 拓扑，包含：
- **redis** 组件：1 主 + 2 从，共 3 个 Redis 实例
- **redis-sentinel** 组件：3 个 Sentinel 实例，实现自动故障转移

默认密码：`redis@czw`，与现有 Spotahome 方案保持一致。

## 参考

- [KubeBlocks Addons - redis](https://github.com/apecloud/kubeblocks-addons/tree/main/addons/redis)
- [KubeBlocks 官方文档](https://kubeblocks.io/docs/)
