#!/bin/bash
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

log() { echo -e "$*"; }

if [ "$EUID" -ne 0 ]; then
  log "❌ Jalankan script ini sebagai root."
  exit 1
fi

if [ ! -r /etc/os-release ]; then
  log "❌ /etc/os-release tidak ditemukan."
  exit 1
fi

. /etc/os-release

ARCH="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
esac

case "$ARCH" in
  amd64|arm64|armhf) ;;
  *)
    log "❌ Arsitektur tidak didukung untuk speedtest resmi Ookla: $ARCH"
    exit 1
    ;;
esac

log "🧹 Membersihkan repo speedtest lama yang sering bikin apt error..."
find /etc/apt/sources.list.d -maxdepth 1 -type f \( -iname '*speedtest*' -o -iname '*ookla*' \) -print -delete 2>/dev/null || true
if [ -f /etc/apt/sources.list ]; then
  sed -i '\|packagecloud.io/ookla/speedtest-cli|d' /etc/apt/sources.list || true
fi
rm -f /etc/apt/keyrings/speedtestcli-archive-keyring.gpg 2>/dev/null || true
rm -f /usr/share/keyrings/speedtestcli-archive-keyring.gpg 2>/dev/null || true

log "📦 Menginstall dependensi..."
apt-get update -y
apt-get install -y ca-certificates wget curl

DISTRO_PATH=""
PKG_VERSION=""
DISTRO_VERSION_ID=""
NOTE=""

case "${ID:-}" in
  debian)
    case "${VERSION_ID:-}" in
      10)
        DISTRO_PATH="debian/buster"
        PKG_VERSION="1.2.0.84-1.ea6b6773cf"
        DISTRO_VERSION_ID="150"
        ;;
      11)
        DISTRO_PATH="debian/bullseye"
        PKG_VERSION="1.1.0.75-1.810304edbd"
        DISTRO_VERSION_ID="207"
        ;;
      12)
        DISTRO_PATH="debian/bookworm"
        PKG_VERSION="1.2.0.84-1.ea6b6773cf"
        DISTRO_VERSION_ID="215"
        ;;
      *)
        log "❌ Debian ${VERSION_ID:-unknown} belum didukung oleh script ini."
        exit 1
        ;;
    esac
    ;;
  ubuntu)
    case "${VERSION_ID:-}" in
      20.04)
        DISTRO_PATH="ubuntu/focal"
        PKG_VERSION="1.2.0.84-1.ea6b6773cf"
        DISTRO_VERSION_ID="210"
        ;;
      22.04|24.04)
        DISTRO_PATH="ubuntu/focal"
        PKG_VERSION="1.2.0.84-1.ea6b6773cf"
        DISTRO_VERSION_ID="210"
        NOTE="⚠️ Ubuntu ${VERSION_ID} memakai paket resmi Ookla build Ubuntu focal sebagai fallback kompatibilitas."
        ;;
      *)
        log "❌ Ubuntu ${VERSION_ID:-unknown} belum didukung oleh script ini."
        exit 1
        ;;
    esac
    ;;
  *)
    log "❌ OS ${ID:-unknown} tidak didukung. Hanya Ubuntu 20/22/24 dan Debian 10/11/12."
    exit 1
    ;;
esac

[ -n "$NOTE" ] && log "$NOTE"

TMP_DEB="/tmp/speedtest_${PKG_VERSION}_${ARCH}.deb"
PKG_URL="https://packagecloud.io/ookla/speedtest-cli/packages/${DISTRO_PATH}/speedtest_${PKG_VERSION}_${ARCH}.deb/download.deb?distro_version_id=${DISTRO_VERSION_ID}"

log "⬇️ Download speedtest resmi Ookla..."
wget -O "$TMP_DEB" "$PKG_URL"

log "📥 Install speedtest..."
apt-get install -y "$TMP_DEB"

if ! command -v speedtest >/dev/null 2>&1; then
  log "❌ Binary speedtest tidak ditemukan setelah instalasi."
  exit 1
fi

log "✅ Speedtest berhasil diinstall."
speedtest --version || true

rm -f "$TMP_DEB" 2>/dev/null || true
