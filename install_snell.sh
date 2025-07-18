#!/usr/bin/env bash

# Snell Proxy 安装和配置脚本
# 适用系统：Debian
# 使用本脚本前请以 root 用户运行

set -euo pipefail

# 更新包索引并升级已安装的软件包
apt update
apt upgrade -y

# 安装 unzip 工具
apt install -y unzip wget

# 下载 Snell Server
SNELL_VERSION="v5.0.0"
SNELL_ZIP="snell-server-${SNELL_VERSION}-linux-amd64.zip"
SNELL_URL="https://dl.nssurge.com/snell/${SNELL_ZIP}"
wget "$SNELL_URL"

# 解压并移动可执行文件到 /usr/local/bin
unzip "$SNELL_ZIP" -d /usr/local/bin
chmod +x /usr/local/bin/snell-server

# 运行 Snell Server 向导生成默认配置
snell-server --wizard -c /etc/snell-server.conf

# 创建 systemd 服务文件
cat > /etc/systemd/system/snell.service << 'EOF'
[Unit]
Description=Snell Proxy Service
After=network.target

[Service]
Type=simple
User=root
Group=root
LimitNOFILE=32768
ExecStart=/usr/local/bin/snell-server -c /etc/snell-server.conf
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=snell-server
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# 重新加载 systemd 配置并启动服务
systemctl daemon-reload
systemctl start snell
systemctl enable snell

# 清理下载的 zip 文件
rm -f "$SNELL_ZIP"

echo "Snell Proxy 已成功安装并以 systemd 服务形式运行。"
