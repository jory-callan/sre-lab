#!/bin/bash
set -e

# Node.js 环境安装脚本
# 192.168.5.104 Ubuntu 26.04，root 免密 SSH。
# 安装 fnm + Node.js LTS，配置 npmmirror 国内镜像源。

proxy_github_urls() {
  local file="$1"

  # 先归一化，避免重复代理成 gh-proxy.com/https://gh-proxy.com/...
  sed -i \
    -e 's#https://gh-proxy.com/https://github.com/#https://github.com/#g' \
    -e 's#https://gh-proxy.com/https://raw.githubusercontent.com/#https://raw.githubusercontent.com/#g' \
    -e 's#https://gh-proxy.com/https://api.github.com/#https://api.github.com/#g' \
    "$file"

  # fnm 官方安装脚本内部还会访问 GitHub release / raw / API，需要执行前批量代理
  sed -i \
    -e 's#https://github.com/#https://gh-proxy.com/https://github.com/#g' \
    -e 's#https://raw.githubusercontent.com/#https://gh-proxy.com/https://raw.githubusercontent.com/#g' \
    -e 's#https://api.github.com/#https://gh-proxy.com/https://api.github.com/#g' \
    "$file"
}

echo "==> 下载 fnm 安装脚本"
FNM_INSTALL_SCRIPT="$(mktemp /tmp/fnm-install.XXXXXX.sh)"
trap 'rm -f "$FNM_INSTALL_SCRIPT"' EXIT
curl -fsSL https://gh-proxy.com/https://github.com/Schniz/fnm/raw/master/.ci/install.sh -o "$FNM_INSTALL_SCRIPT"

proxy_github_urls "$FNM_INSTALL_SCRIPT"

if grep -nE 'https://(github.com|raw.githubusercontent.com|api.github.com)/' "$FNM_INSTALL_SCRIPT" | grep -v 'https://gh-proxy.com/'; then
  echo "ERROR: fnm 安装脚本仍存在未代理的 GitHub URL"
  exit 1
fi

echo "==> 执行 fnm 安装脚本"
bash "$FNM_INSTALL_SCRIPT" --install-dir /usr/local/bin

echo "==> 写入系统级 fnm 环境变量"
cat > /etc/profile.d/fnm.sh << 'EOF'
# fnm - Fast Node Manager
if [ -x /usr/local/bin/fnm ]; then
  export PATH="/usr/local/bin:$PATH"
  case "$-" in
    *i*) eval "$(fnm env --shell bash)" ;;
  esac
fi
EOF
chmod +x /etc/profile.d/fnm.sh

echo "==> 安装 Node.js LTS"
source /etc/profile.d/fnm.sh
fnm install --lts
fnm default lts-latest

echo "==> 软链到 /usr/local/bin"
ln -sf /root/.local/share/fnm/node-versions/v24.16.0/installation/bin/node /usr/local/bin/node
ln -sf /root/.local/share/fnm/node-versions/v24.16.0/installation/bin/npm  /usr/local/bin/npm
ln -sf /root/.local/share/fnm/node-versions/v24.16.0/installation/bin/npx  /usr/local/bin/npx

echo "==> 写入 npm 镜像配置"
cat > /etc/npmrc << 'EOF'
registry=https://registry.npmmirror.com/
EOF

cat > /root/.npmrc << 'EOF'
registry=https://registry.npmmirror.com/
EOF

echo "==> 清理 .bashrc 重复配置"
sed -i.bak '/^# fnm$/,/^fi$/d' /root/.bashrc

echo "==> 验证"
fnm --version
node --version
npm --version
npm config get registry
npm ping

echo ""
echo "安装完成。"
