#!/bin/bash
set -e

# 定义变量
SNELL_VERSION="v4.1.1"
SHADOW_TLS_VERSION="v0.2.25"
TLS_DOMAIN="gateway.icloud.com"
TLS_PASSWORD="mima"

# 更新系统
apt update
apt full-upgrade -y
apt install -y unzip wget

# 安装 snell
wget https://dl.nssurge.com/snell/snell-server-${SNELL_VERSION}-linux-amd64.zip
unzip snell-server-${SNELL_VERSION}-linux-amd64.zip -d /usr/local/bin
chmod +x /usr/local/bin/snell-server
rm snell-server-${SNELL_VERSION}-linux-amd64.zip

snell-server --wizard -c /etc/snell-server.conf
chmod 600 /etc/snell-server.conf

# systemd 服务 - snell
cat > /etc/systemd/system/snell.service << EOF
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

systemctl daemon-reload
systemctl enable --now snell

# 安装 shadow-tls
wget https://github.com/ihciah/shadow-tls/releases/download/${SHADOW_TLS_VERSION}/shadow-tls-x86_64-unknown-linux-musl -O /usr/local/bin/shadow-tls
chmod +x /usr/local/bin/shadow-tls

# systemd 服务 - shadow-tls
cat > /etc/systemd/system/shadow-tls.service << EOF
[Unit]
Description=Shadow-TLS Server Service
Documentation=man:sstls-server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/shadow-tls --fastopen --v3 server --listen ::0:8443 --server 127.0.0.1:10086 --tls ${TLS_DOMAIN} --password ${TLS_PASSWORD}
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=shadow-tls

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now shadow-tls.service
