#!/usr/bin/env bash
# ==============================================================================
# WireGuard Add User Script
# Usage: ./add_user.sh <client_name> <exp_days>
# ==============================================================================
set -e
umask 077

CLIENT_NAME=$1
EXP_DAYS=$2
EXP_DATE=$(date -d "+${EXP_DAYS} days" +%s)

# Setup directories
WG_DIR="/etc/wireguard"
CLIENT_DIR="${WG_DIR}/clients"
mkdir -p "${CLIENT_DIR}"

# DB paths
DB_FILE="/opt/bluefalcon-ultimate-toolkit/panel.db"
SERVER_PUB_IP=$(sqlite3 "$DB_FILE" "SELECT public_ip FROM settings WHERE server_name='wireguard';")
if [ -z "$SERVER_PUB_IP" ]; then
    SERVER_PUB_IP=$(curl --interface $(ip route | awk '/default/ {print $5}' | head -1) -s4 ifconfig.me)
fi
SERVER_PORT=$(sqlite3 "$DB_FILE" "SELECT port FROM settings WHERE server_name='wireguard';")
DNS1=$(sqlite3 "$DB_FILE" "SELECT dns FROM settings WHERE server_name='wireguard';")
DNS2=$(sqlite3 "$DB_FILE" "SELECT dns2 FROM settings WHERE server_name='wireguard';")
SERVER_PUB_KEY=$(cat "${WG_DIR}/server_public.key")

# Generate Client Keys
cd "${CLIENT_DIR}"
wg genkey | tee "${CLIENT_NAME}_private.key" | wg pubkey > "${CLIENT_NAME}_public.key"
wg genpsk > "${CLIENT_NAME}_preshared.key"

CLIENT_PRIV=$(cat "${CLIENT_NAME}_private.key")
CLIENT_PUB=$(cat "${CLIENT_NAME}_public.key")
CLIENT_PSK=$(cat "${CLIENT_NAME}_preshared.key")

# Find an available IP in 10.7.0.0/24 subnet (starting from 10.7.0.2)
# We will read existing IPs from wg0.conf
USED_IPS=$(grep -oE '10\.7\.0\.[0-9]+' "${WG_DIR}/wg0.conf" || true)

CLIENT_IP=""
for i in {2..254}; do
    candidate="10.7.0.${i}"
    if ! echo "$USED_IPS" | grep -q "$candidate"; then
        CLIENT_IP="$candidate"
        break
    fi
done

if [ -z "$CLIENT_IP" ]; then
    echo "Error: No available IPs in subnet 10.7.0.0/24."
    exit 1
fi

# Add peer to server config
cat >> "${WG_DIR}/wg0.conf" <<EOF

# BEGIN_PEER ${CLIENT_NAME}
[Peer]
PublicKey = ${CLIENT_PUB}
PresharedKey = ${CLIENT_PSK}
AllowedIPs = ${CLIENT_IP}/32
# END_PEER ${CLIENT_NAME}
EOF

# Apply live without restarting the interface
wg set wg0 peer "${CLIENT_PUB}" preshared-key "${CLIENT_NAME}_preshared.key" allowed-ips "${CLIENT_IP}/32"

# Generate client config file
cat > "${CLIENT_DIR}/${CLIENT_NAME}.conf" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}/24
DNS = ${DNS1}, ${DNS2}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PSK}
Endpoint = ${SERVER_PUB_IP}:${SERVER_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

# Add to SQLite database
sqlite3 "$DB_FILE" "INSERT INTO wg_users (display_name, system_name, pub_key, ip_address, exp_days, status, rx, tx) VALUES ('${CLIENT_NAME}', '${CLIENT_NAME}', '${CLIENT_PUB}', '${CLIENT_IP}', ${EXP_DAYS}, 'active', 0, 0);"

echo "[ ✔ ] User ${CLIENT_NAME} added successfully with IP ${CLIENT_IP}."
