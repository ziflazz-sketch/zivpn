#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
SCRIPT_PATH="/usr/local/bin/zivpn-nat-apply"
SERVICE_FILE="/etc/systemd/system/zivpn-nat.service"

apt-get update -y >/dev/null 2>&1 || true
apt-get install -y iptables-persistent netfilter-persistent >/dev/null 2>&1 || true
systemctl enable netfilter-persistent >/dev/null 2>&1 || true

cat > "$SCRIPT_PATH" <<'EOS'
#!/bin/bash
set -euo pipefail
get_iface() {
  ip -4 route show default 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="dev"){print $(i+1); exit}}'
}
IFACE="$(get_iface)"
[ -n "${IFACE:-}" ] || exit 0
if ! iptables -t nat -C PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667 2>/dev/null; then
  iptables -t nat -A PREROUTING -i "$IFACE" -p udp --dport 6000:19999 -j DNAT --to-destination :5667
fi
netfilter-persistent save >/dev/null 2>&1 || true
EOS
chmod +x "$SCRIPT_PATH"

cat > "$SERVICE_FILE" <<SERVICE
[Unit]
Description=ZiVPN NAT Persistence Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
ExecReload=$SCRIPT_PATH
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable zivpn-nat.service >/dev/null 2>&1 || true
systemctl restart zivpn-nat.service >/dev/null 2>&1 || systemctl start zivpn-nat.service >/dev/null 2>&1 || true
