#!/bin/bash
# ============================================================
#  FreeFlow Auto Script VPN — All In One
#  https://github.com/zizwanphgziz/freeflowasvpn
# ============================================================
# Supported: Ubuntu 18.04-26.04, Debian 9-13
# Architecture: Nginx (reverse proxy) + Xray Core
# Protocols: VLESS, VMESS, Trojan (WS/gRPC/XTLS Reality)
# ============================================================

REPO_OWNER="zizwanphgziz"
REPO_NAME="freeflowasvpn"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
REPO_BRANCH="init-branch"
INSTALL_DIR="/usr/local/lib/freeflow"
VERSION="2.1.0"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║     FreeFlow Auto Script VPN — All In One            ║"
echo "║     Version: ${VERSION}                                   ║"
echo "║     VLESS · VMESS · Trojan · SSH WS                  ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# --- Root Check ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e " ${RED}[FAIL]${NC} This script must be run as root"
    exit 1
fi

# --- OS Check ---
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS_NAME="${ID}"
    OS_VERSION="${VERSION_ID}"
else
    echo -e " ${RED}[FAIL]${NC} Cannot detect OS"
    exit 1
fi

case "${OS_NAME}" in
    ubuntu|debian) ;;
    *)
        echo -e " ${RED}[FAIL]${NC} Unsupported OS: ${OS_NAME}"
        echo -e " ${BLUE}[INFO]${NC} Supported: Ubuntu 18.04-26.04, Debian 9-13"
        exit 1
        ;;
esac

echo -e " ${GREEN}[OK]${NC} OS: ${PRETTY_NAME}"

# --- Check if already installed ---
if [[ -f "${INSTALL_DIR}/scripts/core/common.sh" ]]; then
    echo -e " ${YELLOW}[WARN]${NC} FreeFlow is already installed"
    echo ""
    echo -e "  ${GREEN}1${NC}. Reinstall / Update"
    echo -e "  ${GREEN}2${NC}. Open Menu"
    echo -e "  ${GREEN}3${NC}. Uninstall"
    echo -e "  ${GREEN}0${NC}. Exit"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1) ;;
        2) exec bash "${INSTALL_DIR}/scripts/menu/menu.sh" ;;
        3)
            echo -e " ${RED}Uninstalling...${NC}"
            systemctl stop xray nginx ssh-ws freeflow-bot 2>/dev/null
            systemctl disable xray nginx ssh-ws freeflow-bot 2>/dev/null
            rm -rf "${INSTALL_DIR}" /etc/freeflow
            rm -f /usr/local/bin/freeflow /usr/local/bin/menu
            echo -e " ${GREEN}[OK]${NC} Uninstalled"
            exit 0
            ;;
        0) exit 0 ;;
    esac
fi

# === ONLY PROMPT: Domain ===
echo ""
echo -e " ${BOLD}Enter your domain (must point to this server's IP)${NC}"
echo -e " Server IP: $(curl -s4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')"
echo ""
read -rp " Domain: " domain

if [[ -z "${domain}" ]]; then
    echo -e " ${RED}[FAIL]${NC} Domain is required"
    exit 1
fi

echo -e " ${GREEN}[OK]${NC} Domain: ${domain}"

# === AUTO INSTALL EVERYTHING BELOW — NO MORE PROMPTS ===

# --- Download Scripts ---
echo ""
echo -e " ${BLUE}[INFO]${NC} Downloading scripts..."

apt-get update -y > /dev/null 2>&1
apt-get install -y wget curl tar > /dev/null 2>&1

mkdir -p "${INSTALL_DIR}"
cd /tmp || exit 1

if wget -q "${REPO_URL}/archive/refs/heads/${REPO_BRANCH}.tar.gz" -O freeflow.tar.gz; then
    tar xzf freeflow.tar.gz
    mkdir -p "${INSTALL_DIR}/scripts"
    cp -rf "${REPO_NAME}-${REPO_BRANCH}/scripts/"* "${INSTALL_DIR}/scripts/"
    cp -f "${REPO_NAME}-${REPO_BRANCH}/setup.sh" "${INSTALL_DIR}/setup.sh" 2>/dev/null
    rm -rf "${REPO_NAME}-${REPO_BRANCH}" freeflow.tar.gz
    echo -e " ${GREEN}[OK]${NC} Scripts downloaded"
else
    echo -e " ${RED}[FAIL]${NC} Download failed"
    exit 1
fi

find "${INSTALL_DIR}/scripts" -name "*.sh" -exec chmod +x {} \;

# Source common functions
source "${INSTALL_DIR}/scripts/core/common.sh"

# --- Setup Directories ---
setup_directories
set_version "${VERSION}"
echo "${domain}" > "${CONFIG_DIR}/domain"

# --- Install Dependencies ---
source "${INSTALL_DIR}/scripts/core/dependencies.sh"
install_all_dependencies

# --- Install Xray (auto — no prompts) ---
source "${INSTALL_DIR}/scripts/xray/install_xray.sh"
install_xray_core
generate_xray_config

# --- Install Nginx (auto — no prompts) ---
source "${INSTALL_DIR}/scripts/nginx/install_nginx.sh"
install_nginx_full

# --- Setup Crons ---
source "${INSTALL_DIR}/scripts/user/usage_tracker.sh"
setup_usage_cron

# Expiry checker
if ! crontab -l 2>/dev/null | grep -q "manage_user.sh check-expiry"; then
    (crontab -l 2>/dev/null; echo "*/30 * * * * /bin/bash ${INSTALL_DIR}/scripts/user/manage_user.sh check-expiry") | crontab -
fi

# Auto-update
source "${INSTALL_DIR}/scripts/update/auto_update.sh"
if ! crontab -l 2>/dev/null | grep -q "auto_update.sh"; then
    (crontab -l 2>/dev/null; echo "0 4 * * * /bin/bash ${INSTALL_DIR}/scripts/update/auto_update.sh auto >> /var/log/freeflow/update.log 2>&1") | crontab -
fi

# Auto-clear log
if ! crontab -l 2>/dev/null | grep -q "auto_clear_log.sh"; then
    (crontab -l 2>/dev/null; echo "0 3 * * * /bin/bash ${INSTALL_DIR}/scripts/tools/auto_clear_log.sh clear >> /var/log/freeflow/autoclear.log 2>&1") | crontab -
fi
mkdir -p "${CONFIG_DIR}/modules"
touch "${CONFIG_DIR}/modules/auto_clear_log"

# Auto-reboot at 5 AM
if ! grep -q '/sbin/reboot' /etc/crontab 2>/dev/null; then
    echo "0 5 * * * root /sbin/reboot" >> /etc/crontab
    systemctl restart cron 2>/dev/null
fi

# --- Create Menu Command ---
cp -f "${INSTALL_DIR}/scripts/menu/menu.sh" /usr/local/bin/freeflow
chmod +x /usr/local/bin/freeflow
ln -sf /usr/local/bin/freeflow /usr/local/bin/menu 2>/dev/null

echo 'clear ; freeflow' > /root/.profile 2>/dev/null

# --- Done ---
clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║   FreeFlow ASVPN — Installation Complete!            ║"
echo "║   Version: ${VERSION}                                     ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e " ${GREEN}[OK]${NC} All services installed and running"
echo ""
echo -e " ${BOLD}Commands${NC}"
echo -e "  ${GREEN}freeflow${NC} or ${GREEN}menu${NC} — Open main menu"
echo ""
echo -e " ${YELLOW}Reboot your VPS to complete setup${NC}"
echo ""
