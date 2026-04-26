#!/bin/bash
chattr -i /etc/zivpn/api_auth.key
echo -e "Backup Data ZiVPN Old..."
rm -rf /etc/zivpn-backup
cp -r /etc/zivpn /etc/zivpn-backup
echo -e "Uninstalling ZiVPN Old..."
svc="zivpn.service"
systemctl stop $svc 1>/dev/null 2>/dev/null
systemctl disable $svc 1>/dev/null 2>/dev/null
rm -f /etc/systemd/system/$svc 1>/dev/null 2>/dev/null
echo "Removed service $svc"
echo "Cleaning Cache"
echo 3 > /proc/sys/vm/drop_caches
sysctl -w vm.drop_caches=3
export DEBIAN_FRONTEND=noninteractive
dpkg --configure -a || true
apt -f install -y || true
apt update
apt install -y sudo screen ufw ruby rubygems figlet lolcat curl wget python3-pip jq curl sudo zip figlet lolcat vnstat cron
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
sudo apt install iptables-persistent -y
apt install -y iptables-persistent netfilter-persistent
iptables -t nat -F PREROUTING
sudo netfilter-persistent save
echo "1. Update OS dan install dependensi..."
apt update
apt install -y wget curl ca-certificates
update-ca-certificates
echo "2. Hentikan service lama (jika ada)..."
systemctl stop zivpn 2>/dev/null
echo "3. Hapus binary lama (jika ada)..."
rm -f /usr/local/bin/zivpn
echo "4. Download skrip resmi ZiVPN..."
ARCH=$(uname -m)
case "$ARCH" in
x86_64)
FILE="zi.sh"      # amd64
;;
aarch64)
FILE="zi2.sh"       # arm64
;;
armv7l|armhf)
FILE="zi3.sh"       # arm32
;;
*)
echo "❌ Arsitektur tidak didukung: $ARCH"
exit 1
;;
esac
echo "Terdeteksi arsitektur: $ARCH → pakai $FILE"
wget -O /root/zi.sh "https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/$FILE"
echo "5. Beri izin executable..."
chmod +x /root/zi.sh
echo "6. Jalankan skrip instalasi ZiVPN..."
sudo /root/zi.sh
echo "7. Reload systemd dan start service..."
systemctl daemon-reload
systemctl start zivpn
systemctl enable zivpn
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/setup_zivpn_nat.sh -O /usr/local/bin/setup_zivpn_nat.sh && chmod +x /usr/local/bin/setup_zivpn_nat.sh && /usr/local/bin/setup_zivpn_nat.sh || true
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/install_udpgw_7300.sh -O /usr/local/bin/install_udpgw_7300.sh && chmod +x /usr/local/bin/install_udpgw_7300.sh && /usr/local/bin/install_udpgw_7300.sh || true
wget -q https://raw.githubusercontent.com/ziflazz-sketch/zivpn/main/install_speedtest.sh -O /usr/local/bin/install_speedtest.sh && chmod +x /usr/local/bin/install_speedtest.sh && /usr/local/bin/install_speedtest.sh || true
echo "8. Cek status service..."
systemctl status zivpn --no-pager
echo "✅ Instalasi selesai. Service ZiVPN + UDPGW harusnya aktif dan panel bisa mendeteksi."
echo -e "Restore Data ZiVPN Old..."
rm -rf /etc/zivpn
cp -r /etc/zivpn-backup /etc/zivpn
systemctl restart zivpn.service || true
systemctl restart zivpn-api.service || true
systemctl restart badvpn-udpgw.service || true
chattr +i /etc/zivpn/api_auth.key
