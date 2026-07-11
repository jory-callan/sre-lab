# Kite — K8s Web UI

## 安装

```bash
bash install.sh
```

## 访问

https://kite.czw-sre.internal

## 配置

自定义配置在 `values.yaml` 的 `config:` 段，通过 Secret 注入到 Pod 的 `/etc/kite/config.yaml`。
