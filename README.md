# CZW SRE

SRE 基础设施即代码项目。

> 完整规范文档：[**项目架构与目录规范.md**](./项目架构与目录规范.md)

## 快速导航

| 层 | 目录 | 内容 |
|----|------|------|
| 物理层 | [`01-physical/`](./01-physical/) | 操作系统初始化、网络配置 |
| 平台层 | [`02-platforms/`](./02-platforms/) | Docker、k3s 安装部署 |
| 基础设施 Docker | [`03-infra-docker/`](./03-infra-docker/) | Docker Compose 中间件 |
| 基础设施 K8s | [`03-infra-k8s/`](./03-infra-k8s/) | K8s 中间件（监控/数据库/中间件） |
| 业务 Docker | [`04-apps-docker/`](./04-apps-docker/) | Docker 业务应用 |
| 业务 K8s | [`04-apps-k8s/`](./04-apps-k8s/) | K8s 业务应用 |
| 文档 | [`docs/`](./docs/) | 端口分配、模板等 |
| AI 规则 | [`AGENT.md`](./AGENT.md) | AI 助手行为指令 |
| Git 规范 | [`git-commit-reference-doc.md`](./git-commit-reference-doc.md) | 提交格式参考 |