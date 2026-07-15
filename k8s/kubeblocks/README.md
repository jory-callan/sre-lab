# KubeBlocks 家族

KubeBlocks 是一个 Kubernetes 原生的数据库 Operator 平台，支持多种数据库引擎的统一管理。

## 版本

| 组件 | 版本 |
|------|------|
| KubeBlocks Operator | 1.0.0 |
| apecloud-mysql | 8.0.30 |
| redis | 7.2.7 |

## 目录结构

```
kubeblocks/
├── operator/               KubeBlocks operator 安装（ns: operators）
├── chart/                  Helm chart 源码
├── common/                 共享资源
├── cr-redis-auth/          Redis 认证实例（KubeBlocks 管理）
└── cr-apecloud-mysql/      ApeCloud MySQL 实例（KubeBlocks 管理）
```

## 部署顺序

1. 先安装 operator
2. 再部署实例

## 注意事项

- 镜像源为阿里云国内镜像站（apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com）
- 所有 operator 统一部署到 `operators` namespace
- 实例 namespace 遵循各中间件约定（mysql / redis 等）
