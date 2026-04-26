#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
if command -v speedtest >/dev/null 2>&1; then
  exit 0
fi
find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null | while read -r f; do
  if grep -qiE 'packagecloud|ookla|speedtest' "$f"; then
    rm -f "$f" || true
  fi
done
apt-get update -y || true
apt-get install -y curl ca-certificates gnupg >/dev/null 2>&1 || true
curl -fsSL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash || true
apt-get update -y || true
apt-get install -y speedtest || true
