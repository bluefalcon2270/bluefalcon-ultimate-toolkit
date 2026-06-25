# ==============================================================================
# --- Constants, Colors & UI Utilities ---
# ==============================================================================

# --- Constants & Configuration ---
readonly SCRIPT_VERSION="v2.4"
readonly APP_DIR="/opt/bluefalcon-ultimate-toolkit"
readonly LOG_FILE="/var/log/bluefalcon_toolkit.log"
readonly WARP_LOG="/var/log/bluefalcon_warp.log"
readonly SSH_CONFIG="/etc/ssh/sshd_config"

# --- Colors ---
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly BOLD_BLUE='\033[1;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# --- Initialization & Traps ---
touch "${LOG_FILE}" "${WARP_LOG}"

cleanup() {
    echo -e "${NC}\n[!] Process interrupted. Cleaning up..."
    local jobs=$(jobs -p)
    [ -n "$jobs" ] && kill $jobs 2>/dev/null
    tput cnorm
    rm -f /tmp/wgcf.sh
    exit 1
}
trap cleanup SIGINT SIGTERM

# --- Core Utility Functions ---
pause_execution() {
    tput cnorm
    echo ""
    read -n 1 -s -r -p "Press any key to continue..."
    echo ""
}

run_with_spinner() {
    local msg="$1"
    shift
    local log_tgt="${CURRENT_LOG:-$LOG_FILE}"
    "$@" >> "$log_tgt" 2>&1 &
    local pid=$!
    local delay=0.1
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    
    tput civis
    while kill -0 "$pid" 2>/dev/null; do
        for frame in "${frames[@]}"; do
            printf "\r[ ${CYAN}%s${NC} ] %s" "$frame" "$msg"
            sleep $delay
        done
    done
    wait "$pid"
    local exit_status=$?
    
    if [ $exit_status -eq 0 ]; then
        printf "\r[ ${GREEN}✔${NC} ] %s\n" "$msg"
    else
        printf "\r[ ${RED}✖${NC} ] %s\n" "$msg"
        tput cnorm
        return 1
    fi
    tput cnorm
}