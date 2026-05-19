#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WARP Cloudflare Module (Install/Uninstall)
# Uses Xray native WireGuard outbound via wgcf — no external
# daemon needed. Matches proven architecture from fscarmen/warp,
# Remnawave docs, and XTLS/Xray-core guidance.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

WARP_CONFIG="${CONFIG_DIR}/warp"

# --- Install wgcf binary ---
install_wgcf() {
    if command -v wgcf &>/dev/null; then
        msg_ok "wgcf already installed"
        return 0
    fi

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

    # Get latest release tag (e.g. "v2.2.30") via GitHub API redirect
    local wgcf_tag
    wgcf_tag=$(curl -sI "https://github.com/ViRb3/wgcf/releases/latest" \
               | grep -i '^location:' | sed 's|.*/tag/||;s/[[:space:]]//g')

    if [[ -z "${wgcf_tag}" ]]; then
        msg_warn "Could not detect latest wgcf version, using v2.2.30"
        wgcf_tag="v2.2.30"
    fi

    # Asset names are: wgcf_<version_without_v>_linux_<arch>
    local wgcf_ver="${wgcf_tag#v}"
    local wgcf_url="https://github.com/ViRb3/wgcf/releases/download/${wgcf_tag}/wgcf_${wgcf_ver}_linux_${wgcf_arch}"

    msg_info "Downloading wgcf ${wgcf_tag}..."
    if wget -q -O /usr/local/bin/wgcf "${wgcf_url}" 2>/dev/null || \
       curl -sL -o /usr/local/bin/wgcf "${wgcf_url}" 2>/dev/null; then
        chmod +x /usr/local/bin/wgcf
        # Verify it's a real binary, not an HTML error page
        if ! wgcf --version &>/dev/null; then
            rm -f /usr/local/bin/wgcf
            msg_fail "Downloaded file is not a valid wgcf binary"
            return 1
        fi
        msg_ok "wgcf ${wgcf_tag} installed"
    else
        msg_fail "Could not download wgcf"
        return 1
    fi
}

# --- Register with Cloudflare WARP and generate WireGuard profile ---
register_warp() {
    msg_info "Registering with Cloudflare WARP..."

    mkdir -p "${WARP_CONFIG}"
    cd "${WARP_CONFIG}" || return 1

    # Remove stale account/profile files so wgcf starts fresh
    rm -f "${WARP_CONFIG}/wgcf-account.toml" "${WARP_CONFIG}/wgcf-profile.conf"

    # Register new account (retry up to 3 times — Cloudflare API may
    # return 500 on the first attempt yet still create the account file)
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
        msg_info "This may be a Cloudflare API issue — try again later"
        return 1
    fi

    # Generate WireGuard profile
    wgcf generate 2>&1 || true

    if [[ ! -f "${WARP_CONFIG}/wgcf-profile.conf" ]]; then
        msg_fail "Could not generate WireGuard profile"
        return 1
    fi
    msg_ok "WireGuard profile generated"

    # Extract keys from wgcf-profile.conf
    local private_key address_v4 address_v6 endpoint peer_pubkey
    private_key=$(grep "^PrivateKey" "${WARP_CONFIG}/wgcf-profile.conf" | awk '{print $3}')
    address_v4=$(grep "^Address" "${WARP_CONFIG}/wgcf-profile.conf" | head -1 | awk '{print $3}')
    address_v6=$(grep "^Address" "${WARP_CONFIG}/wgcf-profile.conf" | tail -1 | awk '{print $3}')
    endpoint=$(grep "^Endpoint" "${WARP_CONFIG}/wgcf-profile.conf" | awk '{print $3}')
    peer_pubkey=$(grep "^PublicKey" "${WARP_CONFIG}/wgcf-profile.conf" | awk '{print $3}')

    if [[ -z "${private_key}" || -z "${peer_pubkey}" ]]; then
        msg_fail "Could not extract keys from WireGuard profile"
        return 1
    fi

    # Save extracted values for Xray config
    echo "${private_key}" > "${WARP_CONFIG}/private_key"
    echo "${peer_pubkey}" > "${WARP_CONFIG}/peer_pubkey"
    echo "${address_v4}" > "${WARP_CONFIG}/address_v4"
    echo "${address_v6}" > "${WARP_CONFIG}/address_v6"
    echo "${endpoint}" > "${WARP_CONFIG}/endpoint"

    chmod 600 "${WARP_CONFIG}/private_key" "${WARP_CONFIG}/wgcf-account.toml"

    msg_ok "WARP keys extracted"
    msg_info "  Private key : [saved]"
    msg_info "  Address IPv4: ${address_v4}"
    msg_info "  Address IPv6: ${address_v6}"
    msg_info "  Endpoint    : ${endpoint}"
}

