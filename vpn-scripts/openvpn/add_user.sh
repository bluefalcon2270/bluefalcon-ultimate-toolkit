#!/bin/bash
u=$1; p=$2
readonly APP_DIR="/opt/bluefalcon-ultimate-toolkit"
IPV4=$(curl -s -4 ifconfig.me)
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