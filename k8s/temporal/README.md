# Temporal 部署项目文档

---

## 📚 文档目录

| 文档 | 说明 |
|------|------|
| [01-部署与架构.md](docs/01-部署与架构.md) | 架构介绍，环境信息，文件清单 |
| [02-快速开始.md](docs/02-快速开始.md) | 快速上手教程，验证部署 |
| [03-配置与优化.md](docs/03-配置与优化.md) | 生产优化配置，Namespace Retention 设置 |
| [04-故障排查.md](docs/04-故障排查.md) | 问题排查指南，常见问题 |
| [05-常用命令.md](docs/05-常用命令.md) | Cheatsheet，常用命令速查 |

---

## 🚀 快速开始

### 1. 部署单体版（推荐开发用）

```bash
kubectl create namespace temporal-simple
kubectl apply -f temporal-simple-mysql.yaml
kubectl apply -f temporal-simple.yaml
```

### 2. 访问 Web UI

```bash
# 终端 1
kubectl port-forward -n temporal-simple svc/temporal-simple-web 8080:8080

# 终端 2
kubectl port-forward -n temporal-simple svc/temporal-simple-frontend 7233:7233
```
打开浏览器访问：`http://localhost:8080`

### 3. 验证部署

```bash
# 查看 Pod
kubectl get pods -n temporal-simple

# 验证 default Namespace Retention（是 8760h）
kubectl exec -n temporal-simple deploy/temporal-simple-admintools -- \
  temporal operator namespace describe default --address temporal-simple-frontend:7233
```

---

## 📁 文件清单

### 部署文件

| 文件 | 说明 |
|------|------|
| `temporal-simple.yaml` | 单体版完整部署文件 |
| `temporal-simple-mysql.yaml` | MySQL 部署文件 |
| `values.yaml` | 分布式版 Helm values 配置 |

### 工具与脚本

| 文件 | 说明 |
|------|------|
| `temporal-wrapper.sh` | Temporal CLI wrapper，强制 Retention 1年 |
| `temporal-tool.sh` | 常用操作工具脚本 |

---

## 🎯 重要提示

### Namespace Retention 必看！

**Temporal Server 没有全局默认 Retention 的配置项！**

所以你需要：
1. **部署时自动创建 default Namespace（已配置！Retention 1年！）
2. **在本地用 wrapper 脚本（推荐！自动加 `--retention 8760h`！）

**Wrapper 脚本使用：**
```bash
# 下载脚本到本地 Mac
scp root@你的服务器:/root/temporal-deploy/temporal-wrapper.sh ~/bin/temporal
chmod +x ~/bin/temporal
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

---

## 📊 架构对比

| 特性 | 单体版 (temporal-simple) | 分布式版 (temporal-test) |
|------|---------------------|---------------------|
| Server Pod | 1 (all-in-one) | 4 (frontend/history/matching/worker) |
| 总 Pod 数 | 4 | 7 |
| 适用环境 | 开发/测试 | 生产 |
| 资源占用 | 低 | 高 |

---

## 🎉 验证成功的标准

部署后，你应该看到：

- [ ] 所有 Pod 状态为 `Running` 或 `Completed`
- [ ] default Namespace 的 Retention 为 `8760h0m0s`
- [ ] 能访问 Web UI：`http://localhost:8080`
- [ ] Server 日志中没有 `ERROR`
- [ ] `temporal-simple-namespaces` 和 `temporal-simple-schema` 两个 Job 都是 `Complete`

---

## 📖 下一步

- 查看 [快速开始文档](docs/02-快速开始.md)
- 查看 [配置与优化文档](docs/03-配置与优化.md)
- 查看 [常用命令 Cheatsheet](docs/05-常用命令.md)