# --- Configure Xray WARP outbound (native WireGuard protocol) ---
configure_xray_warp() {
    msg_info "Configuring Xray WARP outbound (native WireGuard)..."

    local private_key peer_pubkey address_v4 address_v6 endpoint
    private_key=$(cat "${WARP_CONFIG}/private_key" 2>/dev/null)
    peer_pubkey=$(cat "${WARP_CONFIG}/peer_pubkey" 2>/dev/null)
    address_v4=$(cat "${WARP_CONFIG}/address_v4" 2>/dev/null)
    address_v6=$(cat "${WARP_CONFIG}/address_v6" 2>/dev/null)
    endpoint=$(cat "${WARP_CONFIG}/endpoint" 2>/dev/null || echo "engage.cloudflareclient.com:2408")

    if [[ -z "${private_key}" || -z "${peer_pubkey}" ]]; then
        msg_fail "WARP keys not found — run install first"
        return 1
    fi

    # Remove any existing WARP outbound
    local tmp_config
    tmp_config=$(mktemp)
    jq '.outbounds = [.outbounds[] | select(.tag != "warp")]' \
        "${XRAY_CONFIG}" > "${tmp_config}" 2>/dev/null

    if [[ ! -s "${tmp_config}" ]]; then
        rm -f "${tmp_config}"
        msg_fail "Could not read Xray config"
        return 1
    fi

    # Split endpoint into host:port
    local ep_host ep_port
    ep_host="${endpoint%%:*}"
    ep_port="${endpoint##*:}"

    # Build address array — include both v4 and v6
    local addresses="[\"${address_v4}\"]"
    if [[ -n "${address_v6}" && "${address_v6}" != "${address_v4}" ]]; then
        addresses="[\"${address_v4}\", \"${address_v6}\"]"
    fi

    # Add Xray native WireGuard outbound
    jq --arg sk "${private_key}" \
       --arg pk "${peer_pubkey}" \
       --argjson addrs "${addresses}" \
       --arg ep "${ep_host}:${ep_port}" \
    '
        .outbounds += [{
            "protocol": "wireguard",
            "settings": {
                "secretKey": $sk,
                "address": $addrs,
                "peers": [{
                    "publicKey": $pk,
                    "allowedIPs": ["0.0.0.0/0", "::/0"],
                    "endpoint": $ep
                }],
                "reserved": [0, 0, 0],
                "mtu": 1280,
                "kernelMode": false
            },
            "tag": "warp"
        }]
    ' "${tmp_config}" > "${tmp_config}.new"

    if [[ -s "${tmp_config}.new" ]]; then
        mv "${tmp_config}.new" "${XRAY_CONFIG}"
        rm -f "${tmp_config}"
    else
        rm -f "${tmp_config}" "${tmp_config}.new"
        msg_fail "Could not add WARP outbound to Xray config"
        return 1
    fi

    # Ensure domainStrategy is set in routing for proper domain resolution
    tmp_config=$(mktemp)
    jq '.routing.domainStrategy = "IPOnDemand"' "${XRAY_CONFIG}" > "${tmp_config}"
    if [[ -s "${tmp_config}" ]]; then
        mv "${tmp_config}" "${XRAY_CONFIG}"
    else
        rm -f "${tmp_config}"
    fi

    restart_service xray
    msg_ok "Xray WARP outbound configured (native WireGuard)"
}

# --- Main install function ---
install_warp() {
    print_section "Installing Cloudflare WARP"

    msg_info "WARP bypasses domains that cannot pass through the VPS"
    msg_info "Traffic is routed via Cloudflare's network via Xray WireGuard"
    echo ""

    # Step 1: Install wgcf
    if ! install_wgcf; then
        return 1
    fi

    # Step 2: Register and generate keys
    if ! register_warp; then
        return 1
    fi

    # Step 3: Configure Xray outbound
    if ! configure_xray_warp; then
        return 1
    fi

    # Mark as installed
    mkdir -p "${CONFIG_DIR}/modules"
    touch "${CONFIG_DIR}/modules/warp_installed"
    echo "xray-wireguard" > "${WARP_CONFIG}/method"

    msg_ok "WARP installed successfully"
    msg_info "Method: Xray native WireGuard (no external daemon)"
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

    # Remove WARP outbound and routing rules from Xray config
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

    # Remove wgcf binary and config
    rm -f /usr/local/bin/wgcf
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

    # Check if Xray has WARP outbound configured
    if jq -e '.outbounds[] | select(.tag == "warp" and .protocol == "wireguard")' "${XRAY_CONFIG}" &>/dev/null; then
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
