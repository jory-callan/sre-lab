# Kite — K8s Web UI

Kite 是一个开源的 Kubernetes 多集群管理面板，提供资源查看、日志/终端、YAML 编辑等能力。

- **开源地址**: https://github.com/kite-org/kite
- **Helm Chart**: https://github.com/kite-org/charts

## 安装

```bash
bash install.sh
```

## 访问

https://kite.czw-sre.internal

## 初始账号

**无默认账号。** 首次访问会进入设置页面，自行创建管理员账号即可使用。

## 配置

自定义配置在 `values.yaml` 的 `config:` 段，通过 Secret 注入到 Pod 的 `/etc/kite/config.yaml`。
