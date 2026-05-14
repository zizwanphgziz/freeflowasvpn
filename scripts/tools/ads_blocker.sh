#!/bin/bash
# ============================================================
# FreeFlow ASVPN - DNS-Level Ads Blocker
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

ADS_HOSTS="/etc/freeflow/ads_hosts"
ADS_MARKER="${CONFIG_DIR}/modules/ads_blocker_installed"

install_ads_blocker() {
    print_section "Installing Ads Blocker"

    msg_info "Downloading ad-blocking hosts list..."

    mkdir -p "$(dirname "${ADS_HOSTS}")"

    # Download popular hosts-based ad blocklist
    local tmp_hosts
    tmp_hosts=$(mktemp)
    wget -qO "${tmp_hosts}" "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" 2>/dev/null

    if [[ ! -s "${tmp_hosts}" ]]; then
        msg_fail "Failed to download ad-blocking hosts"
        rm -f "${tmp_hosts}"
        return 1
    fi

    # Filter to just the blocking entries
    grep "^0.0.0.0" "${tmp_hosts}" | grep -v "0.0.0.0 0.0.0.0" > "${ADS_HOSTS}"
    rm -f "${tmp_hosts}"

    local count
    count=$(wc -l < "${ADS_HOSTS}")
    msg_ok "Downloaded ${count} ad domains to block"

    # Backup original hosts
    cp /etc/hosts /etc/hosts.freeflow.bak 2>/dev/null

    # Add to /etc/hosts if not already added
    if ! grep -q "# FreeFlow Ads Blocker" /etc/hosts; then
        {
            echo ""
            echo "# FreeFlow Ads Blocker — Start"
            cat "${ADS_HOSTS}"
            echo "# FreeFlow Ads Blocker — End"
        } >> /etc/hosts
    fi

    mkdir -p "${CONFIG_DIR}/modules"
    touch "${ADS_MARKER}"

    msg_ok "Ads blocker installed (${count} domains blocked)"
}

uninstall_ads_blocker() {
    print_section "Uninstalling Ads Blocker"

    if [[ ! -f "${ADS_MARKER}" ]]; then
        msg_warn "Ads blocker is not installed"
        return 1
    fi

    # Remove ad-blocking entries from /etc/hosts
    sed -i '/# FreeFlow Ads Blocker — Start/,/# FreeFlow Ads Blocker — End/d' /etc/hosts

    rm -f "${ADS_HOSTS}" "${ADS_MARKER}"
    msg_ok "Ads blocker removed"
}

update_ads_blocker() {
    if [[ ! -f "${ADS_MARKER}" ]]; then
        msg_warn "Ads blocker is not installed"
        return 1
    fi

    # Remove old entries
    sed -i '/# FreeFlow Ads Blocker — Start/,/# FreeFlow Ads Blocker — End/d' /etc/hosts

    # Re-download and apply
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
