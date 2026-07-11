# Ansible

infra-base 的配置管理核心，用于从裸机到 Kubernetes 集群就绪的自动化部署。

# 批量免密
bash sshcopy.sh

## 支持系统

| 发行版 | 系列 | 状态 |
|--------|------|------|
| Rocky Linux 8/9 | RedHat | ✅ 已测试 |
| Ubuntu 22.04/24.04 | Debian | ✅ 已适配 |
| CentOS 7/8 | RedHat | ⚠️ 兼容但建议迁移 |

## 目录

```
ansible/
├── run.sh                               # 一键运行入口
├── ansible.cfg                          # 全局配置 (pipelining, json cache)
├── inventories/
│   └── production/
│       └── hosts.ini                    # 主机清单 + 所有变量
├── playbooks/
│   ├── linux-init.yml                   # OS 初始化
│   ├── docker.yml                       # Docker CE 安装
│   └── k3s.yml                          # (待实现)
└── roles/
    ├── linux-init/                      # 时区 / sysctl / swap / ulimit / 日志
    └── docker/                          # CE 安装 / daemon 配置 / 启动
```

## 用法

```bash
# 进入 ansible 目录运行
cd ansible

# Linux 初始化
bash run.sh linux-init

# Docker 安装
bash run.sh docker

# 查看所有主机
ansible-inventory -i inventories/production/hosts.ini --list
```

## 变量

所有变量集中在 `inventories/production/hosts.ini` 的 `[all:vars]` 段：

```ini
[all:vars]
timezone=Asia/Shanghai
log_retention_days=7
journald_max_size=500M
docker_registry_mirror=http://192.168.5.103:5002
docker_data_root=/var/lib/docker
```

## 添加新角色

```bash
mkdir -p roles/<name>/tasks
echo "---" > roles/<name>/tasks/main.yml
```

在剧本中引用即可。

## 注意事项

- 控制节点须安装 Ansible 8+ (ansible-core 2.15+)
- 需 root 权限 SSH 免密登录所有目标节点
- 每个 task 文件按步骤拆分，通过 `main.yml` 的 `import_tasks` 串联