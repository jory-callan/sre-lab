# KubeBlocks Operator

KubeBlocks 是一个 Kubernetes 原生的数据库 operator 平台，支持多种数据库引擎的统一管理。

## 版本

| 组件 | 版本 |
|------|------|
| KubeBlocks Operator | 1.0.0 |
| apecloud-mysql addon | 8.0.30 |
| redis addon | 7.2.7 |

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
- 若 addon 自动安装失败，安装脚本会手动安装 addon chart
- 需要从 GitHub 下载 CRD 定义，已配置 gh-proxy.com 加速
- 安装前需确保 `operators` 命名空间 ResourceQuota 足够（requests.cpu ≥ 4）
