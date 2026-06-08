# Kubectl + Helm 安装

独立安装 kubectl 和 helm CLI 工具，国内网络适配。

## 安装

```bash
# 默认版本（kubectl 1.31.13, helm 3.17.2）
bash install.sh

# 自定义版本
KUBECTL_VERSION=1.32.0 HELM_VERSION=3.16.0 bash install.sh

# 覆盖已安装版本
FORCE=true KUBECTL_VERSION=1.31.13 HELM_VERSION=3.17.2 bash install.sh
```

## 卸载

```bash
bash uninstall.sh
```

## 验证

```bash
kubectl version --client
helm version
```

## 配置说明

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `KUBECTL_VERSION` | `1.31.13` | kubectl 版本号 |
| `HELM_VERSION` | `3.17.2` | helm 版本号 |
| `ARCH` | `amd64` | CPU 架构 |
| `OS` | `linux` | 操作系统 |
| `FORCE` | `false` | 是否覆盖已安装版本，设为 `true` 时重新下载覆盖 |

## 镜像源

- kubectl: 阿里云镜像 `mirrors.aliyun.com/kubernetes-release/release/`（国内快）
- helm: GitHub releases via `gh-proxy.com`