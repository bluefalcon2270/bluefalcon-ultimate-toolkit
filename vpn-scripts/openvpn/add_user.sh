#!/bin/bash
u=$1; p=$2
APP_DIR="/opt/bluefalcon-ultimate-toolkit"

# Fetch True IP from Database to avoid WARP hijacks
IPV4=$(sqlite3 "${APP_DIR}/panel.db" "SELECT public_ip FROM settings LIMIT 1;")
if [ -z "$IPV4" ]; then IPV4=$(curl --interface $(ip route show table main | awk '/default/ {print $5}' | head -1) -s4 ifconfig.me || echo "127.0.0.1"); fi

PROTOCOL=$(sqlite3 "${APP_DIR}/panel.db" "SELECT protocol FROM settings LIMIT 1;")
PORT=$(sqlite3 "${APP_DIR}/panel.db" "SELECT port FROM settings LIMIT 1;")
cd "${APP_DIR}/easy-rsa"
./easyrsa --batch build-client-full "$u" nopass > /dev/null 2>&1

cat > "${APP_DIR}/configs/${u}.ovpn" << EOCONF
client
dev tun
proto $PROTOCOL
remote $IPV4 $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
auth-user-pass
<auth-user-pass>
$u
$p
</auth-user-pass>
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' pki/issued/${u}.crt)
</cert>
<key>
$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' pki/private/${u}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/server/tc.key)
</tls-crypt>
EOCONF

cat > "${APP_DIR}/configs/${u}_manual.ovpn" << EOCONF
client
dev tun
proto $PROTOCOL
remote $IPV4 $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
ignore-unknown-option block-outside-dns
block-outside-dns
auth-user-pass
<ca>
$(cat /etc/openvpn/server/ca.crt)
</ca>
<cert>
$(sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' pki/issued/${u}.crt)
</cert>
<key>
$(sed -n '/BEGIN PRIVATE KEY/,/END PRIVATE KEY/p' pki/private/${u}.key)
</key>
<tls-crypt>
$(cat /etc/openvpn/server/tc.key)
</tls-crypt>
EOCONF