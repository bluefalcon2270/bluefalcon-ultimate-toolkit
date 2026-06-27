#!/usr/bin/env bash
# ==============================================================================
# WireGuard Core Setup Script
# ==============================================================================
set -e
umask 077

PORT="${1:-51820}"
DNS1="${2:-8.8.8.8}"
DNS2="${3:-8.8.4.4}"
PUBLIC_IP=$(curl --interface $(ip route | awk '/default/ {print $5}' | head -1) -s4 ifconfig.me)

echo "🚀 STARTING WIREGUARD INSTALLATION..."
echo "-----------------------------------------------------"
echo "  Installing WireGuard Tools"
echo "-----------------------------------------------------"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y > /dev/null 2>&1
apt-get install -y wireguard-tools qrencode sqlite3 > /dev/null 2>&1

echo "  Generating Server Keys"
echo "-----------------------------------------------------"
mkdir -p /etc/wireguard
cd /etc/wireguard
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
SERVER_PRIV=$(cat server_private.key)

echo "  Configuring wg0 Interface"
echo "-----------------------------------------------------"
SERVER_PUB_NIC=$(ip route | awk '/default/ {print $5}' | head -1)

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.7.0.1/24
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIV}
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
EOF

echo "  Enabling IP Forwarding"
echo "-----------------------------------------------------"
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf > /dev/null 2>&1

echo "  Configuring Firewall (UFW)"
echo "-----------------------------------------------------"
ufw allow "${PORT}"/udp > /dev/null 2>&1 || true

echo "  Starting WireGuard Service"
echo "-----------------------------------------------------"
systemctl enable wg-quick@wg0 > /dev/null 2>&1
systemctl restart wg-quick@wg0 > /dev/null 2>&1

# Update SQLite Database to mark as installed
sqlite3 /opt/bluefalcon-ultimate-toolkit/panel.db "UPDATE settings SET is_installed=1, port=${PORT}, dns='${DNS1}', dns2='${DNS2}' WHERE server_name='wireguard';"

echo "[ ✔ ] WireGuard successfully installed on port ${PORT}!"
