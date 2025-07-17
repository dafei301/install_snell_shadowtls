#!/usr/bin/env bash
# install-xanmod.sh
# 在 Debian 12 上安装 gnupg、添加 XanMod APT 源并安装 XanMod 内核及构建模块依赖

set -euo pipefail

# 确保以 root 身份运行
if [[ $EUID -ne 0 ]]; then
  echo "请以 root 用户运行此脚本！" >&2
  exit 1
fi

# 变量
KEYRING_DIR="/etc/apt/keyrings"
KEYRING_FILE="${KEYRING_DIR}/xanmod-archive-keyring.gpg"
SRC_LIST="/etc/apt/sources.list.d/xanmod-release.list"
CODENAME=$(lsb_release -sc)

echo "当前发行版代号：${CODENAME}"

# 0. 安装 gnupg（如果系统中没有 gpg）
if ! command -v gpg >/dev/null 2>&1; then
  echo "检测到系统中缺少 gpg，正在安装 gnupg..."
  apt update
  apt install -y gnupg
fi

# 1. 注册 PGP 密钥
echo "1. 注册 XanMod APT 源密钥..."
mkdir -p "${KEYRING_DIR}"
wget -qO - https://dl.xanmod.org/archive.key \
  | gpg --dearmor -o "${KEYRING_FILE}"

# 2. 添加 APT 源
echo "2. 添加 XanMod APT 源到：${SRC_LIST}"
cat > "${SRC_LIST}" <<EOF
deb [signed-by=${KEYRING_FILE}] http://deb.xanmod.org ${CODENAME} main
EOF

# 3. 更新索引并安装 XanMod 内核
echo "3. 更新索引并安装 XanMod 内核 (linux-xanmod-x64v3) ..."
apt update
apt install -y linux-xanmod-x64v3

# 4. （可选）安装构建外部模块的最小依赖
echo "4. 安装 DKMS、libdw-dev、LLVM/Clang 等依赖..."
apt install --no-install-recommends -y dkms libdw-dev clang lld llvm

echo
echo "安装完成！请重启系统以使用 XanMod 内核："
echo "  reboot"
