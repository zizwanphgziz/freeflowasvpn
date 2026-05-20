#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WARP Cloudflare Module (Install/Uninstall)
# Self-contained: downloads wireproxy + wgcf, registers WARP,
# creates SOCKS5 proxy on 127.0.0.1:40000, configures Xray.
# Architecture from hamid-gh98/x-ui-scripts & JinGGoVPN.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

WARP_CONFIG="${CONFIG_DIR}/warp"
WARP_SOCKS_PORT="40000"
WARP_SOCKS_ADDR="127.0.0.1"
WIREPROXY_BIN="/usr/local/bin/wireproxy"
WIREPROXY_CONF="/etc/wireproxy.conf"

# --- Download wireproxy binary from GitHub ---
install_wireproxy_bin() {
    if [[ -x "${WIREPROXY_BIN}" ]] && "${WIREPROXY_BIN}" --version &>/dev/null; then
        msg_ok "wireproxy binary already installed"
        return 0
    fi

    rm -f "${WIREPROXY_BIN}" 2>/dev/null

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

    # wireproxy repo was transferred from pufferffish to windtf
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

# --- Install wgcf binary ---
install_wgcf() {
    if command -v wgcf &>/dev/null && wgcf --help &>/dev/null; then
        msg_ok "wgcf already installed"
        return 0
    fi

    rm -f /usr/local/bin/wgcf 2>/dev/null

    msg_info "Downloading wgcf..."
    local arch
    arch=$(uname -m)
    local wgcf_arch
    case "${arch}" in
        x86_64|amd64) wgcf_arch="amd64" ;;
        aarch64|arm64) wgcf_arch="arm64" ;;
        armv7l) wgcf_arch="armv7" ;;
        *) msg_fail "Unsupported architecture: ${arch}"; return 1 ;;
    esac

    local wgcf_tag
    wgcf_tag=$(curl -sI "https://github.com/ViRb3/wgcf/releases/latest" \
               | grep -i '^location:' | sed 's|.*/tag/||;s/[[:space:]]//g')
    [[ -z "${wgcf_tag}" ]] && wgcf_tag="v2.2.30"

    local wgcf_ver="${wgcf_tag#v}"
    local wgcf_url="https://github.com/ViRb3/wgcf/releases/download/${wgcf_tag}/wgcf_${wgcf_ver}_linux_${wgcf_arch}"

    if wget -q -O /usr/local/bin/wgcf "${wgcf_url}" 2>/dev/null || \
       curl -sL -o /usr/local/bin/wgcf "${wgcf_url}" 2>/dev/null; then
        chmod +x /usr/local/bin/wgcf
        if ! wgcf --help &>/dev/null; then
            rm -f /usr/local/bin/wgcf
            msg_fail "Downloaded wgcf is not a valid binary"
            return 1
        fi
        msg_ok "wgcf ${wgcf_tag} installed"
    else
        msg_fail "Could not download wgcf"
        return 1
    fi
}

# --- Register WARP and generate WireGuard profile ---
register_warp() {
    msg_info "Registering with Cloudflare WARP..."

    mkdir -p "${WARP_CONFIG}"
    cd "${WARP_CONFIG}" || return 1

    rm -f "${WARP_CONFIG}/wgcf-account.toml" "${WARP_CONFIG}/wgcf-profile.conf"

    local attempt
    for attempt in 1 2 3; do
        wgcf register --accept-tos 2>&1 || true
        if [[ -f "${WARP_CONFIG}/wgcf-account.toml" ]]; then
            msg_ok "WARP account registered (attempt ${attempt})"
            break
        fi
        if [[ "${attempt}" -lt 3 ]]; then
            msg_warn "Registration attempt ${attempt} failed — retrying in 3s..."
            sleep 3
        fi
    done

    if [[ ! -f "${WARP_CONFIG}/wgcf-account.toml" ]]; then
        msg_fail "WARP registration failed after 3 attempts"
        return 1
    fi

    wgcf generate 2>&1 || true

    if [[ ! -f "${WARP_CONFIG}/wgcf-profile.conf" ]]; then
        msg_fail "Could not generate WireGuard profile"
        return 1
    fi
    msg_ok "WireGuard profile generated"
}

# --- Create wireproxy config from WireGuard profile ---
create_wireproxy_config() {
    msg_info "Creating wireproxy config..."

    local profile="${WARP_CONFIG}/wgcf-profile.conf"
    if [[ ! -f "${profile}" ]]; then
        msg_fail "WireGuard profile not found"
        return 1
    fi

    local private_key endpoint peer_pubkey
    private_key=$(grep "^PrivateKey" "${profile}" | awk '{print $3}')
    endpoint=$(grep "^Endpoint" "${profile}" | awk '{print $3}')
    peer_pubkey=$(grep "^PublicKey" "${profile}" | awk '{print $3}')

    # Parse address line — may have both v4 and v6 comma-separated
    local addr_line
    addr_line=$(grep "^Address" "${profile}" | head -1 | sed 's/^Address *= *//')
    local address_v4 address_v6
    address_v4=$(echo "${addr_line}" | cut -d',' -f1 | tr -d ' ')
    address_v6=$(echo "${addr_line}" | cut -d',' -f2 | tr -d ' ')
    [[ "${address_v6}" == "${address_v4}" ]] && address_v6=""

    if [[ -z "${private_key}" || -z "${peer_pubkey}" ]]; then
        msg_fail "Could not extract keys from WireGuard profile"
        return 1
    fi

    # Build address line for wireproxy
    local wp_address="${address_v4}"
    [[ -n "${address_v6}" ]] && wp_address="${address_v4}, ${address_v6}"

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

    # Check service status for debug info
    msg_warn "wireproxy may not have started — checking status..."
    systemctl status wireproxy --no-pager 2>&1 | tail -5 || true

    # Try once more
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

    # Step 1: Download wireproxy binary
    if ! install_wireproxy_bin; then
        return 1
    fi

    # Step 2: Download wgcf binary
    if ! install_wgcf; then
        return 1
    fi

    # Step 3: Register WARP account and generate WireGuard profile
    if ! register_warp; then
        return 1
    fi

    # Step 4: Create wireproxy config from WireGuard profile
    if ! create_wireproxy_config; then
        return 1
    fi

    # Step 5: Create systemd service and start wireproxy
    if ! start_wireproxy_service; then
        return 1
    fi

    # Step 6: Configure Xray SOCKS outbound
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

    msg_ok "WARP removed (wireproxy + wgcf + config)"
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
