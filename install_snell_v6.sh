cat > snell.sh << 'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

########################################
# Root Check
########################################
[[ $EUID -eq 0 ]] || {
    echo "Please run this script as root."
    exit 1
}

########################################
# Variables
########################################
readonly SNELL_VERSION="v6.0.0rc"
readonly PLATFORM="linux-amd64"
readonly ZIP_FILE="snell-server-${SNELL_VERSION}-${PLATFORM}.zip"
readonly DOWNLOAD_URL="https://dl.nssurge.com/snell/${ZIP_FILE}"

TMP_DIR="$(mktemp -d)"

########################################
# Cleanup
########################################
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

########################################
# Colors
########################################
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

########################################
# Install Dependencies
########################################
info "Updating package index..."

apt-get update

info "Installing dependencies..."

apt-get install -y --no-install-recommends \
    wget \
    unzip

########################################
# Download Snell
########################################
cd "$TMP_DIR"

info "Downloading Snell Server ${SNELL_VERSION}..."

wget \
    --tries=3 \
    --timeout=30 \
    --show-progress \
    "$DOWNLOAD_URL"

########################################
# Install Binary
########################################
info "Installing Snell..."

unzip -q "$ZIP_FILE"

install -m755 snell-server /usr/local/bin/snell-server

########################################
# Generate Config
########################################
info "Starting Snell configuration wizard..."

mkdir -p /etc

/usr/local/bin/snell-server --wizard -c /etc/snell-server.conf

########################################
# Create systemd Service
########################################
info "Creating systemd service..."

cat >/etc/systemd/system/snell.service <<'EON'
[Unit]
Description=Snell Proxy Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
Group=root

ExecStart=/usr/local/bin/snell-server -c /etc/snell-server.conf

Restart=on-failure
RestartSec=3

LimitNOFILE=65535

StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EON

########################################
# Enable Service
########################################
info "Starting Snell service..."

systemctl daemon-reload
systemctl enable --now snell

########################################
# Verify
########################################
if systemctl is-active --quiet snell; then
    info "Snell installed successfully."
else
    error "Snell service failed to start."
    systemctl status snell --no-pager
    exit 1
fi

echo
info "Useful commands:"
echo "  systemctl status snell"
echo "  systemctl restart snell"
echo "  journalctl -u snell -f"

EOF

chmod +x snell.sh
