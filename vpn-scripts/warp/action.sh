#!/bin/bash
# ==============================================================================
# BlueFalcon Toolkit - WARP Background Engine
# ==============================================================================

ACTION=$1
TARGET=${2:-3}
LICENSE=${3:-}

WGCF_conf="/etc/wireguard/wgcf.conf"
Profile_conf="/etc/warp/wgcf-profile.conf"
Wgcf_account="/etc/warp/wgcf-account.toml"

install_warp() {
    export DEBIAN_FRONTEND=noninteractive
    echo "[INFO] Updating package repositories..."
    apt-get update -y
    
    echo "[INFO] Installing core network dependencies..."
    apt-get install -y curl gnupg lsb-release ca-certificates
    
    if ! command -v wgcf >/dev/null 2>&1; then
        echo "[INFO] Downloading WGCF binary..."
        curl -fsSL git.io/wgcf.sh -o /tmp/wgcf.sh
        bash /tmp/wgcf.sh
    fi
    
    if ! command -v warp-cli >/dev/null 2>&1; then
        echo "[INFO] Fetching Cloudflare Repository keys..."
        . /etc/os-release
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/cloudflare-client.list >/dev/null
        
        echo "[INFO] Installing Cloudflare client & WireGuard..."
        apt-get update -y
        local dns_pkg="resolvconf"
        if apt-get install -s openresolv >/dev/null 2>&1; then dns_pkg="openresolv"; fi
        apt-get install cloudflare-warp iproute2 "${dns_pkg}" wireguard-tools -y
    fi

    mkdir -p /etc/warp
    cd /etc/warp || exit
    
    if [[ ! -f "$Wgcf_account" ]]; then 
        echo "[INFO] Registering free Cloudflare profile..."
        wgcf register --accept-tos
    fi

    if [ -n "$LICENSE" ] && [ "$LICENSE" != "free" ]; then
        echo "[INFO] Upgrading profile to WARP+ Premium License..."
        sed -i "s/\(license_key = \).*/\1'${LICENSE}'/" "$Wgcf_account"
        wgcf update --config "$Wgcf_account"
    fi

    echo "[INFO] Generating WireGuard configuration file..."
    wgcf generate
    [ -d "/etc/wireguard" ] || mkdir -p "/etc/wireguard"
    
    local PrivateKey=$(grep ^PrivateKey "${Profile_conf}" | cut -d= -f2- | awk '$1=$1')
    local Address=$(grep ^Address "${Profile_conf}" | cut -d= -f2- | awk '$1=$1' | sed ":a;N;s/\n/,/g;ta")
    local PublicKey=$(grep ^PublicKey "${Profile_conf}" | cut -d= -f2- | awk '$1=$1')
    local MTU=1280
    
    cat <<EOF >${WGCF_conf}
[Interface]
PrivateKey = ${PrivateKey}
Address = ${Address}
DNS = 8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844
MTU = ${MTU}
EOF

    local DEFAULT_IF=$(ip route | awk '/default/ {print $5}' | head -1)
    local IPv4_addr=$(ip -4 addr show "$DEFAULT_IF" | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
    local IPv6_addr=$(ip -6 addr show "$DEFAULT_IF" | awk '/inet6 / {print $2}' | cut -d/ -f1 | grep -v '^fe80' | head -1)

    if [ "$TARGET" == "1" ] || [ "$TARGET" == "3" ]; then
        cat <<EOF >>${WGCF_conf}
PreUp = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -4 rule add from ${IPv4_addr} lookup main prio 18
PostDown = ip -4 rule delete from ${IPv4_addr} lookup main prio 18 2>/dev/null || true
EOF
    fi
    if [ "$TARGET" == "2" ] || [ "$TARGET" == "3" ]; then
        cat <<EOF >>${WGCF_conf}
PreUp = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
PostUp = ip -6 rule add from ${IPv6_addr} lookup main prio 18
PostDown = ip -6 rule delete from ${IPv6_addr} lookup main prio 18 2>/dev/null || true
EOF
    fi

    cat <<EOF >>${WGCF_conf}
[Peer]
PublicKey = ${PublicKey}
AllowedIPs = $( [ "$TARGET" == "1" ] && echo "0.0.0.0/0" || ( [ "$TARGET" == "2" ] && echo "::/0" || echo "0.0.0.0/0,::/0" ) )
Endpoint = engage.cloudflareclient.com:2408
EOF

    echo "[INFO] Securing routes and enabling Background Service..."
    (crontab -l 2>/dev/null | grep -v "wg-quick@wgcf"; echo "0 4 * * * systemctl restart wg-quick@wgcf;systemctl restart warp-svc") | crontab -
    systemctl enable --now wg-quick@wgcf
}

toggle_warp() {
    if ip link show wgcf >/dev/null 2>&1; then
        systemctl disable --now wg-quick@wgcf >/dev/null 2>&1
        wg-quick down wgcf >/dev/null 2>&1
        ip link delete wgcf >/dev/null 2>&1
    else
        systemctl enable --now wg-quick@wgcf >/dev/null 2>&1
        if ! ip link show wgcf >/dev/null 2>&1; then wg-quick up wgcf >/dev/null 2>&1; fi
    fi
}

uninstall_warp() {
    echo "[INFO] Halting WireGuard services..."
    systemctl stop wg-quick@wgcf >/dev/null 2>&1
    systemctl disable wg-quick@wgcf >/dev/null 2>&1
    
    echo "[INFO] Purging Cloudflare packages..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get purge cloudflare-warp -y
    
    echo "[INFO] Removing routing rules and config files..."
    rm -rf /etc/warp /etc/wireguard/wgcf* /usr/local/bin/wgcf
    ip link delete wgcf >/dev/null 2>&1
}

case "$ACTION" in
    install) install_warp ;;
    toggle) toggle_warp ;;
    uninstall) uninstall_warp ;;
esac