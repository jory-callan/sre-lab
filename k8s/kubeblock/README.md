# KubeBlocks 家族

KubeBlocks 是一个 Kubernetes 原生的数据库 Operator 平台，支持多种数据库引擎的统一管理。
官方 addon 仓库：https://github.com/apecloud/kubeblocks-addons
示例参考：https://github.com/apecloud/kubeblocks-addons/blob/main/examples/

## 版本

| 组件 | 版本 |
|------|------|
| KubeBlocks Operator | 1.0.0 |
| ApeCloud MySQL | 8.0.30 |
| Redis | 7.2.4 |
| Valkey | 8.1.8 |

## 目录结构

```
kubeblock/
├── operator/               KubeBlocks operator 安装（ns: operators）
├── redis/                  KubeBlocks Redis 实例
│   └── test-default/       Redis 测试实例（replication, 7.2.4）
├── valkey/                 KubeBlocks Valkey 实例
│   └── test-default/       Valkey 测试实例（replication-8, 8.1.8）
└── apecloud-mysql/         KubeBlocks ApeCloud MySQL 实例
    └── test-default/         ApeCloud MySQL 默认实例（8.0.30）
```

## 部署顺序

1. 先安装 operator
2. 再部署各实例（redis / valkey / apecloud-mysql）

## 注意事项

- 镜像源为阿里云国内镜像站（apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com）
- 所有 operator 统一部署到 `operators` namespace
- 实例 namespace 遵循各中间件约定（mysql / redis / valkey）
- 所有实例统一使用 `install.sh` 管理（install / uninstall / purge）
- StorageClass 显式指定为 `nfs-client`
- 资源限制仅配 memory limits，不做 CPU 限制
