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

## 约定规范

### 变量设计

- 所有动态值必须走变量，不在配置文件中硬编码
- 变量定义在 `hosts.ini` 的 `[all:vars]`，能数组就数组（JSON 格式），不写单值字符串
- `hosts.ini` 中每个变量写注释说明用途和示例值

### 配置文件与变量分离

- k3s 的 `config.yaml` / `config-agent.yaml` 是静态文件，用 `copy` 部署，不写 Jinja2 模板
- 所有动态注入用 `replace` / `lineinfile` / `blockinfile` 模块替换占位符
- 占位符统一用 `__CHANGEME_*__` 格式，一眼可识别

### 模板管理

- 需要模板引擎的文件才用 `template` 模块，变量用 `| default()` 给兜底值
- 数组类型用 `| tojson` 直接渲染 JSON 数组，不手写遍历

### /etc/hosts 管理

- 只用 `blockinfile`，划标记块隔离托管区域，不动用户自定义条目
- 标记用 `# === <SCOPE> MANAGED BLOCK {mark} ===`，清晰可辨

### Playbook 编排

- 一个 playbook 可以包含多个 play，按依赖顺序排列
- 串行操作用 `serial: 1` 控制，如 server 节点逐个加入集群
- 卸载等危险操作用 `tags: [never]` 隔离，不自动执行

### Role 组织

- 按功能拆分：`linux-init` / `docker` / `k3s` / `keepalived-haproxy`
- `tasks/main.yml` 只做入口编排，实际逻辑拆分到 `prereq.yml` / `config.yml` / `install.yml`
- 变量收集（`set_fact`）放在 `main.yml`，`config.yml` 只管注入

### 幂等安全

- 安装任务用 `creates` 或 `when: check.rc != 0` 控制只执行一次
- 配置变更通过 `notify` 触发 handler 重启服务，不在 task 里直接重启
- `blockinfile` / `replace` 天然幂等，多次运行不会重复注入
