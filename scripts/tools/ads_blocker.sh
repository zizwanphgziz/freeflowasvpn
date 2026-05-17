#!/bin/bash
# ============================================================
# FreeFlow ASVPN - DNS-Level Ads Blocker (dnsmasq)
# Uses dnsmasq for O(1) DNS lookup instead of /etc/hosts O(n)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

ADS_CONF="/etc/dnsmasq.d/freeflow-ads.conf"
ADS_MARKER="${CONFIG_DIR}/modules/ads_blocker_installed"

install_ads_blocker() {
    print_section "Installing Ads Blocker (dnsmasq)"

    # Install dnsmasq
    apt-get install -y dnsmasq > /dev/null 2>&1
    if ! command -v dnsmasq &>/dev/null; then
        msg_fail "dnsmasq installation failed"
        return 1
    fi

    msg_info "Downloading ad-blocking list..."

    local tmp_hosts
    tmp_hosts=$(mktemp)
    wget -qO "${tmp_hosts}" "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" 2>/dev/null

    if [[ ! -s "${tmp_hosts}" ]]; then
        msg_fail "Failed to download ad-blocking hosts"
        rm -f "${tmp_hosts}"
        return 1
    fi

    # Convert hosts format to dnsmasq format
    mkdir -p /etc/dnsmasq.d
    grep "^0.0.0.0" "${tmp_hosts}" | grep -v "0.0.0.0 0.0.0.0" \
        | awk '{print "address=/"$2"/0.0.0.0"}' \
        > "${ADS_CONF}"
    rm -f "${tmp_hosts}"

    local count
    count=$(wc -l < "${ADS_CONF}")

    # Clean up old /etc/hosts entries if present from previous version
    if grep -q "# FreeFlow Ads Blocker" /etc/hosts 2>/dev/null; then
        sed -i '/# FreeFlow Ads Blocker/,/# FreeFlow Ads Blocker — End/d' /etc/hosts
        msg_info "Cleaned up old /etc/hosts ad entries"
    fi

    systemctl enable dnsmasq 2>/dev/null
    systemctl restart dnsmasq

    mkdir -p "${CONFIG_DIR}/modules"
    touch "${ADS_MARKER}"

    msg_ok "Ads blocker installed via dnsmasq (${count} domains blocked)"
}

uninstall_ads_blocker() {
    print_section "Uninstalling Ads Blocker"

    if [[ ! -f "${ADS_MARKER}" ]]; then
        msg_warn "Ads blocker is not installed"
        return 1
    fi

    rm -f "${ADS_CONF}"
    systemctl restart dnsmasq 2>/dev/null

    # Also clean /etc/hosts if old entries exist
    if grep -q "# FreeFlow Ads Blocker" /etc/hosts 2>/dev/null; then
        sed -i '/# FreeFlow Ads Blocker/,/# FreeFlow Ads Blocker — End/d' /etc/hosts
    fi

    rm -f "${ADS_MARKER}"
    msg_ok "Ads blocker removed"
}

update_ads_blocker() {
    if [[ ! -f "${ADS_MARKER}" ]]; then
        msg_warn "Ads blocker is not installed"
        return 1
    fi

    rm -f "${ADS_CONF}"
    install_ads_blocker
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        install) install_ads_blocker ;;
        uninstall) uninstall_ads_blocker ;;
        update) update_ads_blocker ;;
        *) echo "Usage: $0 {install|uninstall|update}" ;;
    esac
fi
