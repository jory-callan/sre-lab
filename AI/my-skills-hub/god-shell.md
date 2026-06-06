---
name: god-shell
description: 落地部署文档风格 — 简洁上下文 + 可复制执行的 shell 命令 + 清理步骤。注释在命令上一行，末尾必带清理。
---

# god-shell — 部署文档风格规范

## 核心理念

读者复制粘贴每条命令到终端就能执行。文档结构：**简洁上下文 → 可复制命令 → 末尾清理**。

## 结构模板

```markdown
# {标题}

{1-2 句话说明：做什么、为什么、前提条件}

## 安装

# {注释：解释这条命令在做什么}
{command}

# {注释}
{command}

## 验证

{command}

## 清理

# {注释}
{command}
```

## 风格规则

### 1. 注释在命令上一行

```markdown
# 安装 fnm 到系统目录
curl -fsSL https://example.com/install.sh | bash -s -- --install-dir /usr/local/bin

# 写入系统级 npm 镜像配置
cat > /etc/npmrc << 'EOF'
registry=https://registry.npmmirror.com/
EOF
```

### 2. 上下文只写 1-2 句

```markdown
# 192.168.5.104 是 Ubuntu 26.04 桌面版，已配好 root 免密 SSH。
# 安装 fnm + Node.js LTS，配置 npmmirror 国内镜像源。
```

### 3. 命令可复制执行

- 优先 `cat > file << 'EOF'`、`sed -i`、`tee` 写文件
- 不用变量，直接硬编码路径和版本
- 每步独立可执行，不依赖上一步的变量或状态

### 4. 末尾必带清理步骤

```markdown
## 清理

# 删除安装文件
rm -rf /tmp/fnm-install

# 恢复备份
mv /etc/npmrc.bak /etc/npmrc
```

### 5. 验证章节放清理之前

```markdown
## 验证

node --version
npm --version
npm config get registry
```

## 示例（完整文档骨架）

```markdown
# Node.js 环境安装

# 192.168.5.104 Ubuntu 26.04，root 免密 SSH。
# 安装 fnm + Node.js LTS，配置 npmmirror 国内镜像。

## 安装

# 下载安装 fnm
curl -fsSL https://gh-proxy.com/https://github.com/Schniz/fnm/raw/master/.ci/install.sh | bash -s -- --install-dir /usr/local/bin

# 写入系统级 npm 镜像配置
cat > /etc/npmrc << 'EOF'
registry=https://registry.npmmirror.com/
EOF

## 验证

node --version
npm --version
npm config get registry

## 清理

# 删除安装缓存
rm -rf /tmp/.npm/_cacache
```
