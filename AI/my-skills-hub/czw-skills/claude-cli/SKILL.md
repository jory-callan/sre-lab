---
name: claude-cli
description: "Claude Code CLI 完整参考 - 包含所有常用命令、标志和使用方法"
category: autonomous-ai-agents
tags: [claude, cli, code, tools]
---

# Claude Code CLI 参考

## 安装

从 https://claude.ai/code 下载最新版本，或使用 npm：

```bash
npm install -g claude-code
```

## 基本命令

### 1. 启动交互模式

```bash
claude
```

直接进入交互聊天会话，可处理文件和执行任务。

### 2. 执行任务

```bash
claude task "描述你的任务"
claude task --file requirements.txt
claude task --interactive
```

### 3. 使用 Fork Session（并行开发）

```bash
claude --fork-session
```

这会创建独立的会话，适合前后端并行开发（参见 claude-fork-dev 技能）。

### 4. 配置

```bash
claude config list
claude config set key value
claude config get key
claude config reset
```

### 5. 帮助

```bash
claude --help
claude -h
claude help [command]
```

## 常用标志

- `-v, --verbose`: 详细输出
- `-q, --quiet`: 安静模式
- `-c, --config`: 指定配置文件
- `-w, --workspace`: 指定工作区目录
- `--no-colors`: 禁用彩色输出
- `--model`: 指定使用的模型（如 sonnet-3.5, opus, haiku）
- `--temperature`: 设置温度（0-2）
- `--max-tokens`: 最大 tokens 限制

## 环境变量

- `CLAUDE_API_KEY`: API 密钥
- `CLAUDE_MODEL`: 默认模型
- `CLAUDE_TEMPERATURE`: 默认温度
- `CLAUDE_WORKSPACE`: 默认工作区
- `CLAUDE_CONFIG`: 配置文件路径

## 工作流示例

### 快速编码任务

```bash
cd your-project
claude task "重构 API 端点，添加 TypeScript 类型"
```

### 使用交互式模式进行复杂任务

```bash
claude
> 让我们分析当前项目结构
> 好的，现在创建一个新功能：用户管理模块
> 我们来测试一下，然后提交代码
```

### 并行开发（前后端分离）

```bash
# 终端 1 - 后端开发
cd backend
claude --fork-session task "设计数据库 schema 和 API 端点"

# 终端 2 - 前端开发
cd frontend
claude --fork-session task "开发用户界面组件"
```

## 高级功能

### Checkpointing

```bash
claude checkpoint list
claude checkpoint create
claude checkpoint restore [id]
claude checkpoint delete [id]
```

### Plugins

```bash
claude plugin list
claude plugin install [plugin-name]
claude plugin uninstall [plugin-name]
```

### Hooks

在 `.claude/hooks/` 目录下定义钩子脚本，可在任务执行前后运行：

- `pre-task.sh`: 任务开始前
- `post-task.sh`: 任务完成后

## 技巧

1. 始终在项目根目录运行 `claude`，这样可以访问整个项目上下文
2. 使用 `--fork-session` 时，每个会话都有独立状态，适合并行任务
3. 配合 `claudefile`（类似 Makefile）可以自动化常见工作流
4. 使用 `claude --model opus` 获得最高质量的输出，`claude --model sonnet` 获得最佳性价比

## 相关技能

- claude-code: 委托编码给 Claude Code CLI
- claude-fork-dev: 使用 --fork-session 进行前后端并行开发
- hermes-agent: Hermes 本身的使用和配置
