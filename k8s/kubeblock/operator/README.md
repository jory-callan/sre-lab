# KubeBlocks Operator

KubeBlocks 是一个 Kubernetes 原生的数据库 operator 平台，支持多种数据库引擎的统一管理。

## 版本

| 组件 | 版本 |
|------|------|
| KubeBlocks Operator | 1.0.2 |
| apecloud-mysql addon | 1.0.1 |
| redis addon | 1.0.2 |

## 部署

```bash
bash install.sh
```

## 卸载

```bash
bash uninstall.sh
```

## 管理

```bash
# 查看 KubeBlocks 状态
kubectl get pods -n operators -l app.kubernetes.io/name=kubeblocks

# 查看已安装的 addon
kubectl get addon -n operators

# 查看所有集群
kubectl get clusters.apps.kubeblocks.io -A
```

## 架构

KubeBlocks 通过 addon 机制管理各类数据库引擎的 ComponentDefinition 和 ClusterDefinition。
安装 KubeBlocks 后，apecloud-mysql 和 redis addon 会自动安装，随后即可创建对应的 Cluster CR。

## 注意事项

- 镜像源为 `apecloud-registry.cn-zhangjiakou.cr.aliyuncs.com`（阿里云国内镜像站）
- CRD 和 Chart 已本地化，无需外网访问
- addon 通过 KubeBlocks addon 控制器自动安装，无需手动干预
