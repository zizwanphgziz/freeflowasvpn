#!/bin/bash
# ============================================================
#  FreeFlow Auto Script VPN — All In One
#  https://github.com/zizwanphgziz/freeflowasvpn
# ============================================================
# Supported: Ubuntu 18.04+, Debian 9+
# Architecture: Nginx (reverse proxy) + Xray Core
# ============================================================

set -e

REPO_OWNER="zizwanphgziz"
REPO_NAME="freeflowasvpn"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"
REPO_BRANCH="init-branch"
REPO_RAW="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}"
INSTALL_DIR="/usr/local/lib/freeflow"
VERSION="1.0.0"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'

clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║     FreeFlow Auto Script VPN — All In One            ║"
echo "║     Version: ${VERSION}                                   ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# --- Root Check ---
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e " ${RED}[FAIL]${NC} This script must be run as root"
    echo -e "  Run: ${YELLOW}sudo su${NC} then re-run this script"
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
        echo -e " ${BLUE}[INFO]${NC} Supported: Ubuntu 18.04+, Debian 9+"
        exit 1
        ;;
esac

echo -e " ${GREEN}[OK]${NC} OS: ${PRETTY_NAME}"

# --- Check if already installed ---
if [[ -f "${INSTALL_DIR}/scripts/core/common.sh" ]]; then
    echo -e " ${YELLOW}[WARN]${NC} FreeFlow ASVPN is already installed"
    echo -e ""
    echo -e "  ${GREEN}1${NC}. Reinstall / Update"
    echo -e "  ${GREEN}2${NC}. Open Menu"
    echo -e "  ${GREEN}3${NC}. Uninstall"
    echo -e "  ${GREEN}0${NC}. Exit"
    echo ""
    read -rp " Choose: " choice
    case "${choice}" in
        1) ;; # Continue with installation
        2) exec bash "${INSTALL_DIR}/scripts/menu/menu.sh" ;;
        3)
            echo -e " ${RED}Uninstalling...${NC}"
            systemctl stop xray nginx ssh-ws freeflow-bot 2>/dev/null
            systemctl disable xray nginx ssh-ws freeflow-bot 2>/dev/null
            rm -rf "${INSTALL_DIR}"
            rm -rf /etc/freeflow
            rm -f /usr/local/bin/freeflow /usr/local/bin/menu
            echo -e " ${GREEN}[OK]${NC} Uninstalled"
            exit 0
            ;;
        0) exit 0 ;;
    esac
fi

# --- Download Scripts ---
echo ""
echo -e " ${BLUE}[INFO]${NC} Downloading FreeFlow ASVPN scripts..."

apt-get update -y > /dev/null 2>&1
apt-get install -y wget curl tar > /dev/null 2>&1

mkdir -p "${INSTALL_DIR}"
cd /tmp

if wget -q "${REPO_URL}/archive/refs/heads/${REPO_BRANCH}.tar.gz" -O freeflow.tar.gz; then
    tar xzf freeflow.tar.gz
    cp -rf "${REPO_NAME}-${REPO_BRANCH}/scripts/"* "${INSTALL_DIR}/scripts/" 2>/dev/null || {
        mkdir -p "${INSTALL_DIR}/scripts"
        cp -rf "${REPO_NAME}-${REPO_BRANCH}/scripts/"* "${INSTALL_DIR}/scripts/"
    }
    cp -f "${REPO_NAME}-${REPO_BRANCH}/setup.sh" "${INSTALL_DIR}/setup.sh" 2>/dev/null
    rm -rf "${REPO_NAME}-${REPO_BRANCH}" freeflow.tar.gz
    echo -e " ${GREEN}[OK]${NC} Scripts downloaded"
else
    echo -e " ${RED}[FAIL]${NC} Download failed. Check internet connection."
    exit 1
fi

