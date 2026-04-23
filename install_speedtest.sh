#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
cleanup_old_speedtest_repo() {
  rm -f /etc/apt/sources.list.d/ookla_speedtest-cli.list \
        /etc/apt/sources.list.d/ookla_speedtest-cli*.list \
        /etc/apt/sources.list.d/packagecloud_io_ookla_speedtest-cli*.list || true
}
install_speedtest_repo() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
  else
    wget -qO- https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
  fi
}
main() {
  if command -v speedtest >/dev/null 2>&1; then
    exit 0
  fi
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y curl ca-certificates gnupg apt-transport-https >/dev/null 2>&1 || true
  cleanup_old_speedtest_repo
  install_speedtest_repo
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y speedtest >/dev/null 2>&1 || apt-get install -y speedtest-cli >/dev/null 2>&1 || true
}
main "$@"
