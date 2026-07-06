#!/usr/bin/env bash
# ==============================================================================
# WireGuard Delete User Script
# Usage: ./del_user.sh <client_name>
# ==============================================================================
set -e

CLIENT_NAME=$1

WG_DIR="/etc/wireguard"
CLIENT_DIR="${WG_DIR}/clients"
DB_FILE="/opt/bluefalcon-ultimate-toolkit/data/panel.db"

# Fetch pub key from DB
CLIENT_PUB=$(sqlite3 "$DB_FILE" "SELECT pub_key FROM wg_users WHERE system_name='${CLIENT_NAME}';")

if [ -n "$CLIENT_PUB" ]; then
    # Remove from live interface
    wg set wg0 peer "${CLIENT_PUB}" remove || true
fi

# Remove from wg0.conf
sed -i "/# BEGIN_PEER ${CLIENT_NAME}/,/# END_PEER ${CLIENT_NAME}/d" "${WG_DIR}/wg0.conf"

# Delete client files
rm -f "${CLIENT_DIR}/${CLIENT_NAME}_private.key"
rm -f "${CLIENT_DIR}/${CLIENT_NAME}_public.key"
rm -f "${CLIENT_DIR}/${CLIENT_NAME}_preshared.key"
rm -f "${CLIENT_DIR}/${CLIENT_NAME}.conf"

# Remove from DB
sqlite3 "$DB_FILE" "DELETE FROM wg_users WHERE system_name='${CLIENT_NAME}';"

echo "[ âœ” ] User ${CLIENT_NAME} deleted successfully."
