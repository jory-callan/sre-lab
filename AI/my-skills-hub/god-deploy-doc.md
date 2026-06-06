---
name: god-deploy-doc
description: 落地部署文档风格规范 — 顺序执行、无变量、可复现的 shell 命令式文档。关注风格复现而非内容复刻。
---

# god-deploy-doc — 部署文档风格规范

## 核心理念

这是一套**文档风格**，不是某个具体部署步骤的流水线。目标是让读者能**直接复制粘贴命令到终端逐条执行**，无需修改、无需理解上下文、无需额外操作。

## 风格规则

### 1. 顺序执行，编号清晰

每步按执行顺序编号，读者从上到下逐条复制即可：

```markdown
## 安装

```bash
# 1. 第一步
command-1

# 2. 第二步
command-2
```

### 2. 无变量，全部硬编码

**不要**用 `$VERSION`、`$HOME`、`$USER` 等变量。直接用具体值：

```bash
# ❌ 错误：依赖变量
VERSION=24.16.0
ln -sf /root/.local/share/fnm/node-versions/v${VERSION}/installation/bin/node /usr/local/bin/node

# ✅ 正确：直接硬编码
ln -sf /root/.local/share/fnm/node-versions/v24.16.0/installation/bin/node /usr/local/bin/node
```

> 唯一例外：`$HOME` 在 root 场景下可接受，但优先用 `/root` 等绝对路径。

### 3. 用 shell 原生工具写文件

优先用 `cat > file << 'EOF'` 或 `tee`，**不用** `echo >>` 逐行追加：

```bash
# ✅ 正确：cat heredoc
cat > /etc/npmrc << 'EOF'
registry=https://registry.npmmirror.com/
EOF

# ✅ 正确：sed 修改
sed -i '/^# fnm$/,/^fi$/d' /root/.bashrc

# ✅ 正确：tee 写入（需要 sudo 时）
echo 'registry=https://registry.npmmirror.com/' | tee /etc/npmrc

# ❌ 错误：echo 逐行追加
echo "registry=https://registry.npmmirror.com/" >> /etc/npmrc
```

### 4. 每步自包含，不依赖上一步状态

```bash
# ❌ 错误：依赖上一步的变量
export PATH="/usr/local/bin:$PATH"
eval "$(fnm env --shell bash)"
fnm install --lts

# ✅ 正确：每步独立可执行
curl -fsSL https://example.com/install.sh | bash -s -- --install-dir /usr/local/bin
source /etc/profile.d/fnm.sh
fnm install --lts
```

### 5. 说明文字精简，命令是主角

- 每步用 `# 注释` 写在命令上方或行内
- 不需要长篇原理说明
- 关键注意事项用 `> **注意**` 引用块

```markdown
# 5. 软链到 /usr/local/bin（非交互式 SSH 也能用）
ln -sf /path/to/node /usr/local/bin/node
ln -sf /path/to/npm  /usr/local/bin/npm

> **注意**：切换版本后需手动更新软链。
```

### 6. 末尾加验证章节

```markdown
## 验证

```bash
node --version
npm --version
npm config get registry
npm ping
```
```

### 7. 文件操作必须可逆

- 修改前用 `.bak` 备份：`sed -i.bak '/pattern/d' file`
- 创建的文件写明路径，方便删除回滚

## 模板

```markdown
# {标题} — {一句话说明}

## 安装

```bash
# 1. {第一步}
{command}

# 2. {第二步}
{command}
```

## 配置

```bash
# 3. {写配置文件}
cat > {path} << 'EOF'
{content}
EOF

# 4. {修改配置}
sed -i.bak '{pattern}' {file}
```

## 验证

```bash
{verification commands}
```

> **注意**：{关键注意事项}
```

## 使用场景

- 服务器初始化文档
- 软件安装文档
- 环境配置文档
- CI/CD 流水线步骤说明
- 任何需要读者手动执行命令的文档
