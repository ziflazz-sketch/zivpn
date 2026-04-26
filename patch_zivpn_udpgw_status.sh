#!/bin/bash
set -euo pipefail
TARGET_DIR="${1:-.}"
cd "$TARGET_DIR"
for f in install.sh update.sh fix-zivpn.sh zi.sh zi2.sh zi3.sh zivpn-manager README.md; do
  [ -f "$f" ] || continue
  sed -i 's|https://raw.githubusercontent.com/ziflazz-sketch/udp-zivpn/main|https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main|g' "$f"
done
echo "Patch dasar repo URL selesai. Gunakan ZIP hasil edit untuk perubahan penuh UDPGW/NAT/panel."
