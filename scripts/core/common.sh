#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Common Functions Library
# ============================================================

# --- Repository Info ---
REPO_OWNER="zizwanphgziz"
REPO_NAME="freeflowasvpn"
REPO_BRANCH="devin/1778775736-v2.1-ux-fix"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"
VERSION_FILE="/etc/freeflow/version"
CONFIG_DIR="/etc/freeflow"
DATA_DIR="/etc/freeflow/data"
USER_DB="${DATA_DIR}/users"
LOG_DIR="/var/log/freeflow"
XRAY_CONFIG="/etc/xray/config.json"
NGINX_CONF="/etc/nginx/conf.d/freeflow.conf"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# --- Status Icons ---
OK="${GREEN}[OK]${NC}"
FAIL="${RED}[FAIL]${NC}"
WARN="${YELLOW}[WARN]${NC}"
INFO="${BLUE}[INFO]${NC}"

# --- Print Functions ---
print_header() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}${BOLD}       FreeFlow Auto Script VPN — All In One        ${NC}${CYAN}║${NC}"
    echo -e "${CYAN}║${NC}        ${PURPLE}github.com/${REPO_OWNER}/${REPO_NAME}${NC}        ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_line() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_section() {
    echo ""
    print_line
    echo -e " ${BOLD}${WHITE}$1${NC}"
    print_line
}

msg_ok() {
    echo -e " ${OK} $1"
}

msg_fail() {
    echo -e " ${FAIL} $1"
}

msg_warn() {
    echo -e " ${WARN} $1"
}

msg_info() {
    echo -e " ${INFO} $1"
}

# --- OS Detection ---
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="${ID}"
        OS_VERSION="${VERSION_ID}"
        OS_PRETTY="${PRETTY_NAME}"
    elif [[ -f /etc/lsb-release ]]; then
        . /etc/lsb-release
        OS_NAME="${DISTRIB_ID,,}"
        OS_VERSION="${DISTRIB_RELEASE}"
        OS_PRETTY="${DISTRIB_DESCRIPTION}"
    else
        OS_NAME="unknown"
        OS_VERSION="unknown"
        OS_PRETTY="Unknown OS"
    fi
    export OS_NAME OS_VERSION OS_PRETTY
}

check_os_support() {
    detect_os
    case "${OS_NAME}" in
        ubuntu)
            local major="${OS_VERSION%%.*}"
            if [[ "$major" -ge 18 ]]; then
                return 0
            fi
            ;;
        debian)
            if [[ "${OS_VERSION}" -ge 9 ]] 2>/dev/null; then
                return 0
            fi
            ;;
    esac
    msg_fail "Unsupported OS: ${OS_PRETTY}"
    msg_info "Supported: Ubuntu 18.04-26.04, Debian 9-13"
    return 1
}

# --- Root Check ---
check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        msg_fail "This script must be run as root"
        echo -e "  Run: ${YELLOW}sudo su${NC} or ${YELLOW}sudo bash $0${NC}"
        exit 1
    fi
}

# --- Architecture Check ---
check_arch() {
    ARCH=$(uname -m)
    case "${ARCH}" in
        x86_64|amd64) ARCH="64" ;;
        aarch64|arm64) ARCH="arm64-v8a" ;;
        armv7l) ARCH="armv7" ;;
        *)
            msg_fail "Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac
    export ARCH
}

# --- UUID Functions ---
generate_uuid() {
    cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '[:cntrl:]' || uuidgen 2>/dev/null || openssl rand -hex 16 | sed 's/^\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\)/\1-\2-\3-\4-\5/'
}

custom_uuid_from_name() {
    local name="$1"
    # Generate a deterministic UUID v5-like from a name using namespace
    echo -n "${name}" | md5sum | sed 's/^\(.\{8\}\)\(.\{4\}\)\(.\{4\}\)\(.\{4\}\)\(.\{12\}\).*/\1-\2-\3-\4-\5/'
}

prompt_uuid() {
    local uuid
    echo ""
    read -rp " Custom UUID name? (leave empty for random): " custom_name
    if [[ -n "${custom_name}" ]]; then
        uuid=$(custom_uuid_from_name "${custom_name}")
        msg_info "Custom UUID generated from '${custom_name}': ${uuid}"
    else
        uuid=$(generate_uuid)
        msg_info "Random UUID generated: ${uuid}"
    fi
    echo "${uuid}"
}

# --- Network Helpers ---
get_server_ip() {
    local ip
    ip=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 ip.sb 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null)
    if [[ -z "${ip}" ]]; then
        ip=$(hostname -I | awk '{print $1}')
    fi
    echo "${ip}"
}

get_domain() {
    if [[ -f "${CONFIG_DIR}/domain" ]]; then
        cat "${CONFIG_DIR}/domain"
    else
        echo ""
    fi
}

# --- Service Helpers ---
restart_service() {
    local service="$1"
    systemctl daemon-reload
    systemctl restart "${service}" 2>/dev/null
    if systemctl is-active --quiet "${service}"; then
        msg_ok "${service} restarted"
    else
        msg_fail "${service} failed to restart"
        return 1
    fi
}

enable_service() {
    local service="$1"
    systemctl daemon-reload
    systemctl enable "${service}" 2>/dev/null
    systemctl start "${service}" 2>/dev/null
}

# --- Directory Setup ---
setup_directories() {
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${USER_DB}/vless/active"
    mkdir -p "${USER_DB}/vless/expired"
    mkdir -p "${USER_DB}/vmess/active"
    mkdir -p "${USER_DB}/vmess/expired"
    mkdir -p "${USER_DB}/trojan/active"
    mkdir -p "${USER_DB}/trojan/expired"
    mkdir -p "${USER_DB}/ssh/active"
    mkdir -p "${USER_DB}/ssh/expired"
    mkdir -p "${DATA_DIR}/usage"
    mkdir -p "${DATA_DIR}/backup"
    mkdir -p "${LOG_DIR}"
    mkdir -p /etc/xray
    mkdir -p /usr/local/share/xray
}

# --- Date/Time Helpers ---
get_expiry_date() {
    local days="$1"
    date -d "+${days} days" +"%Y-%m-%d"
}

is_expired() {
    local expiry_date="$1"
    local today
    today=$(date +"%Y-%m-%d")
    [[ "${today}" > "${expiry_date}" ]]
}

# --- Confirmation Prompt ---
confirm() {
    local msg="${1:-Continue?}"
    read -rp " ${msg} [y/N]: " response
    case "${response}" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# --- Version Tracking ---
get_installed_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        cat "${VERSION_FILE}"
    else
        echo "0.0.0"
    fi
}

set_version() {
    echo "$1" > "${VERSION_FILE}"
}
