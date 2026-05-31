# 应用标准模板（Docker Compose）

这是一个标准的应用目录模板，用于 `infra-docker/` 和 `apps-docker/`。

## 📂 目录结构

```
{app-name}/
├── dev/
│   ├── docker-compose.yml
│   ├── .env
│   ├── install.sh
│   └── README.md
└── prod/
    ├── docker-compose.yml
    ├── .env
    ├── install.sh
    └── README.md
```

---

## 📄 文件说明

| 文件 | 说明 |
|------|------|
| `docker-compose.yml` | Docker Compose 配置文件 |
| `.env` | 环境变量文件 |
| `install.sh` | 一键安装脚本 |
| `README.md` | 说明文档 |
