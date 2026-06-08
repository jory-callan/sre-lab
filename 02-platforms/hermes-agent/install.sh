#!/bin/bash
set -e

# Hermes Agent 安装脚本
# 192.168.5.104 Ubuntu 26.04，root 免密 SSH。
# 安装 uv（清华源）+ Hermes Agent v0.16.0（官方脚本，FHS 布局）。

proxy_github_urls() {
  local file="$1"

  # 先归一化，避免重复代理成 gh-proxy.com/https://gh-proxy.com/...
  sed -i \
    -e 's#https://gh-proxy.com/https://github.com/#https://github.com/#g' \
    -e 's#https://gh-proxy.com/https://raw.githubusercontent.com/#https://raw.githubusercontent.com/#g' \
    -e 's#https://gh-proxy.com/https://api.github.com/#https://api.github.com/#g' \
    "$file"

  # 官方安装脚本内部可能继续访问 GitHub release / raw / API，需要执行前批量代理
  sed -i \
    -e 's#https://github.com/#https://gh-proxy.com/https://github.com/#g' \
    -e 's#https://raw.githubusercontent.com/#https://gh-proxy.com/https://raw.githubusercontent.com/#g' \
    -e 's#https://api.github.com/#https://gh-proxy.com/https://api.github.com/#g' \
    "$file"
}

download_and_run_script() {
  local url="$1"
  shift

  local script_file
  script_file="$(mktemp /tmp/remote-install.XXXXXX.sh)"
  curl -fsSL "$url" -o "$script_file"
  proxy_github_urls "$script_file"

  if grep -nE 'https://(github.com|raw.githubusercontent.com|api.github.com)/' "$script_file" | grep -v 'https://gh-proxy.com/'; then
    echo "ERROR: 远程安装脚本仍存在未代理的 GitHub URL: $url"
    rm -f "$script_file"
    exit 1
  fi

  bash "$script_file" "$@"
  rm -f "$script_file"
}

apt update
apt install -y python3-venv python3-full

echo "==> 安装 uv"
download_and_run_script https://astral.sh/uv/install.sh
source "$HOME/.local/bin/env"

echo "==> 配置 uv 清华源"
mkdir -p /root/.config/uv
cat > /root/.config/uv/uv.toml << 'EOF'
[[index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
EOF

echo "==> 执行官方安装脚本"
download_and_run_script https://hermes-agent.nousresearch.com/install.sh --skip-setup

# 如果 clone 超时，手动补全
if [ ! -f /usr/local/lib/hermes-agent/venv/bin/hermes ]; then
  echo "==> clone 超时，手动补全"
  rm -rf /usr/local/lib/hermes-agent
  git clone --depth 1 https://gh-proxy.com/https://github.com/NousResearch/hermes-agent.git /usr/local/lib/hermes-agent
  download_and_run_script https://hermes-agent.nousresearch.com/install.sh --skip-setup
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
