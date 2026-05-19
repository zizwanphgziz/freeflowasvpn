#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Xray Installation & Configuration
# NO USER PROMPTS — all config is automatic with sensible defaults
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

install_xray_core() {
    print_section "Installing Xray Core"

    mkdir -p /usr/local/share/xray
    wget -q -O /usr/local/share/xray/geosite.dat \
        "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" 2>/dev/null
    wget -q -O /usr/local/share/xray/geoip.dat \
        "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" 2>/dev/null

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root 2>&1 | tail -5

    if command -v xray &>/dev/null; then
        msg_ok "Xray installed: $(xray version | head -1)"
    else
        msg_fail "Xray installation failed"
        return 1
    fi
}

generate_xray_config() {
    print_section "Generating Xray Configuration"

    local domain
    domain=$(get_domain)

    # Auto-generate UUID — no prompts, strip all control chars
    local uuid
    uuid=$(generate_uuid | tr -d '[:cntrl:]' | tr -d '[:space:]')
    echo "${uuid}" > "${CONFIG_DIR}/default_uuid"

    # Default paths — all hardcoded, sensible defaults
    local vless_ws_path="/vless-ws"
    local vless_hu_path="/vless-hup"
    local vless_xhttp_path="/vless-xhttp"
    local vless_grpc_sn="vless-grpc"
    local vmess_ws_path="/vmess-ws"
    local vmess_grpc_sn="vmess-grpc"
    local trojan_ws_path="/trojan-ws"
    local trojan_grpc_sn="trojan-grpc"

    # Save paths config
    mkdir -p "${CONFIG_DIR}"
    cat > "${CONFIG_DIR}/paths.conf" <<EOF
VLESS_WS_PATH=${vless_ws_path}
VLESS_HU_PATH=${vless_hu_path}
VLESS_XHTTP_PATH=${vless_xhttp_path}
VLESS_GRPC_SN=${vless_grpc_sn}
VMESS_WS_PATH=${vmess_ws_path}
VMESS_GRPC_SN=${vmess_grpc_sn}
TROJAN_WS_PATH=${trojan_ws_path}
TROJAN_GRPC_SN=${trojan_grpc_sn}
EOF

    # Generate XTLS Reality keys
    local reality_private=""
    local reality_public=""
    local reality_short_id=""

    if xray x25519 &>/dev/null; then
        local reality_keys
        reality_keys=$(xray x25519 2>&1)
        reality_private=$(echo "${reality_keys}" | grep -i "private" | awk '{print $NF}')
        reality_public=$(echo "${reality_keys}" | grep -i "public" | awk '{print $NF}')
    fi

    # Fallback if key generation fails
    if [[ -z "${reality_private}" ]]; then
        reality_private=$(openssl rand -base64 32 | tr -d '=+/' | head -c 43)
        reality_public="none"
    fi
    reality_short_id=$(openssl rand -hex 4)

    # Reality destination (configurable, default: www.google.com)
    local reality_dest
    reality_dest=$(cat "${CONFIG_DIR}/reality_dest" 2>/dev/null || echo "www.google.com")

    # Sanitize ALL variables — strip control characters that break JSON
    uuid=$(echo -n "${uuid}" | tr -d '[:cntrl:]')
    domain=$(echo -n "${domain}" | tr -d '[:cntrl:]')
    reality_private=$(echo -n "${reality_private}" | tr -d '[:cntrl:]')
    reality_public=$(echo -n "${reality_public}" | tr -d '[:cntrl:]')
    reality_short_id=$(echo -n "${reality_short_id}" | tr -d '[:cntrl:]')

    mkdir -p "${CONFIG_DIR}"
    echo "${reality_private}" > "${CONFIG_DIR}/reality_private_key"
    echo "${reality_public}" > "${CONFIG_DIR}/reality_public_key"
    echo "${reality_short_id}" > "${CONFIG_DIR}/reality_short_id"
    echo "${reality_dest}" > "${CONFIG_DIR}/reality_dest"

    # Setup log directory
    mkdir -p /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 666 /var/log/xray/*.log

    # Port mapping:
    #   10001 = VLESS WS          (behind nginx)
    #   10002 = VLESS HttpUpgrade (behind nginx)
    #   10003 = VLESS XHTTP       (behind nginx)
    #   10004 = VLESS gRPC        (behind nginx)
    #   10005 = VMESS WS          (behind nginx)
    #   10006 = VMESS gRPC        (behind nginx)
    #   10007 = Trojan WS         (behind nginx)
    #   10008 = Trojan gRPC       (behind nginx)
    #   443   = VLESS XTLS Reality (TCP, direct — NOT behind nginx)
    #   10010 = Trojan TCP        (fallback from Reality)
    mkdir -p /etc/xray
    cat > "${XRAY_CONFIG}" <<XRAYEOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "none"
  },
  "api": {
    "services": ["StatsService"],
    "tag": "api"
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "statsUserUplink": true,
        "statsUserDownlink": true
      }
    },
    "system": {
      "statsInboundUplink": true,
      "statsInboundDownlink": true,
      "statsOutboundUplink": true,
      "statsOutboundDownlink": true
    }
  },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": 10085,
      "protocol": "dokodemo-door",
      "settings": { "address": "127.0.0.1" },
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "${vless_ws_path}" }
      },
      "tag": "vless-ws",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "httpupgrade",
        "httpupgradeSettings": { "path": "${vless_hu_path}", "host": "${domain}" }
      },
      "tag": "vless-httpupgrade",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": { "path": "${vless_xhttp_path}" }
      },
      "tag": "vless-xhttp",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "${vless_grpc_sn}" }
      },
      "tag": "vless-grpc",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${uuid}", "alterId": 0, "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "${vmess_ws_path}" }
      },
      "tag": "vmess-ws",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vmess",
      "settings": {
        "clients": [{ "id": "${uuid}", "alterId": 0, "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "${vmess_grpc_sn}" }
      },
      "tag": "vmess-grpc",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "${trojan_ws_path}" }
      },
      "tag": "trojan-ws",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": { "serviceName": "${trojan_grpc_sn}" }
      },
      "tag": "trojan-grpc",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [{ "id": "${uuid}", "flow": "xtls-rprx-vision", "email": "default@freeflow" }],
        "fallbacks": [{ "dest": 10010, "xver": 1 }]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${reality_dest}:443",
          "xver": 0,
          "serverNames": ["${reality_dest}"],
          "privateKey": "${reality_private}",
          "shortIds": ["${reality_short_id}"]
        }
      },
      "tag": "vless-reality",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    },
    {
      "listen": "127.0.0.1",
      "port": 10010,
      "protocol": "trojan",
      "settings": {
        "clients": [{ "password": "${uuid}", "email": "default@freeflow" }]
      },
      "streamSettings": { "network": "tcp", "security": "none" },
      "tag": "trojan-tcp",
      "sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "settings": {}, "tag": "direct" },
    { "protocol": "blackhole", "settings": {}, "tag": "blocked" }
  ],
  "routing": {
    "rules": [
      { "inboundTag": ["api"], "outboundTag": "api", "type": "field" },
      { "type": "field", "outboundTag": "blocked", "protocol": ["bittorrent"] }
    ]
  }
}
XRAYEOF

    # Create systemd override
    mkdir -p /etc/systemd/system/xray.service.d
    cat > /etc/systemd/system/xray.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -config ${XRAY_CONFIG}
User=root
EOF

    systemctl daemon-reload
    systemctl enable xray 2>/dev/null

    # Validate JSON with jq before testing with xray
    if ! jq empty "${XRAY_CONFIG}" 2>/dev/null; then
        msg_warn "JSON validation failed — attempting to fix..."
        # Remove control characters and re-validate
        local cleaned
        cleaned=$(sed 's/[[:cntrl:]]//g' "${XRAY_CONFIG}")
        echo "${cleaned}" | jq '.' > "${XRAY_CONFIG}.tmp" 2>/dev/null
        if [[ -s "${XRAY_CONFIG}.tmp" ]]; then
            mv "${XRAY_CONFIG}.tmp" "${XRAY_CONFIG}"
            msg_ok "JSON fixed"
        else
            rm -f "${XRAY_CONFIG}.tmp"
            msg_fail "Could not fix JSON"
        fi
    fi

    # Test config before starting
    if xray run -test -config "${XRAY_CONFIG}" &>/dev/null; then
        restart_service xray
    else
        msg_fail "Xray config test failed — checking error..."
        xray run -test -config "${XRAY_CONFIG}" 2>&1 | tail -5
        msg_warn "Attempting to start anyway..."
        systemctl restart xray 2>/dev/null
    fi
}

uninstall_xray() {
    print_section "Uninstalling Xray"

    if ! confirm "Remove Xray completely?"; then
        return 1
    fi

    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove
    rm -rf /etc/xray /var/log/xray /usr/local/share/xray

    msg_ok "Xray removed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    install_xray_core
    generate_xray_config
fi
