#!/bin/bash
set -euo pipefail

echo "[ZiVPN NAT] Menyiapkan NAT persistence..."
export DEBIAN_FRONTEND=noninteractive

echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections || true
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections || true
apt-get update -y >/dev/null 2>&1 || true
apt-get install -y iptables-persistent netfilter-persistent >/dev/null 2>&1 || true
systemctl enable netfilter-persistent >/dev/null 2>&1 || true

cat <<'EOF' > /usr/local/bin/zivpn-nat-apply
#!/bin/bash
set -euo pipefail
ACTION="${1:-apply}"
WAIT_TRIES="${WAIT_TRIES:-20}"
WAIT_SECS="${WAIT_SECS:-2}"
RULE_MATCH='--dport 6000:19999'
TARGET_MATCH='--to-destination :5667'

get_iface() {
  ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}

wait_for_iface() {
  local iface=""
  local i
  for i in $(seq 1 "$WAIT_TRIES"); do
    iface="$(get_iface)"
    if [ -n "$iface" ]; then
      echo "$iface"
      return 0
    fi
    sleep "$WAIT_SECS"
  done
  return 1
}

remove_existing_rules() {
  local line delete_line
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    delete_line="${line/-A /-D }"
    eval "iptables -t nat ${delete_line}" >/dev/null 2>&1 || true
  done < <(iptables -t nat -S PREROUTING 2>/dev/null | grep -- "$RULE_MATCH" | grep -- "$TARGET_MATCH" || true)
}

apply_rule() {
  local iface="$1"
  remove_existing_rules
  iptables -t nat -A PREROUTING -i "$iface" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
  netfilter-persistent save >/dev/null 2>&1 || true
}

status_rule() {
  if iptables -t nat -S PREROUTING 2>/dev/null | grep -q -- "$RULE_MATCH" &&      iptables -t nat -S PREROUTING 2>/dev/null | grep -q -- "$TARGET_MATCH"; then
    echo "active"
  else
    echo "missing"
  fi
}

case "$ACTION" in
  apply)
    IFACE="$(wait_for_iface)" || { echo "[ZiVPN NAT] Interface default tidak ditemukan"; exit 1; }
    apply_rule "$IFACE"
    echo "[ZiVPN NAT] NAT aktif di interface: $IFACE"
    ;;
  status)
    status_rule
    ;;
  delete)
    remove_existing_rules
    netfilter-persistent save >/dev/null 2>&1 || true
    echo "[ZiVPN NAT] NAT rule dihapus"
    ;;
  *)
    echo "Usage: $0 {apply|status|delete}"
    exit 1
    ;;
esac
EOF
chmod +x /usr/local/bin/zivpn-nat-apply

cat <<'EOF' > /etc/systemd/system/zivpn-nat.service
[Unit]
Description=ZiVPN NAT Persistence Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/zivpn-nat-apply apply
ExecReload=/usr/local/bin/zivpn-nat-apply apply
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable zivpn-nat.service >/dev/null 2>&1 || true
systemctl restart zivpn-nat.service >/dev/null 2>&1 || systemctl start zivpn-nat.service >/dev/null 2>&1 || true

(crontab -l 2>/dev/null | grep -v '# zivpn-nat-watchdog') | crontab - || true
(crontab -l 2>/dev/null; echo '*/2 * * * * /usr/local/bin/zivpn-nat-apply apply >/dev/null 2>&1 # zivpn-nat-watchdog') | crontab - || true

if /usr/local/bin/zivpn-nat-apply status | grep -q '^active$'; then
  echo "[ZiVPN NAT] NAT persistence berhasil diaktifkan."
else
  echo "[ZiVPN NAT] NAT belum aktif, cek: systemctl status zivpn-nat.service"
fi
