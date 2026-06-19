# ==============================================================================
# --- Preflight System Checks ---
# ==============================================================================

check_preflight() {
    if [[ "${EUID}" -ne 0 ]]; then
        echo -e "[ ${RED}✖${NC} ] Error: This script requires root privileges. Execute with sudo or as root."
        exit 1
    fi
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "[ ${RED}✖${NC} ] Error: No active internet connection detected."
        exit 1
    fi
    if lsof /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || lsof /var/lib/apt/lists/lock >/dev/null 2>&1; then
        echo -e "[ ${RED}✖${NC} ] Error: Package manager is currently locked by another process."
        exit 1
    fi
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "${ID}" == "ubuntu" && ("${VERSION_ID}" == "22.04" || "${VERSION_ID}" == "24.04") ]] || \
           [[ "${ID}" == "debian" && ("${VERSION_ID}" == "11" || "${VERSION_ID}" == "12" || "${VERSION_ID}" == "13") ]]; then
            :
        else
            echo -e "[ ${RED}✖${NC} ] Error: Toolkit strictly supports Ubuntu 22.04/24.04 or Debian 11/12/13."
            exit 1
        fi
    else
        echo -e "[ ${RED}✖${NC} ] Error: Cannot detect OS. /etc/os-release missing."
        exit 1
    fi
}