#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WARP Cloudflare Module (Install/Uninstall)
# Self-contained: registers directly with Cloudflare API,
# downloads wireproxy from GitHub, creates SOCKS5 proxy on
# 127.0.0.1:40000, configures Xray outbound.
# Architecture from hamid-gh98/x-ui-scripts & JinGGoVPN.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

WARP_CONFIG="${CONFIG_DIR}/warp"
WARP_SOCKS_PORT="40000"
WARP_SOCKS_ADDR="127.0.0.1"
WIREPROXY_BIN="/usr/local/bin/wireproxy"
WIREPROXY_CONF="/etc/wireproxy.conf"

CF_API="https://api.cloudflareclient.com/v0a2223"
CF_CLIENT_VER="a-6.11-2223"

# --- Download wireproxy binary from GitHub ---
install_wireproxy_bin() {
    if [[ -x "${WIREPROXY_BIN}" ]]; then
        msg_ok "wireproxy binary already installed"
        return 0
    fi

    msg_info "Downloading wireproxy..."
    local arch
    arch=$(uname -m)
    local wp_arch
    case "${arch}" in
        x86_64|amd64) wp_arch="amd64" ;;
        aarch64|arm64) wp_arch="arm64" ;;
        armv7l) wp_arch="arm" ;;
        i686|i386) wp_arch="386" ;;
        *) msg_fail "Unsupported architecture: ${arch}"; return 1 ;;
    esac

    local wp_url="https://github.com/pufferffish/wireproxy/releases/latest/download/wireproxy_linux_${wp_arch}.tar.gz"

    local tmp_dir
    tmp_dir=$(mktemp -d)
    if wget -q -O "${tmp_dir}/wireproxy.tar.gz" "${wp_url}" 2>/dev/null || \
       curl -sL -o "${tmp_dir}/wireproxy.tar.gz" "${wp_url}" 2>/dev/null; then
        tar -xzf "${tmp_dir}/wireproxy.tar.gz" -C "${tmp_dir}" 2>/dev/null
        if [[ -f "${tmp_dir}/wireproxy" ]]; then
            mv "${tmp_dir}/wireproxy" "${WIREPROXY_BIN}"
            chmod +x "${WIREPROXY_BIN}"
            rm -rf "${tmp_dir}"
            msg_ok "wireproxy installed"
            return 0
        fi
    fi

    rm -rf "${tmp_dir}"
    msg_fail "Could not download wireproxy"
    return 1
}

# --- Register with Cloudflare WARP API directly ---
register_warp() {
    msg_info "Registering with Cloudflare WARP..."

    mkdir -p "${WARP_CONFIG}"

    # Generate a random key for registration
    local reg_key
    reg_key=$(openssl rand -base64 32)

    local reg_response
    local attempt
    for attempt in 1 2 3; do
        reg_response=$(curl -s -X POST "${CF_API}/reg" \
            -H "CF-Client-Version: ${CF_CLIENT_VER}" \
            -H "Content-Type: application/json" \
            -d '{
                "key": "'"${reg_key}"'",
                "install_id": "",
                "fcm_token": "",
                "tos": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'",
                "model": "PC",
                "serial_number": "",
                "locale": "en_US"
            }' 2>/dev/null)

        # Check if response has the config we need
        if echo "${reg_response}" | jq -e '.config.peers[0].public_key' &>/dev/null; then
            msg_ok "WARP registered (attempt ${attempt})"
            break
        fi

        if [[ "${attempt}" -lt 3 ]]; then
            msg_warn "Registration attempt ${attempt} failed — retrying in 3s..."
            sleep 3
        fi
    done

    # Extract WireGuard config from API response
    local private_key peer_pubkey endpoint address_v4 address_v6 client_id
    private_key=$(echo "${reg_response}" | jq -r '.key // empty')
    peer_pubkey=$(echo "${reg_response}" | jq -r '.config.peers[0].public_key // empty')
    endpoint=$(echo "${reg_response}" | jq -r '.config.peers[0].endpoint.host // empty')
    address_v4=$(echo "${reg_response}" | jq -r '.config.interface.addresses.v4 // empty')
    address_v6=$(echo "${reg_response}" | jq -r '.config.interface.addresses.v6 // empty')
    client_id=$(echo "${reg_response}" | jq -r '.config.client_id // empty')

    if [[ -z "${private_key}" || -z "${peer_pubkey}" ]]; then
        msg_fail "WARP registration failed — could not get keys"
        msg_info "API response: $(echo "${reg_response}" | jq -r '.errors // .message // "unknown error"' 2>/dev/null)"
        return 1
    fi

    # Decode client_id (base64) to reserved bytes
    local reserved=""
    if [[ -n "${client_id}" ]]; then
        reserved=$(echo "${client_id}" | base64 -d 2>/dev/null | od -An -tu1 | tr -s ' ' ',' | sed 's/^,//;s/,$//')
    fi

    # Save all values
    echo "${private_key}" > "${WARP_CONFIG}/private_key"
    echo "${peer_pubkey}" > "${WARP_CONFIG}/peer_pubkey"
    echo "${endpoint}" > "${WARP_CONFIG}/endpoint"
    echo "${address_v4}" > "${WARP_CONFIG}/address_v4"
    echo "${address_v6}" > "${WARP_CONFIG}/address_v6"
    echo "${reserved}" > "${WARP_CONFIG}/reserved"
    echo "${reg_response}" > "${WARP_CONFIG}/registration.json"

    chmod 600 "${WARP_CONFIG}/private_key" "${WARP_CONFIG}/registration.json"

    msg_ok "WARP keys obtained"
    msg_info "  Address IPv4: ${address_v4}"
    msg_info "  Address IPv6: ${address_v6}"
    msg_info "  Endpoint    : ${endpoint}"
}

