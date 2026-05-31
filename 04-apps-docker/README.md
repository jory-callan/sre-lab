# 04-apps-docker - Docker 业务应用

## 📂 目录结构

```
04-apps-docker/
└── kite/
    ├── dev/           # 开发环境
    └── prod/          # 生产环境
```

---

## 🎯 用途

这一层包含用 Docker Compose 部署的你的业务应用。

---

## 📖 使用说明

每个应用都分 `dev/` 和 `prod/` 两个环境：
- **dev/**：开发环境
- **prod/**：生产环境

### 快速开始

```bash
cd 04-apps-docker/kite/dev
./install.sh
```

---

## 📦 应用列表

| 应用 | 说明 |
|------|------|
| [kite/](./kite/) | Kite 应用 |
