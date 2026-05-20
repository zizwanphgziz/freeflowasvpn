#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WARP Cloudflare Module (Install/Uninstall)
# Uses hamid-gh98/x-ui-scripts WARP installer (fscarmen/warp).
# Pre-installs wireproxy from GitHub to avoid packagecloud.io
# download failures, then lets gh98 handle WARP registration
# and wireproxy configuration.
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

WARP_CONFIG="${CONFIG_DIR}/warp"
WARP_SOCKS_PORT="40000"
WARP_SOCKS_ADDR="127.0.0.1"
WIREPROXY_BIN="/usr/local/bin/wireproxy"

GH98_SCRIPT_URL="https://raw.githubusercontent.com/hamid-gh98/x-ui-scripts/main/install_warp_proxy.sh"

# --- Pre-install wireproxy binary from GitHub ---
install_wireproxy_bin() {
    if command -v wireproxy &>/dev/null; then
        msg_ok "wireproxy binary already installed"
        return 0
    fi

    msg_info "Pre-installing wireproxy from GitHub..."
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
            msg_ok "wireproxy binary installed from GitHub"
            return 0
        fi
    fi

    rm -rf "${tmp_dir}"
    msg_fail "Could not download wireproxy from GitHub"
    return 1
}

# --- Run gh98 WARP installer ---
run_gh98_warp_install() {
    msg_info "Running hamid-gh98 WARP installer..."
    msg_info "This will register WARP and configure wireproxy via fscarmen/warp"
    echo ""

    # Download and run the gh98 script with -yf (accept defaults + force)
    local tmp_script
    tmp_script=$(mktemp)
    if wget -q -O "${tmp_script}" "${GH98_SCRIPT_URL}" 2>/dev/null || \
       curl -sL -o "${tmp_script}" "${GH98_SCRIPT_URL}" 2>/dev/null; then
        chmod +x "${tmp_script}"
        bash "${tmp_script}" -yf
        local exit_code=$?
        rm -f "${tmp_script}"

        if [[ ${exit_code} -ne 0 ]]; then
            msg_warn "gh98 script exited with code ${exit_code} — checking if wireproxy started anyway..."
        fi
    else
        rm -f "${tmp_script}"
        msg_fail "Could not download gh98 WARP installer"
        return 1
    fi

    # Verify wireproxy is running
    sleep 2
    if ss -nltp 2>/dev/null | grep -q wireproxy; then
        local running_port
        running_port=$(ss -nltp 2>/dev/null | grep wireproxy | awk '{print $(NF-2)}' | head -1 | cut -d: -f2)
        WARP_SOCKS_PORT="${running_port:-40000}"
        msg_ok "WireProxy running on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
        return 0
    fi

    # Try starting wireproxy if service exists but not running
    if systemctl start wireproxy 2>/dev/null; then
        sleep 2
        if ss -nltp 2>/dev/null | grep -q wireproxy; then
            local running_port
            running_port=$(ss -nltp 2>/dev/null | grep wireproxy | awk '{print $(NF-2)}' | head -1 | cut -d: -f2)
            WARP_SOCKS_PORT="${running_port:-40000}"
            msg_ok "WireProxy started on socks5://${WARP_SOCKS_ADDR}:${WARP_SOCKS_PORT}"
            return 0
        fi
    fi

    msg_fail "WireProxy failed to start after gh98 installation"
    msg_info "Try manually: warp w"
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
    msg_info "Using hamid-gh98 WARP installer (fscarmen/warp)"
    echo ""

    # Step 1: Pre-install wireproxy binary from GitHub
    if ! install_wireproxy_bin; then
        return 1
    fi

    # Step 2: Run gh98 WARP installer (handles registration + config)
    if ! run_gh98_warp_install; then
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

    # Stop wireproxy service
    systemctl stop wireproxy 2>/dev/null
    systemctl disable wireproxy 2>/dev/null

    # Uninstall via fscarmen/warp (handles WARP account cleanup)
    if command -v warp &>/dev/null; then
        warp u <<< $'y\n' 2>/dev/null || true
    fi

    # Remove wireproxy binary and leftover files
    rm -f "${WIREPROXY_BIN}"
    rm -f /etc/systemd/system/wireproxy.service
    rm -f /usr/bin/warp
    rm -rf /etc/wireguard
    rm -rf "${WARP_CONFIG}"
    rm -f "${CONFIG_DIR}/modules/warp_installed"
    systemctl daemon-reload 2>/dev/null

    msg_ok "WARP removed (wireproxy + warp + config)"
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
