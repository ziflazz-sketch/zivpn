#!/bin/bash
set -euo pipefail
echo "🔄 Updating ZiVPN Manager..."
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/install.sh \
-O /usr/local/bin/install.sh
chmod +x /usr/local/bin/install.sh
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/zivpn-manager \
-O /usr/local/bin/zivpn-manager
chmod +x /usr/local/bin/zivpn-manager
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/zivpn_helper.sh \
-O /usr/local/bin/zivpn_helper.sh
chmod +x /usr/local/bin/zivpn_helper.sh
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/update.sh \
-O /usr/local/bin/update-manager
chmod +x /usr/local/bin/update-manager
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/install_speedtest.sh \
-O /usr/local/bin/install_speedtest.sh
chmod +x /usr/local/bin/install_speedtest.sh
/usr/local/bin/install_speedtest.sh || true
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/install_zivpn_nat.sh \
-O /usr/local/bin/install_zivpn_nat.sh
chmod +x /usr/local/bin/install_zivpn_nat.sh
/usr/local/bin/install_zivpn_nat.sh || true
echo "🎉 ZiVPN Update completed successfully."
echo "⏰ Setting auto backup & auto reboot (cron)..."
CRON_BACKUP="0 * * * * /usr/local/bin/zivpn_helper.sh backup >> /var/log/zivpn_backup.log 2>&1"
CRON_REBOOT="0 1 * * * /sbin/reboot"
chmod +x /usr/local/bin/zivpn_helper.sh
(crontab -l 2>/dev/null | grep -v "zivpn_helper.sh backup" | grep -v "/sbin/reboot"; \
echo "$CRON_BACKUP"; \
echo "$CRON_REBOOT") | crontab -
echo "✅ Auto backup aktif (tiap jam)"
echo "✅ Auto reboot aktif (jam 01:00)"
echo "Setting up expiry check cron job..."
cat <<'EOF' > /etc/zivpn/expire_check.sh
DB_FILE="/etc/zivpn/users.db"
CONFIG_FILE="/etc/zivpn/config.json"
TMP_DB_FILE="${DB_FILE}.tmp"
LOCK_FILE="${DB_FILE}.lock"
CURRENT_DATE=$(date +%s)
SERVICE_RESTART_NEEDED=false
LOCK_FD=""
acquire_lock() {
exec {lock_fd}>"$LOCK_FILE" || return 1
if ! flock -x "$lock_fd"; then
eval "exec ${lock_fd}>&-"
return 1
fi
LOCK_FD="$lock_fd"
}
release_lock() {
[ -n "$LOCK_FD" ] || return 0
flock -u "$LOCK_FD" 2>/dev/null || true
eval "exec ${LOCK_FD}>&-"
LOCK_FD=""
}
cleanup() {
[ -n "$TMP_DB_FILE" ] && rm -f "$TMP_DB_FILE"
release_lock
}
trap cleanup EXIT
if [ ! -f "$DB_FILE" ]; then exit 0; fi
if ! acquire_lock; then exit 1; fi
> "$TMP_DB_FILE"
while IFS=':' read -r password expiry_date; do
if [[ -z "$password" ]]; then continue; fi
if ! [[ "$expiry_date" =~ ^[0-9]+$ ]]; then
echo "${password}:${expiry_date}" >> "$TMP_DB_FILE"
continue
fi
if [ "$expiry_date" -le "$CURRENT_DATE" ]; then
echo "User '${password}' has expired. Deleting permanently."
jq --arg pass "$password" 'del(.auth.config[] | select(. == $pass))' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
SERVICE_RESTART_NEEDED=true
else
echo "${password}:${expiry_date}" >> "$TMP_DB_FILE"
fi
done < "$DB_FILE"
mv "$TMP_DB_FILE" "$DB_FILE"
TMP_DB_FILE=""
if [ "$SERVICE_RESTART_NEEDED" = true ]; then
echo "User(s) removed, but skipping service restart to avoid disconnecting active users."
echo "Use menu 15 or 16 for manual cleanup with restart when needed."
fi
exit 0
EOF
chmod +x /etc/zivpn/expire_check.sh
CRON_JOB_EXPIRY="* * * * * /etc/zivpn/expire_check.sh # zivpn-expiry-check"
(crontab -l 2>/dev/null | grep -v "# zivpn-expiry-check") | crontab -
(crontab -l 2>/dev/null; echo "$CRON_JOB_EXPIRY") | crontab -
echo "🧩 Ensuring ZiVPN NAT persistence..."
/usr/local/bin/install_zivpn_nat.sh || true
/usr/local/bin/zivpn-manager
