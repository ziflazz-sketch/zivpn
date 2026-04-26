#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
LISTEN_ADDR="127.0.0.1:7300"
BIN_DST="/usr/local/bin/badvpn-udpgw"
SERVICE_FILE="/etc/systemd/system/badvpn-udpgw.service"
SRC_DIR="/usr/local/src/badvpn-src"
BUILD_DIR="$SRC_DIR/build-udpgw"

have_service_listening() {
  command -v ss >/dev/null 2>&1 && ss -lntup 2>/dev/null | grep -q '127\.0\.0\.1:7300'
}

ensure_service_file() {
  cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=BadVPN UDPGW Service (127.0.0.1:7300)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
ExecStart=$BIN_DST --listen-addr $LISTEN_ADDR --max-clients 4096 --loglevel notice
Restart=always
RestartSec=2
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
SERVICE
}

if [ -x "$BIN_DST" ]; then
  ensure_service_file
  systemctl daemon-reload
  systemctl enable badvpn-udpgw.service >/dev/null 2>&1 || true
  systemctl restart badvpn-udpgw.service || systemctl start badvpn-udpgw.service || true
  if have_service_listening; then
    echo "UDPGW sudah aktif di $LISTEN_ADDR"
    exit 0
  fi
fi

apt-get update -y || true
apt-get install -y ca-certificates git cmake build-essential pkg-config libssl-dev zlib1g-dev || true

if command -v badvpn-udpgw >/dev/null 2>&1; then
  install -m 0755 "$(command -v badvpn-udpgw)" "$BIN_DST"
else
  rm -rf "$SRC_DIR"
  git clone --depth 1 https://github.com/ambrop72/badvpn.git "$SRC_DIR"
  mkdir -p "$BUILD_DIR"
  cd "$BUILD_DIR"
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
  make -j"$(nproc)"
  install -m 0755 "$BUILD_DIR/udpgw/badvpn-udpgw" "$BIN_DST"
fi

ensure_service_file
systemctl daemon-reload
systemctl enable badvpn-udpgw.service
systemctl restart badvpn-udpgw.service || systemctl start badvpn-udpgw.service
systemctl is-active --quiet badvpn-udpgw.service && echo "UDPGW aktif di $LISTEN_ADDR"
