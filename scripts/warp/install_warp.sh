#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WARP Cloudflare Module (Install/Uninstall)
# Uses fscarmen/warp WireProxy → SOCKS5 proxy on 127.0.0.1:40000
# Xray routes selected domains through the SOCKS outbound.
# Proven architecture from hamid-gh98/x-ui-scripts & JinGGoVPN.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

WARP_CONFIG="${CONFIG_DIR}/warp"
WARP_SOCKS_PORT="40000"
WARP_SOCKS_ADDR="127.0.0.1"

# --- Install fscarmen/warp script (the 'warp' command) ---
install_warp_script() {
    if [[ -x /usr/bin/warp || -x /etc/wireguard/menu.sh ]]; then
        msg_ok "warp command already installed"
        return 0
    fi

    msg_info "Installing fscarmen/warp..."
    mkdir -p /etc/wireguard

    if wget -q -N -P /etc/wireguard \
       "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" 2>/dev/null || \
       curl -sL -o /etc/wireguard/menu.sh \
       "https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh" 2>/dev/null; then
        chmod +x /etc/wireguard/menu.sh
        ln -sf /etc/wireguard/menu.sh /usr/bin/warp
        msg_ok "warp command installed"
    else
        msg_fail "Could not download fscarmen/warp script"
        return 1
    fi
}

# --- Install WireProxy (WARP SOCKS5) via fscarmen/warp ---
install_wireproxy() {
    # Check if wireproxy is already running
    if command -v wireproxy &>/dev/null && ss -nltp 2>/dev/null | grep -q wireproxy; then
        local existing_port
        existing_port=$(ss -nltp 2>/dev/null | grep wireproxy | awk '{print $(NF-2)}' | head -1 | cut -d: -f2)
        WARP_SOCKS_PORT="${existing_port:-40000}"
        msg_ok "WireProxy already running on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
        return 0
    fi

    msg_info "Installing WireProxy (WARP SOCKS5 proxy)..."

    # fscarmen/warp interactive menu: w = WireProxy, then select account type and port
    # Input: 1 (WARP free account), 1 (default config), port, 1 (confirm)
    if ! warp w <<< $'1\n1\n'"${WARP_SOCKS_PORT}"$'\n1\n' 2>&1; then
        msg_warn "warp command returned non-zero — checking if wireproxy started anyway..."
    fi

    sleep 3

    # Verify wireproxy is running
    if command -v wireproxy &>/dev/null && ss -nltp 2>/dev/null | grep -q wireproxy; then
        local running_port
        running_port=$(ss -nltp 2>/dev/null | grep wireproxy | awk '{print $(NF-2)}' | head -1 | cut -d: -f2)
        WARP_SOCKS_PORT="${running_port:-40000}"
        msg_ok "WireProxy running on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
        return 0
    fi

    # WireProxy might not be running yet — try starting it
    if systemctl start wireproxy 2>/dev/null; then
        sleep 2
        if ss -nltp 2>/dev/null | grep -q wireproxy; then
            msg_ok "WireProxy started on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
            return 0
        fi
    fi

    msg_fail "WireProxy failed to start"
    msg_info "Try manually: warp w"
    return 1
}

# --- Configure Xray SOCKS outbound to WireProxy ---
configure_xray_warp() {
    msg_info "Configuring Xray WARP SOCKS5 outbound..."

    # Remove any existing WARP outbounds (both old wireguard and socks types)
    local tmp_config
    tmp_config=$(mktemp)
    jq '.outbounds = [.outbounds[] | select(.tag != "warp" and .tag != "warp-socks5")]' \
        "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null

    if [[ ! -s "${tmp_config}" ]]; then
        rm -f "${tmp_config}"
        msg_fail "Could not read Xray config"
        return 1
    fi

    # Add SOCKS5 outbound pointing to WireProxy + freedom outbound for IPv4
    jq --arg addr "${WARP_SOCKS_ADDR}" \
       --argjson port "${WARP_SOCKS_PORT}" \
    '
        .outbounds += [
            {
                "tag": "warp-socks5",
                "protocol": "socks",
                "settings": {
                    "servers": [{
                        "address": $addr,
                        "port": $port
                    }]
                }
            },
            {
                "tag": "warp",
                "protocol": "freedom",
                "proxySettings": {
                    "tag": "warp-socks5"
                },
                "settings": {
                    "domainStrategy": "UseIPv4"
                }
            }
        ]
    ' "${tmp_config}" > "${tmp_config}.new"

    if [[ -s "${tmp_config}.new" ]]; then
        mv "${tmp_config}.new" "${XRAY_CONFIG}"
        rm -f "${tmp_config}"
    else
        rm -f "${tmp_config}" "${tmp_config}.new"
        msg_fail "Could not add WARP outbound to Xray config"
        return 1
    fi

    # Ensure domainStrategy is set in routing
    tmp_config=$(mktemp)
    jq '.routing.domainStrategy = "IPOnDemand"' "${XRAY_CONFIG}" > "${tmp_config}"
    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
    else
        rm -f "${tmp_config}"
    fi

    restart_service xray
    msg_ok "Xray WARP outbound configured (SOCKS5 → WireProxy)"
}

