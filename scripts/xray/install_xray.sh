#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Xray Installation & Configuration
# Supports: VLESS (WS/HU/XHTTP/gRPC/XTLS), VMESS (WS/gRPC), Trojan (WS/gRPC/TCP)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

install_xray_core() {
    print_section "Installing Xray Core"

    # Download geodata
    mkdir -p /usr/local/share/xray
    wget -q -O /usr/local/share/xray/geosite.dat \
        "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
    wget -q -O /usr/local/share/xray/geoip.dat \
        "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
    chmod +x /usr/local/share/xray/*

    # Install Xray via official installer
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data

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

    # Prompt for UUID
    echo ""
    echo -e " ${BOLD}UUID Configuration${NC}"
    local uuid
    uuid=$(prompt_uuid)

    # Prompt for custom paths
    echo ""
    echo -e " ${BOLD}Path Configuration${NC}"
    read -rp " VLESS WebSocket path (default: /): " vless_ws_path
    vless_ws_path="${vless_ws_path:-/}"

    read -rp " VLESS HttpUpgrade path (default: /vless-hu): " vless_hu_path
    vless_hu_path="${vless_hu_path:-/vless-hu}"

    read -rp " VLESS XHTTP path (default: /vless-xhttp): " vless_xhttp_path
    vless_xhttp_path="${vless_xhttp_path:-/vless-xhttp}"

    read -rp " VLESS gRPC serviceName (default: vless-grpc): " vless_grpc_sn
    vless_grpc_sn="${vless_grpc_sn:-vless-grpc}"

    read -rp " VMESS WebSocket path (default: /vmess-ws): " vmess_ws_path
    vmess_ws_path="${vmess_ws_path:-/vmess-ws}"

    read -rp " VMESS gRPC serviceName (default: vmess-grpc): " vmess_grpc_sn
    vmess_grpc_sn="${vmess_grpc_sn:-vmess-grpc}"

    read -rp " Trojan WebSocket path (default: /trojan-ws): " trojan_ws_path
    trojan_ws_path="${trojan_ws_path:-/trojan-ws}"

    read -rp " Trojan gRPC serviceName (default: trojan-grpc): " trojan_grpc_sn
    trojan_grpc_sn="${trojan_grpc_sn:-trojan-grpc}"

    # Generate a Trojan password from UUID
    local trojan_password="${uuid}"

    # Save user config
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
    local reality_keys
    reality_keys=$(xray x25519 2>/dev/null)
    local reality_private
    reality_private=$(echo "${reality_keys}" | grep "Private" | awk '{print $3}')
    local reality_public
    reality_public=$(echo "${reality_keys}" | grep "Public" | awk '{print $3}')
    local reality_short_id
    reality_short_id=$(openssl rand -hex 4)

    echo "${reality_private}" > "${CONFIG_DIR}/reality_private_key"
    echo "${reality_public}" > "${CONFIG_DIR}/reality_public_key"
    echo "${reality_short_id}" > "${CONFIG_DIR}/reality_short_id"

    # Xray config with all protocols
    # Port mapping:
    #   10001 = VLESS WS
    #   10002 = VLESS HttpUpgrade
    #   10003 = VLESS XHTTP
    #   10004 = VLESS gRPC
    #   10005 = VMESS WS
    #   10006 = VMESS gRPC
    #   10007 = Trojan WS
    #   10008 = Trojan gRPC
    #   10009 = VLESS XTLS Reality (TCP, direct — not behind nginx)
    #   10010 = Trojan TCP TLS (direct)
    cat > "${XRAY_CONFIG}" <<XRAYEOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
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
      "settings": {
        "address": "127.0.0.1"
      },
      "tag": "api"
    },
    {
      "listen": "127.0.0.1",
      "port": 10001,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "${uuid}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${vless_ws_path}"
        }
      },
      "tag": "vless-ws",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10002,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "${uuid}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "httpupgrade",
        "httpupgradeSettings": {
          "path": "${vless_hu_path}",
          "host": "${domain}"
        }
      },
      "tag": "vless-httpupgrade",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10003,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "${uuid}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "path": "${vless_xhttp_path}"
        }
      },
      "tag": "vless-xhttp",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10004,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "${uuid}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "${vless_grpc_sn}"
        }
      },
      "tag": "vless-grpc",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10005,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${vmess_ws_path}"
        }
      },
      "tag": "vmess-ws",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10006,
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "alterId": 0,
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "${vmess_grpc_sn}"
        }
      },
      "tag": "vmess-grpc",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10007,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${trojan_password}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${trojan_ws_path}"
        }
      },
      "tag": "trojan-ws",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10008,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${trojan_password}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "grpc",
        "grpcSettings": {
          "serviceName": "${trojan_grpc_sn}"
        }
      },
      "tag": "trojan-grpc",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "0.0.0.0",
      "port": 443,
      "protocol": "vless",
      "settings": {
        "decryption": "none",
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision",
            "email": "default@freeflow"
          }
        ],
        "fallbacks": [
          {
            "dest": 10010,
            "xver": 1
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.google.com:443",
          "xver": 0,
          "serverNames": ["www.google.com", "google.com"],
          "privateKey": "${reality_private}",
          "shortIds": ["${reality_short_id}"]
        }
      },
      "tag": "vless-reality",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "listen": "127.0.0.1",
      "port": 10010,
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${trojan_password}",
            "email": "default@freeflow"
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "none"
      },
      "tag": "trojan-tcp",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "inboundTag": ["api"],
        "outboundTag": "api",
        "type": "field"
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": ["bittorrent"]
      },
      {
        "type": "field",
        "ip": [
          "0.0.0.0/8",
          "10.0.0.0/8",
          "100.64.0.0/10",
          "169.254.0.0/16",
          "172.16.0.0/12",
          "192.0.0.0/24",
          "192.0.2.0/24",
          "192.168.0.0/16",
          "198.18.0.0/15",
          "198.51.100.0/24",
          "203.0.113.0/24",
          "::1/128",
          "fc00::/7",
          "fe80::/10"
        ],
        "outboundTag": "blocked"
      }
    ]
  }
}
XRAYEOF

    # Save the default UUID
    echo "${uuid}" > "${CONFIG_DIR}/default_uuid"

    # Setup log directory
    mkdir -p /var/log/xray
    chown -R www-data:www-data /var/log/xray 2>/dev/null
    touch /var/log/xray/access.log /var/log/xray/error.log
    chmod 644 /var/log/xray/*.log

    # Create systemd override for xray
    mkdir -p /etc/systemd/system/xray.service.d
    cat > /etc/systemd/system/xray.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/local/bin/xray run -config ${XRAY_CONFIG}
User=root
EOF

    systemctl daemon-reload
    restart_service xray

    msg_ok "Xray configured with all protocols"
    msg_info "Default UUID: ${uuid}"
    msg_info "Protocols: VLESS (WS/HU/XHTTP/gRPC/Reality), VMESS (WS/gRPC), Trojan (WS/gRPC/TCP)"
}

uninstall_xray() {
    print_section "Uninstalling Xray"

    if ! confirm "Remove Xray completely?"; then
        return 1
    fi

    systemctl stop xray 2>/dev/null
    systemctl disable xray 2>/dev/null
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove

    rm -rf /etc/xray
    rm -rf /var/log/xray
    rm -rf /usr/local/share/xray

    msg_ok "Xray removed"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    install_xray_core
    generate_xray_config
fi
