#!/bin/bash
set -e

# Hermes Agent 安装脚本
# 192.168.5.104 Ubuntu 26.04，root 免密 SSH。
# 安装 uv（清华源）+ Hermes Agent v0.16.0（官方脚本，FHS 布局）。

echo "==> 安装 uv"
curl -fsSL https://astral.sh/uv/install.sh | bash
source "$HOME/.local/bin/env"

echo "==> 配置 uv 清华源"
mkdir -p /root/.config/uv
cat > /root/.config/uv/uv.toml << 'EOF'
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
EOF

echo "==> 执行官方安装脚本"
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup

# 如果 clone 超时，手动补全
if [ ! -f /usr/local/lib/hermes-agent/venv/bin/hermes ]; then
  echo "==> clone 超时，手动补全"
  rm -rf /usr/local/lib/hermes-agent
  git clone --depth 1 https://gh-proxy.com/https://github.com/NousResearch/hermes-agent.git /usr/local/lib/hermes-agent
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup
fi

# 补充软链
echo "==> 补充软链"
ln -sf /usr/local/lib/hermes-agent/venv/bin/hermes /usr/local/bin/hermes
ln -sf /usr/local/lib/hermes-agent/venv/bin/hermes-acp /usr/local/bin/hermes-acp
ln -sf /usr/local/lib/hermes-agent/venv/bin/hermes-agent /usr/local/bin/hermes-agent

echo "==> 验证"
hermes --version
hermes doctor

echo ""
echo "安装完成。首次运行 hermes 会自动进入配置向导。"