# --- Main install function ---
install_warp() {
    print_section "Installing Cloudflare WARP"

    msg_info "WARP bypasses domains that cannot pass through the VPS"
    msg_info "Traffic routes: Xray → SOCKS5 → WireProxy → Cloudflare WARP"
    echo ""

    # Step 1: Install fscarmen/warp script
    if ! install_warp_script; then
        return 1
    fi

    # Step 2: Install WireProxy (SOCKS5 proxy)
    if ! install_wireproxy; then
        return 1
    fi

    # Step 3: Configure Xray SOCKS outbound
    if ! configure_xray_warp; then
        return 1
    fi

    # Mark as installed
    mkdir -p "${CONFIG_DIR}/modules" "${WARP_CONFIG}"
    touch "${CONFIG_DIR}/modules/warp_installed"
    echo "wireproxy-socks5" > "${WARP_CONFIG}/method"
    echo "${WARP_SOCKS_PORT}" > "${WARP_CONFIG}/port"

    msg_ok "WARP installed successfully"
    msg_info "Method: WireProxy SOCKS5 on ${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
    msg_info "Add domains to bypass via: freeflow → WARP menu → Add Domain"
}

# --- Add domain routing through WARP ---
add_warp_route() {
    print_section "WARP Domain Routing"

    echo -e " Add domains to route through WARP (bypass VPS)"
    echo -e " Format: domain name (e.g. google.com, netflix.com)"
    echo -e " Enter domains one per line, empty line to finish:"
    echo ""

    local domains=()
    while true; do
        read -rp " Domain: " domain
        [[ -z "${domain}" ]] && break
        domains+=("${domain}")
    done

    if [[ ${#domains[@]} -eq 0 ]]; then
        msg_info "No domains added"
        return 0
    fi

    # Save domains to config
    mkdir -p "${WARP_CONFIG}"
    for d in "${domains[@]}"; do
        echo "${d}" >> "${WARP_CONFIG}/domains"
    done

    # Sort and deduplicate
    sort -u "${WARP_CONFIG}/domains" -o "${WARP_CONFIG}/domains"

    # Build domain list with "domain:" prefix for proper subdomain matching
    local domain_arr
    domain_arr=$(while IFS= read -r d; do
        [[ -z "${d}" ]] && continue
        echo "\"domain:${d}\""
    done < "${WARP_CONFIG}/domains" | paste -sd,)

    local domain_json="[${domain_arr}]"

    # Update Xray routing: remove old WARP rules, prepend new one
    local tmp_config
    tmp_config=$(mktemp)

    jq --argjson domains "${domain_json}" '
        .routing.rules = [{
            "type": "field",
            "domain": $domains,
            "outboundTag": "warp"
        }] + [.routing.rules[] | select(.outboundTag != "warp")]
    ' "${XRAY_CONFIG}" > "${tmp_config}"

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
        msg_ok "WARP routing updated for ${#domains[@]} domain(s)"
    else
        rm -f "${tmp_config}"
        msg_fail "Could not update routing rules"
    fi
}

# --- Delete a WARP route ---
delete_warp_route() {
    print_section "Remove WARP Domain Route"

    if [[ ! -f "${WARP_CONFIG}/domains" || ! -s "${WARP_CONFIG}/domains" ]]; then
        msg_info "No domains configured"
        return 0
    fi

    echo ""
    cat -n "${WARP_CONFIG}/domains"
    echo ""

    read -rp " Enter line number to remove (0 = cancel): " line_num

    if [[ ! "${line_num}" =~ ^[0-9]+$ ]]; then
        msg_fail "Invalid input"
        return 1
    fi
    [[ "${line_num}" -eq 0 ]] && return 0

    local total
    total=$(wc -l < "${WARP_CONFIG}/domains")
    if [[ "${line_num}" -gt "${total}" || "${line_num}" -lt 1 ]]; then
        msg_fail "Invalid line number (1-${total})"
        return 1
    fi

    local removed
    removed=$(sed -n "${line_num}p" "${WARP_CONFIG}/domains")
    sed -i "${line_num}d" "${WARP_CONFIG}/domains"
    sort -u "${WARP_CONFIG}/domains" -o "${WARP_CONFIG}/domains"

    # Rebuild Xray routing rules from remaining domains
    if [[ -s "${WARP_CONFIG}/domains" ]]; then
        local domain_arr
        domain_arr=$(while IFS= read -r d; do
            [[ -z "${d}" ]] && continue
            echo "\"domain:${d}\""
        done < "${WARP_CONFIG}/domains" | paste -sd,)

        local domain_json="[${domain_arr}]"

        local tmp_config
        tmp_config=$(mktemp)
        jq --argjson domains "${domain_json}" '
            .routing.rules = [{
                "type": "field",
                "domain": $domains,
                "outboundTag": "warp"
            }] + [.routing.rules[] | select(.outboundTag != "warp")]
        ' "${XRAY_CONFIG}" > "${tmp_config}"

        if [[ -s "${tmp_config}" ]]; then
            mv "${tmp_config}" "${XRAY_CONFIG}"
            restart_service xray
            msg_ok "Removed '${removed}' — routing updated"
        else
            rm -f "${tmp_config}"
        fi
    else
        # No more domains — remove WARP routing rule
        local tmp_config
        tmp_config=$(mktemp)
        jq '.routing.rules = [.routing.rules[] | select(.outboundTag != "warp")]' \
            "${XRAY_CONFIG}" > "${tmp_config}"
        if [[ -s "${tmp_config}" ]]; then
            mv "${tmp_config}" "${XRAY_CONFIG}"
        else
            rm -f "${tmp_config}"
        fi
        restart_service xray
        msg_ok "Removed '${removed}' — all WARP routes cleared"
    fi
}

# --- List WARP routes ---
list_warp_routes() {
    print_section "WARP Routed Domains"

    if [[ -f "${WARP_CONFIG}/domains" && -s "${WARP_CONFIG}/domains" ]]; then
        local count
        count=$(wc -l < "${WARP_CONFIG}/domains")
        echo -e " Total: ${count} domain(s)"
        echo ""
        cat -n "${WARP_CONFIG}/domains"
    else
        msg_info "No domains configured for WARP routing"
    fi
}

# --- Uninstall WARP ---
uninstall_warp() {
    print_section "Uninstalling Cloudflare WARP"

    if ! confirm "Remove WARP completely?"; then
        return 1
    fi

    # Remove WARP outbounds and routing rules from Xray config
    local tmp_config
    tmp_config=$(mktemp)
    jq '
        .outbounds = [.outbounds[] | select(.tag != "warp" and .tag != "warp-socks5")] |
        .routing.rules = [.routing.rules[] | select(.outboundTag != "warp")]
    ' "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    # Stop and disable wireproxy
    systemctl stop wireproxy 2>/dev/null
    systemctl disable wireproxy 2>/dev/null

    # Uninstall via fscarmen/warp if available
    if [[ -x /usr/bin/warp ]]; then
        warp u <<< $'y\n' 2>/dev/null || true
    fi

    # Clean up
    rm -f /usr/bin/warp
    rm -rf /etc/wireguard
    rm -rf "${WARP_CONFIG}"
    rm -f "${CONFIG_DIR}/modules/warp_installed"

    msg_ok "WARP removed"
}

# --- Check WARP status ---
check_warp_status() {
    if [[ ! -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
        echo "not_installed"
        return
    fi

    # Check if wireproxy is running and Xray has SOCKS outbound
    if ss -nltp 2>/dev/null | grep -q wireproxy && \
       jq -e '.outbounds[] | select(.tag == "warp-socks5" and .protocol == "socks")' "${XRAY_CONFIG}" &>/dev/null; then
        echo "active"
    else
        echo "configured"
    fi
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        uninstall) uninstall_warp ;;
        route) add_warp_route ;;
        delete-route) delete_warp_route ;;
        list) list_warp_routes ;;
        status) check_warp_status ;;
        *) install_warp ;;
    esac
fi
