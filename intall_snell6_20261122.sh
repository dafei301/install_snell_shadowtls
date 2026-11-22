#!/usr/bin/env bash
set -euo pipefail

# 仅在 root、x86_64 的 Debian 系统上执行。
[ "$(id -u)" -eq 0 ] || { echo '请以 root 运行'; exit 1; }
[ "$(uname -m)" = 'x86_64' ] || { echo '只支持 x86_64/amd64'; exit 1; }
. /etc/os-release
[ "$ID" = 'debian' ] || { echo '此脚本仅适用于 Debian'; exit 1; }

# 安装下载、解压和生成密钥所需的工具。
apt-get update
apt-get install -y --no-install-recommends ca-certificates curl openssl unzip iproute2

# 从 Surge 官方下载并测试 Snell v6.0.0 安装包。
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
curl -fL --retry 3 -o "$workdir/snell.zip" 'https://dl.nssurge.com/snell/snell-server-v6.0.0-linux-amd64.zip'
unzip -tq "$workdir/snell.zip"
unzip -q "$workdir/snell.zip" -d "$workdir"
install -o root -g root -m 755 "$workdir/snell-server" /usr/local/bin/snell-server

# 生成随机 PSK，并保护包含密钥的配置文件。
psk="$(openssl rand -hex 32)"
install -d -o root -g root -m 700 /etc/snell
umask 077
printf '[snell-server]\nlisten = 0.0.0.0:18280,[::]:18280\npsk = %s\nmode = default\ndns-ip-preference = prefer-ipv4\n' "$psk" > /etc/snell/snell-server.conf
chmod 600 /etc/snell/snell-server.conf

# 创建以非 root 身份运行的 systemd 服务。
cat > /etc/systemd/system/snell.service <<'UNIT'
[Unit]
Description=Snell v6.0.0 Proxy Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
DynamicUser=yes
LoadCredential=snell-server.conf:/etc/snell/snell-server.conf
ExecStart=/usr/local/bin/snell-server -c ${CREDENTIALS_DIRECTORY}/snell-server.conf
Restart=on-failure
RestartSec=3
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
UNIT

# 检查配置、加载服务，并设置立即启动及开机自启。
systemd-analyze verify /etc/systemd/system/snell.service
systemctl daemon-reload
systemctl enable --now snell
sleep 1
systemctl is-active --quiet snell || { journalctl -u snell -n 20 --no-pager; exit 1; }
ss -H -lnt 'sport = :18280' | grep -q . || { echo 'Snell 未监听 TCP 18280'; exit 1; }

# 查询出口 IPv4 并输出 Surge 客户端配置；PSK 请妥善保管。
server_ip="$(curl -4fsS --max-time 8 https://api.ipify.org || true)"
[ -n "$server_ip" ] || server_ip='你的VPS公网IPv4'
echo 'Snell v6.0.0 已启动，TCP 端口：18280'
echo "PSK: $psk"
echo "Surge: DMIT-LAX = snell, $server_ip, 18280, psk=$psk, version=6, mode=default"
