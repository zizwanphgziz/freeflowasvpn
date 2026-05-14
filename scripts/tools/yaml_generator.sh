#!/bin/bash
# ============================================================
# FreeFlow ASVPN - YAML/Clash Config Link Generator
# Generates ready-made configs for Clash/Mihomo/Meta clients
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

generate_clash_config() {
    local protocol="$1"
    protocol="${protocol:-vless}"

    print_section "YAML Config Generator (${protocol^^})"

    read -rp " Username: " username
    if [[ -z "${username}" ]]; then
        msg_fail "Username cannot be empty"
        return 1
    fi

    local user_file=""
    for dir in active expired; do
        if [[ -f "${USER_DB}/${protocol}/${dir}/${username}" ]]; then
            user_file="${USER_DB}/${protocol}/${dir}/${username}"
            break
        fi
    done

    if [[ -z "${user_file}" ]]; then
        msg_fail "User '${username}' not found in ${protocol} users"
        return 1
    fi

    local uuid domain
    uuid=$(grep "^UUID=" "${user_file}" | cut -d= -f2)
    domain=$(get_domain)

    # Load paths
    local vless_ws_path="/" vless_hu_path="/vless-hu" vless_xhttp_path="/vless-xhttp"
    local vless_grpc_sn="vless-grpc" vmess_ws_path="/vmess-ws" vmess_grpc_sn="vmess-grpc"
    local trojan_ws_path="/trojan-ws" trojan_grpc_sn="trojan-grpc"
    if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
        source "${CONFIG_DIR}/paths.conf"
    fi

    local yaml_dir="${DATA_DIR}/yaml"
    mkdir -p "${yaml_dir}"
    local yaml_file="${yaml_dir}/${username}_${protocol}.yaml"

    case "${protocol}" in
        vless)
            cat > "${yaml_file}" <<YAMLEOF
proxies:
  - name: "${username}-VLESS-WS-TLS"
    type: vless
    server: ${domain}
    port: 443
    uuid: ${uuid}
    network: ws
    tls: true
    udp: true
    skip-cert-verify: false
    servername: ${domain}
    ws-opts:
      path: ${vless_ws_path}
      headers:
        Host: ${domain}

  - name: "${username}-VLESS-WS"
    type: vless
    server: ${domain}
    port: 80
    uuid: ${uuid}
    network: ws
    tls: false
    udp: true
    ws-opts:
      path: ${vless_ws_path}
      headers:
        Host: ${domain}

  - name: "${username}-VLESS-gRPC"
    type: vless
    server: ${domain}
    port: 443
    uuid: ${uuid}
    network: grpc
    tls: true
    udp: true
    skip-cert-verify: false
    servername: ${domain}
    grpc-opts:
      grpc-service-name: ${vless_grpc_sn}
YAMLEOF
            ;;
        vmess)
            cat > "${yaml_file}" <<YAMLEOF
proxies:
  - name: "${username}-VMESS-WS-TLS"
    type: vmess
    server: ${domain}
    port: 443
    uuid: ${uuid}
    alterId: 0
    cipher: auto
    network: ws
    tls: true
    udp: true
    skip-cert-verify: false
    servername: ${domain}
    ws-opts:
      path: ${vmess_ws_path}
      headers:
        Host: ${domain}

  - name: "${username}-VMESS-WS"
    type: vmess
    server: ${domain}
    port: 80
    uuid: ${uuid}
    alterId: 0
    cipher: auto
    network: ws
    tls: false
    udp: true
    ws-opts:
      path: ${vmess_ws_path}
      headers:
        Host: ${domain}

  - name: "${username}-VMESS-gRPC"
    type: vmess
    server: ${domain}
    port: 443
    uuid: ${uuid}
    alterId: 0
    cipher: auto
    network: grpc
    tls: true
    udp: true
    skip-cert-verify: false
    servername: ${domain}
    grpc-opts:
      grpc-service-name: ${vmess_grpc_sn}
YAMLEOF
            ;;
        trojan)
            cat > "${yaml_file}" <<YAMLEOF
proxies:
  - name: "${username}-TROJAN-WS-TLS"
    type: trojan
    server: ${domain}
    port: 443
    password: ${uuid}
    network: ws
    tls: true
    udp: true
    skip-cert-verify: false
    sni: ${domain}
    ws-opts:
      path: ${trojan_ws_path}
      headers:
        Host: ${domain}

  - name: "${username}-TROJAN-WS"
    type: trojan
    server: ${domain}
    port: 80
    password: ${uuid}
    network: ws
    tls: false
    udp: true
    ws-opts:
      path: ${trojan_ws_path}
      headers:
        Host: ${domain}

  - name: "${username}-TROJAN-gRPC"
    type: trojan
    server: ${domain}
    port: 443
    password: ${uuid}
    network: grpc
    tls: true
    udp: true
    skip-cert-verify: false
    sni: ${domain}
    grpc-opts:
      grpc-service-name: ${trojan_grpc_sn}
YAMLEOF
            ;;
    esac

    print_section "YAML Config Generated"
    echo -e " ${GREEN}File${NC}: ${yaml_file}"
    echo ""
    echo -e " ${BOLD}Config Content:${NC}"
    print_line
    cat "${yaml_file}"
    print_line
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    generate_clash_config "${1:-vless}"
fi