# Make scripts executable
chmod +x "${INSTALL_DIR}/scripts/"*/*.sh 2>/dev/null
chmod +x "${INSTALL_DIR}/setup.sh" 2>/dev/null

# Source common functions
source "${INSTALL_DIR}/scripts/core/common.sh"

# --- Setup Directories ---
setup_directories
set_version "${VERSION}"
echo -e " ${GREEN}[OK]${NC} Directories created"

# --- Domain Setup ---
echo ""
echo -e " ${BOLD}${WHITE}━━━ Domain Configuration ━━━${NC}"
echo ""
echo -e " Enter your domain (must point to this server's IP)"
echo -e " IP: $(get_server_ip)"
echo ""
read -rp " Domain: " domain

if [[ -z "${domain}" ]]; then
    echo -e " ${RED}[FAIL]${NC} Domain is required"
    exit 1
fi

echo "${domain}" > "${CONFIG_DIR}/domain"
echo -e " ${GREEN}[OK]${NC} Domain: ${domain}"

# --- Install Dependencies ---
source "${INSTALL_DIR}/scripts/core/dependencies.sh"
install_all_dependencies

# --- Install Xray ---
source "${INSTALL_DIR}/scripts/xray/install_xray.sh"
install_xray_core
generate_xray_config

# --- Install Nginx ---
source "${INSTALL_DIR}/scripts/nginx/install_nginx.sh"
install_nginx_full

# --- Optional: SSH WebSocket ---
echo ""
echo -e " ${BOLD}${WHITE}━━━ Optional Modules ━━━${NC}"
echo ""
read -rp " Install SSH WebSocket? [y/N]: " install_ssh
if [[ "${install_ssh}" =~ ^[yY] ]]; then
    source "${INSTALL_DIR}/scripts/ssh/install_ssh_ws.sh"
    install_ssh_ws
fi

# --- Optional: WARP ---
read -rp " Install Cloudflare WARP? [y/N]: " install_warp
if [[ "${install_warp}" =~ ^[yY] ]]; then
    source "${INSTALL_DIR}/scripts/warp/install_warp.sh"
    install_warp
fi

# --- Optional: Telegram Bot ---
read -rp " Setup Telegram Bot? [y/N]: " install_bot
if [[ "${install_bot}" =~ ^[yY] ]]; then
    source "${INSTALL_DIR}/scripts/telegram/setup_bot.sh"
    setup_telegram_bot
fi

# --- Setup Usage Tracking Cron ---
source "${INSTALL_DIR}/scripts/user/usage_tracker.sh"
setup_usage_cron

# --- Setup Expiry Check Cron ---
if ! crontab -l 2>/dev/null | grep -q "manage_user.sh check-expiry"; then
    (crontab -l 2>/dev/null; echo "*/30 * * * * /bin/bash ${INSTALL_DIR}/scripts/user/manage_user.sh check-expiry") | crontab -
fi

# --- Auto Update Settings ---
echo ""
read -rp " Enable auto-update? [Y/n]: " auto_update
if [[ ! "${auto_update}" =~ ^[nN] ]]; then
    source "${INSTALL_DIR}/scripts/update/auto_update.sh"
    (crontab -l 2>/dev/null; echo "0 4 * * * /bin/bash ${INSTALL_DIR}/scripts/update/auto_update.sh auto >> /var/log/freeflow/update.log 2>&1") | crontab -
    echo -e " ${GREEN}[OK]${NC} Auto-update enabled (daily at 4 AM)"
fi

# --- Auto Reboot ---
read -rp " Enable auto reboot at 5 AM? [Y/n]: " auto_reboot
if [[ ! "${auto_reboot}" =~ ^[nN] ]]; then
    sed -i '/\/sbin\/reboot/d' /etc/crontab
    echo "0 5 * * * root /sbin/reboot" >> /etc/crontab
    systemctl restart cron
    echo -e " ${GREEN}[OK]${NC} Auto reboot set to 5:00 AM daily"
fi

# --- Create Menu Command ---
cp -f "${INSTALL_DIR}/scripts/menu/menu.sh" /usr/local/bin/freeflow
chmod +x /usr/local/bin/freeflow
ln -sf /usr/local/bin/freeflow /usr/local/bin/menu 2>/dev/null

# Auto-show menu on login
echo 'clear ; freeflow' > /root/.profile 2>/dev/null

# --- Final Summary ---
clear
echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════════╗"
echo "║                                                      ║"
echo "║   FreeFlow ASVPN — Installation Complete!            ║"
echo "║                                                      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e " ${GREEN}[OK]${NC} All services installed and running"
echo ""
echo -e " ${BOLD}Service & Port Info${NC}"
echo -e " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Nginx             : 80, 443 (+ multiport)"
echo -e "  VLESS WS (TLS)    : 443, 8443, 2083, 2087"
echo -e "  VLESS WS (nonTLS) : 80, 8080, 8880, 2086"
echo -e "  VLESS HttpUpgrade : Same ports as above"
echo -e "  VLESS XHTTP       : Same ports as above"
if [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]]; then
    echo -e "  SSH WebSocket      : via Nginx /ssh path"
fi
echo ""
echo -e " ${BOLD}Commands${NC}"
echo -e " ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}freeflow${NC}  — Open main menu"
echo -e "  ${GREEN}menu${NC}      — Same as above"
echo ""
echo -e " ${YELLOW}Please reboot your VPS to complete setup${NC}"
echo ""
