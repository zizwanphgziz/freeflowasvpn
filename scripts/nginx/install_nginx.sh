#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Nginx Reverse Proxy Setup
# Protocols: VLESS, VMESS, Trojan (WS/gRPC/HttpUpgrade/XHTTP)
# Port 443 is reserved for Xray XTLS Reality (direct)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

install_nginx() {
    print_section "Installing Nginx"

    systemctl stop apache2 2>/dev/null
    systemctl disable apache2 2>/dev/null

    apt-get install -y nginx > /dev/null 2>&1
    if command -v nginx &>/dev/null; then
        systemctl enable nginx 2>/dev/null
        msg_ok "Nginx installed and enabled"
    else
        msg_fail "Nginx installation failed"
        return 1
    fi
}

setup_ssl_certificate() {
    print_section "Setting Up SSL Certificate (acme.sh)"

    local domain
    domain=$(get_domain)

    if [[ -z "${domain}" ]]; then
        msg_fail "No domain configured"
        return 1
    fi

    msg_info "Obtaining SSL certificate for ${domain} via acme.sh..."

    # Stop nginx to free port 80 for standalone verification
    systemctl stop nginx 2>/dev/null

    # Install acme.sh if not present
    if [[ ! -f /root/.acme.sh/acme.sh ]]; then
        msg_info "Installing acme.sh..."
        curl -sL https://get.acme.sh | sh -s email=admin@"${domain}" 2>&1 | tail -3
    fi

    # Ensure acme.sh is available
    if [[ ! -f /root/.acme.sh/acme.sh ]]; then
        msg_fail "acme.sh installation failed"
        return 1
    fi

    # Set Let's Encrypt as default CA
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt 2>/dev/null

    # Issue ECC certificate (ec-256) using standalone mode (port 80)
    /root/.acme.sh/acme.sh --issue -d "${domain}" --standalone -k ec-256 --force 2>&1 | tail -5

    # Install cert to /etc/xray/
    mkdir -p /etc/xray
    /root/.acme.sh/acme.sh --installcert -d "${domain}" \
        --fullchainpath /etc/xray/xray.crt \
        --keypath /etc/xray/xray.key \
        --ecc \
        --reloadcmd "systemctl reload nginx" 2>&1 | tail -3

    if [[ -f /etc/xray/xray.crt ]] && [[ -f /etc/xray/xray.key ]]; then
        chmod 644 /etc/xray/xray.crt /etc/xray/xray.key
        msg_ok "SSL certificate obtained from Let's Encrypt (ECC)"
    else
        msg_fail "SSL certificate generation failed"
        msg_info "Check: domain DNS must point to this server's IP"
        msg_info "Check: port 80 must be reachable from the internet"
        return 1
    fi

    msg_ok "SSL auto-renewal configured (acme.sh built-in cron)"
}

