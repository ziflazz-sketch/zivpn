#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if command -v speedtest >/dev/null 2>&1; then
  exit 0
fi

cleanup_old_speedtest_repo() {
  find /etc/apt -type f \( -name '*.list' -o -name '*.sources' \) 2>/dev/null | while read -r f; do
    if grep -qiE 'packagecloud|ookla|speedtest' "$f"; then
      rm -f "$f" || true
    fi
  done
}

retry_apt_update() {
  apt-get clean || true
  rm -rf /var/lib/apt/lists/* || true
  for _ in 1 2 3; do
    if apt-get update -y; then
      return 0
    fi
    sleep 2
  done
  return 1
}

force_packagecloud_dist() {
  if [ ! -r /etc/os-release ]; then
    echo 'OS tidak dikenali' >&2
    return 1
  fi

  . /etc/os-release
  local forced_os="${ID:-}"
  local forced_dist="${VERSION_CODENAME:-}"

  case "${ID:-}" in
    ubuntu)
      case "${VERSION_CODENAME:-}" in
        focal) forced_dist="focal" ;;
        jammy) forced_dist="jammy" ;;
        noble) forced_dist="jammy" ;;
        *)
          case "${VERSION_ID:-}" in
            20.*) forced_dist="focal" ;;
            22.*) forced_dist="jammy" ;;
            24.*) forced_dist="jammy" ;;
            *) echo "Ubuntu ${VERSION_ID:-unknown} tidak didukung untuk speedtest" >&2; return 1 ;;
          esac
        ;;
      esac
    ;;
    debian)
      case "${VERSION_CODENAME:-}" in
        buster|bullseye|bookworm) forced_dist="${VERSION_CODENAME}" ;;
        *)
          case "${VERSION_ID:-}" in
            10) forced_dist="buster" ;;
            11) forced_dist="bullseye" ;;
            12) forced_dist="bookworm" ;;
            *) echo "Debian ${VERSION_ID:-unknown} tidak didukung untuk speedtest" >&2; return 1 ;;
          esac
        ;;
      esac
    ;;
    *) echo "OS ${ID:-unknown} tidak didukung untuk speedtest" >&2; return 1 ;;
  esac

  tmp_script="$(mktemp /tmp/ookla-speedtest.XXXXXX.sh)"
  trap 'rm -f "$tmp_script"' EXIT
  curl -fsSL https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh -o "$tmp_script"
  chmod +x "$tmp_script"
  os="$forced_os" dist="$forced_dist" "$tmp_script"
}

cleanup_old_speedtest_repo
retry_apt_update || true
apt-get install -y curl ca-certificates gnupg >/dev/null 2>&1 || true

if ! force_packagecloud_dist; then
  echo 'Gagal menyiapkan repo speedtest' >&2
  exit 1
fi

retry_apt_update
apt-get install -y speedtest=1.2.0.84-1.ea6b6773cf || apt-get install -y speedtest
