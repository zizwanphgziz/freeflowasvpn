#!/bin/bash
# ============================================================
# FreeFlow ASVPN - WSS Config Converter
# Converts between different VPN client config formats
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

generate_vless_link() {
    local uuid="$1" domain="$2" port="$3" path="$4" tls="$5" transport="$6"
    local sn="$7"

    local security="none"
    [[ "${tls}" == "true" ]] && security="tls"

    local link="vless://${uuid}@${domain}:${port}?"

    case "${transport}" in
        ws) link+="type=ws&path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${path}'))" 2>/dev/null || echo "${path}")&host=${domain}" ;;
        grpc) link+="type=grpc&serviceName=${sn}&mode=gun" ;;
        httpupgrade) link+="type=httpupgrade&path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${path}'))" 2>/dev/null || echo "${path}")&host=${domain}" ;;
        tcp) link+="type=tcp&flow=xtls-rprx-vision" ;;
    esac

    link+="&security=${security}"
    [[ "${tls}" == "true" ]] && link+="&sni=${domain}"

    echo "${link}"
}

generate_vmess_link() {
    local uuid="$1" domain="$2" port="$3" path="$4" tls="$5" transport="$6"
    local sn="$7"

    local net="${transport}"
    local tls_val="none"
    [[ "${tls}" == "true" ]] && tls_val="tls"

    local json
    json=$(jq -n \
        --arg v "2" \
        --arg ps "${domain}-vmess-${transport}" \
        --arg add "${domain}" \
        --arg port "${port}" \
        --arg id "${uuid}" \
        --arg aid "0" \
        --arg net "${net}" \
        --arg type "none" \
        --arg host "${domain}" \
        --arg path "${path}" \
        --arg tls "${tls_val}" \
        --arg sni "${domain}" \
        '{v:$v, ps:$ps, add:$add, port:$port, id:$id, aid:$aid, net:$net, type:$type, host:$host, path:$path, tls:$tls, sni:$sni}')

    if [[ "${transport}" == "grpc" ]]; then
        json=$(echo "${json}" | jq --arg sn "${sn}" '.path = $sn')
    fi

    local encoded
    encoded=$(echo -n "${json}" | base64 -w 0)
    echo "vmess://${encoded}"
}

generate_trojan_link() {
    local password="$1" domain="$2" port="$3" path="$4" tls="$5" transport="$6"
    local sn="$7"

    local link="trojan://${password}@${domain}:${port}?"

    case "${transport}" in
        ws) link+="type=ws&path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${path}'))" 2>/dev/null || echo "${path}")&host=${domain}" ;;
        grpc) link+="type=grpc&serviceName=${sn}&mode=gun" ;;
        tcp) link+="type=tcp" ;;
    esac

    local security="none"
    [[ "${tls}" == "true" ]] && security="tls"
    link+="&security=${security}"
    [[ "${tls}" == "true" ]] && link+="&sni=${domain}"

    echo "${link}"
}

convert_user_configs() {
    print_section "WSS Config Converter"

    read -rp " Username: " username
    if [[ -z "${username}" ]]; then
        msg_fail "Username cannot be empty"
        return 1
    fi

    local domain
    domain=$(get_domain)

    # Load paths
    local vless_ws_path="/vless-ws" vless_hu_path="/vless-hup" vless_xhttp_path="/vless-xhttp"
    local vless_grpc_sn="vless-grpc" vmess_ws_path="/vmess-ws" vmess_grpc_sn="vmess-grpc"
    local trojan_ws_path="/trojan-ws" trojan_grpc_sn="trojan-grpc"
    if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
        source "${CONFIG_DIR}/paths.conf"
    fi

    echo ""
    echo -e " ${BOLD}Generated Share Links:${NC}"
    print_line

    # Check each protocol
    for proto in vless vmess trojan; do
        local user_file=""
        for dir in active expired; do
            if [[ -f "${USER_DB}/${proto}/${dir}/${username}" ]]; then
                user_file="${USER_DB}/${proto}/${dir}/${username}"
                break
            fi
        done

        [[ -z "${user_file}" ]] && continue

        local uuid
        uuid=$(grep "^UUID=" "${user_file}" | cut -d= -f2)

        echo ""
        echo -e " ${YELLOW}=== ${proto^^} Links ===${NC}"

        case "${proto}" in
            vless)
                echo -e " ${CYAN}WS TLS:${NC}"
                echo "  $(generate_vless_link "${uuid}" "${domain}" 8443 "${vless_ws_path}" true ws)"
                echo -e " ${CYAN}WS nonTLS:${NC}"
                echo "  $(generate_vless_link "${uuid}" "${domain}" 80 "${vless_ws_path}" false ws)"
                echo -e " ${CYAN}gRPC TLS:${NC}"
                echo "  $(generate_vless_link "${uuid}" "${domain}" 2083 "" true grpc "${vless_grpc_sn}")"
                ;;
            vmess)
                echo -e " ${CYAN}WS TLS:${NC}"
                echo "  $(generate_vmess_link "${uuid}" "${domain}" 8443 "${vmess_ws_path}" true ws)"
                echo -e " ${CYAN}WS nonTLS:${NC}"
                echo "  $(generate_vmess_link "${uuid}" "${domain}" 80 "${vmess_ws_path}" false ws)"
                echo -e " ${CYAN}gRPC TLS:${NC}"
                echo "  $(generate_vmess_link "${uuid}" "${domain}" 2083 "" true grpc "${vmess_grpc_sn}")"
                ;;
            trojan)
                echo -e " ${CYAN}WS TLS:${NC}"
                echo "  $(generate_trojan_link "${uuid}" "${domain}" 8443 "${trojan_ws_path}" true ws)"
                echo -e " ${CYAN}WS nonTLS:${NC}"
                echo "  $(generate_trojan_link "${uuid}" "${domain}" 80 "${trojan_ws_path}" false ws)"
                echo -e " ${CYAN}gRPC TLS:${NC}"
                echo "  $(generate_trojan_link "${uuid}" "${domain}" 2083 "" true grpc "${trojan_grpc_sn}")"
                ;;
        esac
    done
    print_line
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    convert_user_configs
fi
