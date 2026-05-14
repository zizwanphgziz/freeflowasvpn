#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WARP Cloudflare Module (Install/Uninstall)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

WARP_CONFIG="${CONFIG_DIR}/warp"

install_warp() {
    print_section "Installing Cloudflare WARP"

    msg_info "WARP bypasses domains that cannot pass through the VPS"
    msg_info "Traffic is routed via Cloudflare's network instead"
    echo ""

    # Install WARP client
    detect_os

    if [[ "${OS_NAME}" == "ubuntu" ]] || [[ "${OS_NAME}" == "debian" ]]; then
        # Add Cloudflare GPG key and repo
        curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg

        local codename
        if [[ "${OS_NAME}" == "ubuntu" ]]; then
            codename=$(lsb_release -cs 2>/dev/null || echo "focal")
        else
            codename=$(lsb_release -cs 2>/dev/null || echo "bullseye")
        fi

        echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ ${codename} main" > /etc/apt/sources.list.d/cloudflare-client.list

        apt-get update
        apt-get install -y cloudflare-warp

        if ! command -v warp-cli &>/dev/null; then
            msg_warn "Official WARP client not available for this OS version"
            msg_info "Falling back to WireGuard-based WARP setup..."
            install_warp_wireguard
            return $?
        fi
    else
        install_warp_wireguard
        return $?
    fi

    # Register and connect WARP
    msg_info "Registering WARP..."
    warp-cli registration new 2>/dev/null || warp-cli register 2>/dev/null

    # Set WARP mode to proxy (SOCKS5 on localhost)
    warp-cli mode proxy 2>/dev/null
    warp-cli proxy port 40000 2>/dev/null
    warp-cli connect 2>/dev/null

    # Save WARP config
    mkdir -p "${WARP_CONFIG}"
    echo "warp-cli" > "${WARP_CONFIG}/method"
    echo "40000" > "${WARP_CONFIG}/proxy_port"

    # Add WARP routing to Xray
    configure_xray_warp

    mkdir -p "${CONFIG_DIR}/modules"
    touch "${CONFIG_DIR}/modules/warp_installed"

    msg_ok "WARP installed and connected"
    msg_info "WARP SOCKS5 proxy: 127.0.0.1:40000"
    msg_info "Configure domains to bypass via: freeflow warp-route"
}

install_warp_wireguard() {
    msg_info "Installing WARP via WireGuard..."

    apt-get install -y wireguard-tools

    # Generate WireGuard WARP config
    # This uses Cloudflare's WARP endpoint
    local privkey
    privkey=$(wg genkey)
    local pubkey
    pubkey=$(echo "${privkey}" | wg pubkey)

    msg_info "Registering with Cloudflare WARP API..."

    local reg_response
    reg_response=$(curl -s -X POST "https://api.cloudflareclient.com/v0a2158/reg" \
        -H "Content-Type: application/json" \
        -d "{\"key\":\"${pubkey}\",\"install_id\":\"\",\"tos\":\"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",\"model\":\"Linux\",\"type\":\"Linux\"}")

    if echo "${reg_response}" | jq -e '.result.id' &>/dev/null; then
        local warp_endpoint="162.159.193.1:2408"
        local warp_pubkey
        warp_pubkey=$(echo "${reg_response}" | jq -r '.result.config.peers[0].public_key')
        local warp_ipv4
        warp_ipv4=$(echo "${reg_response}" | jq -r '.result.config.interface.addresses.v4')

        cat > /etc/wireguard/warp.conf <<WGEOF
[Interface]
PrivateKey = ${privkey}
Address = ${warp_ipv4}/32
DNS = 1.1.1.1
Table = off

[Peer]
PublicKey = ${warp_pubkey}
Endpoint = ${warp_endpoint}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
WGEOF

        chmod 600 /etc/wireguard/warp.conf

        # Start WARP WireGuard
        wg-quick up warp 2>/dev/null
        systemctl enable wg-quick@warp 2>/dev/null

        mkdir -p "${WARP_CONFIG}"
        echo "wireguard" > "${WARP_CONFIG}/method"

        msg_ok "WARP WireGuard tunnel established"
    else
        msg_fail "WARP registration failed"
        msg_info "You can manually configure WARP later"
        return 1
    fi
}

configure_xray_warp() {
    msg_info "Configuring Xray WARP routing..."

    local proxy_port
    proxy_port=$(cat "${WARP_CONFIG}/proxy_port" 2>/dev/null || echo "40000")

    # Check if WARP outbound already exists in xray config
    if grep -q '"warp"' "${XRAY_CONFIG}" 2>/dev/null; then
        msg_info "WARP already configured in Xray"
        return 0
    fi

    # Add WARP outbound to xray config using jq
    local tmp_config
    tmp_config=$(mktemp)

    jq --arg port "${proxy_port}" '
        .outbounds += [{
            "protocol": "socks",
            "settings": {
                "servers": [{
                    "address": "127.0.0.1",
                    "port": ($port | tonumber)
                }]
            },
            "tag": "warp"
        }]
    ' "${XRAY_CONFIG}" > "${tmp_config}"

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
        msg_ok "Xray WARP outbound added"
    else
        rm -f "${tmp_config}"
        msg_warn "Could not update Xray config for WARP"
    fi
}

add_warp_route() {
    print_section "WARP Domain Routing"

    echo -e " Add domains to route through WARP (bypass VPS)"
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

    # Update Xray routing rules to send matching domains through WARP
    local domain_list
    domain_list=$(jq -R -s 'split("\n") | map(select(length > 0))' "${WARP_CONFIG}/domains")

    local tmp_config
    tmp_config=$(mktemp)

    jq --argjson domains "${domain_list}" '
        .routing.rules = [
            .routing.rules[] | select(.outboundTag != "warp" or .type != "field" or has("domain") | not)
        ] + [{
            "type": "field",
            "domain": $domains,
            "outboundTag": "warp"
        }]
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

list_warp_routes() {
    print_section "WARP Routed Domains"

    if [[ -f "${WARP_CONFIG}/domains" ]]; then
        local count
        count=$(wc -l < "${WARP_CONFIG}/domains")
        echo -e " Total: ${count} domain(s)"
        echo ""
        cat -n "${WARP_CONFIG}/domains"
    else
        msg_info "No domains configured for WARP routing"
    fi
}

uninstall_warp() {
    print_section "Uninstalling Cloudflare WARP"

    if ! confirm "Remove WARP completely?"; then
        return 1
    fi

    local method
    method=$(cat "${WARP_CONFIG}/method" 2>/dev/null || echo "unknown")

    case "${method}" in
        warp-cli)
            warp-cli disconnect 2>/dev/null
            warp-cli registration delete 2>/dev/null
            apt-get remove -y cloudflare-warp 2>/dev/null
            ;;
        wireguard)
            wg-quick down warp 2>/dev/null
            systemctl disable wg-quick@warp 2>/dev/null
            rm -f /etc/wireguard/warp.conf
            ;;
    esac

    # Remove WARP outbound from Xray config
    local tmp_config
    tmp_config=$(mktemp)
    jq '
        .outbounds = [.outbounds[] | select(.tag != "warp")] |
        .routing.rules = [.routing.rules[] | select(.outboundTag != "warp")]
    ' "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null

    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
        restart_service xray
    else
        rm -f "${tmp_config}"
    fi

    rm -rf "${WARP_CONFIG}"
    rm -f "${CONFIG_DIR}/modules/warp_installed"

    msg_ok "WARP removed"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        uninstall) uninstall_warp ;;
        route) add_warp_route ;;
        list) list_warp_routes ;;
        *) install_warp ;;
    esac
fi
