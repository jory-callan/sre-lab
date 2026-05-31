# 迁移指南

## 📦 现有资源迁移

### 1. 物理机脚本

把你现有的 `script/` 目录内容迁移到：
- Linux 脚本 → `01-physical/linux/scripts/`
- Windows 脚本 → `01-physical/windows/`
- macOS 脚本 → `01-physical/macos/`

### 2. docker-compose 项目

把你现有的 `docker-compose/` 目录内容迁移到：
- 开发环境 → `infra-docker/{app}/dev/`
- 生产环境 → `infra-docker/{app}/prod/`

### 3. k3s 部署

已迁移到 `02-platforms/k3s/`。

### 4. kite 应用

把 kite 应用迁移到：
- Docker 版本 → `apps-docker/kite/`
- k8s 版本 → `apps-k8s/kite/`

---

## 🚀 迁移步骤

### 第一步：先迁移你最常用的
1. 把 `docker-compose/nginx/` 迁移到 `infra-docker/nginx/dev/`
2. 把 `docker-compose/php/` 迁移到 `infra-docker/php/dev/`
3. 把 `docker-compose/postgresql/` 迁移到 `infra-docker/postgresql/dev/`

### 第二步：逐步完善
- 为每个应用添加 `install.sh`
- 为每个应用写好 `README.md`

### 第三步：k8s 部分（未来）
- 等需要时再填充 `infra-k8s/` 和 `apps-k8s/`
- 先只做 manifests 方式