generate_nginx_config() {
    print_section "Generating Nginx Configuration"

    local domain
    domain=$(get_domain)

    # Load paths
    local vless_ws_path="/vless-ws"
    local vless_hu_path="/vless-hup"
    local vless_xhttp_path="/vless-xhttp"
    local vless_grpc_sn="vless-grpc"
    local vmess_ws_path="/vmess-ws"
    local vmess_grpc_sn="vmess-grpc"
    local trojan_ws_path="/trojan-ws"
    local trojan_grpc_sn="trojan-grpc"

    if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
        source "${CONFIG_DIR}/paths.conf"
    fi

    # SSH WS block (only if installed)
    local ssh_ws_block=""
    if [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]]; then
        ssh_ws_block="
    # --- SSH WebSocket ---
    location /ssh {
        if (\$http_upgrade != \"Websocket\") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
        proxy_set_header Host \$http_host;
    }"
    fi

    # Main nginx config
    cat > /etc/nginx/nginx.conf <<'NGINXMAIN'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers EECDH+CHACHA20:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:!MD5;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    gzip on;

    include /etc/nginx/conf.d/*.conf;
}
NGINXMAIN

    # Detect nginx version for http2 directive compatibility
    local nginx_ver http2_directive listen_ssl_h2
    nginx_ver=$(nginx -v 2>&1 | grep -oP '[\d.]+' | head -1)
    if [[ "$(echo -e "${nginx_ver}\n1.25.1" | sort -V | head -1)" == "1.25.1" ]]; then
        # nginx >= 1.25.1 — use separate http2 directive
        http2_directive="    http2 on;"
        listen_ssl_h2="ssl"
    else
        # nginx < 1.25.1 — use http2 in listen directive
        http2_directive=""
        listen_ssl_h2="ssl http2"
    fi

    # Site config — Port 443 NOT included (used by Xray Reality)
    cat > "${NGINX_CONF}" <<NGINXEOF
# ============================================
# FreeFlow ASVPN — Nginx Reverse Proxy
# Port 443: Xray XTLS Reality (direct)
# ============================================

# --- Non-TLS Ports ---
server {
    listen 80;
    listen [::]:80;
    listen 8080;
    listen [::]:8080;
    listen 8880;
    listen [::]:8880;
    listen 2086;
    listen [::]:2086;

    server_name ${domain};

    # VLESS WebSocket (Non-TLS)
    location ${vless_ws_path} {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) / break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # VLESS HttpUpgrade (Non-TLS)
    location ${vless_hu_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # VLESS XHTTP (Non-TLS)
    location ${vless_xhttp_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
    }

    # VLESS gRPC (Non-TLS)
    location /${vless_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10004;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    # VMESS WebSocket (Non-TLS)
    location ${vmess_ws_path} {
        if (\$http_upgrade != "Websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10005;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # VMESS gRPC (Non-TLS)
    location /${vmess_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    # Trojan WebSocket (Non-TLS)
    location ${trojan_ws_path} {
        if (\$http_upgrade != "Websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10007;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # Trojan gRPC (Non-TLS)
    location /${trojan_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$remote_addr;
    }
${ssh_ws_block}

    # Default
    location / {
        root /var/www/html;
        index index.html;
    }
}

# --- TLS Ports (NOT 443 — that's Xray Reality) ---
server {
    listen 8443 ${listen_ssl_h2};
    listen [::]:8443 ${listen_ssl_h2};
    listen 2083 ${listen_ssl_h2};
    listen [::]:2083 ${listen_ssl_h2};
    listen 2087 ${listen_ssl_h2};
    listen [::]:2087 ${listen_ssl_h2};
${http2_directive}

    server_name ${domain};

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_ciphers EECDH+CHACHA20:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:!MD5;
    ssl_protocols TLSv1.2 TLSv1.3;

    # VLESS WebSocket (TLS)
    location ${vless_ws_path} {
        if (\$http_upgrade != "Websocket") {
            rewrite /(.*) / break;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # VLESS HttpUpgrade (TLS)
    location ${vless_hu_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # VLESS XHTTP (TLS)
    location ${vless_xhttp_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
    }

    # VLESS gRPC (TLS)
    location /${vless_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10004;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    # VMESS WebSocket (TLS)
    location ${vmess_ws_path} {
        if (\$http_upgrade != "Websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10005;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # VMESS gRPC (TLS)
    location /${vmess_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    # Trojan WebSocket (TLS)
    location ${trojan_ws_path} {
        if (\$http_upgrade != "Websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10007;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # Trojan gRPC (TLS)
    location /${trojan_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$remote_addr;
    }
${ssh_ws_block}

    # Default
    location / {
        root /var/www/html;
        index index.html;
    }
}
NGINXEOF

    rm -f /etc/nginx/sites-enabled/default 2>/dev/null

    if nginx -t 2>/dev/null; then
        msg_ok "Nginx configuration valid"
        restart_service nginx
    else
        msg_fail "Nginx configuration has errors"
        nginx -t
        return 1
    fi
}

setup_decoy_page() {
    mkdir -p /var/www/html
    cat > /var/www/html/index.html <<'HTML'
<!DOCTYPE html>
<html>
<head><title>Welcome</title></head>
<body>
<h1>It works!</h1>
<p>This server is running.</p>
</body>
</html>
HTML
    msg_ok "Decoy page created"
}

install_nginx_full() {
    install_nginx
    setup_decoy_page
    setup_ssl_certificate
    generate_nginx_config
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    install_nginx_full
fi