# --- Create wireproxy config ---
create_wireproxy_config() {
    msg_info "Creating wireproxy config..."

    local private_key peer_pubkey endpoint address_v4 address_v6
    private_key=$(cat "${WARP_CONFIG}/private_key" 2>/dev/null)
    peer_pubkey=$(cat "${WARP_CONFIG}/peer_pubkey" 2>/dev/null)
    endpoint=$(cat "${WARP_CONFIG}/endpoint" 2>/dev/null)
    address_v4=$(cat "${WARP_CONFIG}/address_v4" 2>/dev/null)
    address_v6=$(cat "${WARP_CONFIG}/address_v6" 2>/dev/null)

    if [[ -z "${private_key}" || -z "${peer_pubkey}" ]]; then
        msg_fail "WARP keys not found — run install first"
        return 1
    fi

    # Default endpoint if missing
    [[ -z "${endpoint}" ]] && endpoint="engage.cloudflareclient.com:2408"

    # Build address line
    local wp_address="${address_v4}/32"
    [[ -n "${address_v6}" ]] && wp_address="${address_v4}/32, ${address_v6}/128"

    cat > "${WIREPROXY_CONF}" <<EOF
[Interface]
PrivateKey = ${private_key}
Address = ${wp_address}
DNS = 1.1.1.1
MTU = 1280

[Peer]
PublicKey = ${peer_pubkey}
Endpoint = ${endpoint}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 30

[Socks5]
BindAddress = ${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}
EOF

    chmod 600 "${WIREPROXY_CONF}"
    msg_ok "wireproxy config created"
    msg_info "  SOCKS5: ${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
}

# --- Create systemd service and start wireproxy ---
start_wireproxy_service() {
    msg_info "Starting wireproxy service..."

    cat > /etc/systemd/system/wireproxy.service <<EOF
[Unit]
Description=WireProxy WARP SOCKS5 Proxy
After=network.target

[Service]
Type=simple
ExecStart=${WIREPROXY_BIN} -c ${WIREPROXY_CONF}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable wireproxy 2>/dev/null
    systemctl restart wireproxy

    sleep 3

    if ss -nltp 2>/dev/null | grep -q wireproxy; then
        msg_ok "WireProxy running on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
        return 0
    fi

    msg_warn "wireproxy may not have started — checking status..."
    systemctl status wireproxy --no-pager 2>&1 | tail -5 || true

    sleep 3
    if ss -nltp 2>/dev/null | grep -q wireproxy; then
        msg_ok "WireProxy running on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
        return 0
    fi

    msg_fail "WireProxy failed to start"
    return 1
}

# --- Configure Xray SOCKS outbound to WireProxy ---
configure_xray_warp() {
    msg_info "Configuring Xray WARP SOCKS5 outbound..."

    local tmp_config
    tmp_config=$(mktemp)
    jq '.outbounds = [.outbounds[] | select(.tag != "warp" and .tag != "warp-socks5")]' \
        "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null

    if [[ ! -s "${tmp_config}" ]]; then
        rm -f "${tmp_config}"
        msg_fail "Could not read Xray config"
        return 1
    fi

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

    # Step 1: Download wireproxy binary
    if ! install_wireproxy_bin; then
        return 1
    fi

    # Step 2: Register with Cloudflare WARP API
    if ! register_warp; then
        return 1
    fi

    # Step 3: Create wireproxy config
    if ! create_wireproxy_config; then
        return 1
    fi

    # Step 4: Create systemd service and start wireproxy
    if ! start_wireproxy_service; then
        return 1
    fi

    # Step 5: Configure Xray SOCKS outbound
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

    mkdir -p "${WARP_CONFIG}"
    for d in "${domains[@]}"; do
        echo "${d}" >> "${WARP_CONFIG}/domains"
    done

    sort -u "${WARP_CONFIG}/domains" -o "${WARP_CONFIG}/domains"

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

    # Stop and remove wireproxy service
    systemctl stop wireproxy 2>/dev/null
    systemctl disable wireproxy 2>/dev/null
    rm -f /etc/systemd/system/wireproxy.service
    systemctl daemon-reload 2>/dev/null

    # Remove binaries and config
    rm -f "${WIREPROXY_BIN}"
    rm -f "${WIREPROXY_CONF}"
    rm -f /usr/local/bin/wgcf
    rm -f /usr/bin/warp
    rm -rf /etc/wireguard
    rm -rf "${WARP_CONFIG}"
    rm -f "${CONFIG_DIR}/modules/warp_installed"

    msg_ok "WARP removed (wireproxy + config)"
}

# --- Check WARP status ---
check_warp_status() {
    if [[ ! -f "${CONFIG_DIR}/modules/warp_installed" ]]; then
        echo "not_installed"
        return
    fi

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
