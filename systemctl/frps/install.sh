#!/bin/bash
set -ex
# 脚本使用说明
echo "使用说明："
echo "  $0"


# 获取当前目录
current_dir=$(dirname "$0")

# 安装 frps 服务
cat <<EOF > tee /etc/systemd/system/frps.service
[Unit]
Description=frp server (frps)
After=network.target

[Service]
Type=simple
ExecStart=$current_dir/frps -c $current_dir/frps.toml
Restart=always
RestartSec=5
User=root
LimitNOFILE=1048576

# 安全加固（可选但推荐）
#ProtectSystem=strict
#ReadWritePaths=/etc/frp /var/log/frp

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable frps
systemctl start frps
