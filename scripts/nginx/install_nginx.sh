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
        msg_ok "Nginx installed"
    else
        msg_fail "Nginx installation failed"
        return 1
    fi
}

setup_ssl_certificate() {
    print_section "Setting Up SSL Certificate"

    local domain
    domain=$(get_domain)

    if [[ -z "${domain}" ]]; then
        msg_fail "No domain configured"
        return 1
    fi

    # Stop nginx for port 80 standalone verification
    systemctl stop nginx 2>/dev/null

    # Install acme.sh if not present
    if [[ ! -f "/root/.acme.sh/acme.sh" ]]; then
        msg_info "Installing acme.sh..."
        curl -sL https://get.acme.sh | sh -s email="admin@${domain}" 2>/dev/null
    fi

    # Issue certificate using acme.sh with ECC (ec-256)
    msg_info "Requesting Let's Encrypt certificate via acme.sh..."
    mkdir -p /etc/xray

    if /root/.acme.sh/acme.sh --issue -d "${domain}" --standalone --keylength ec-256 --force 2>/dev/null; then
        /root/.acme.sh/acme.sh --install-cert -d "${domain}" --ecc \
            --fullchain-file /etc/xray/xray.crt \
            --key-file /etc/xray/xray.key \
            --reloadcmd "systemctl reload nginx; systemctl reload xray" 2>/dev/null

        chmod 644 /etc/xray/xray.crt
        chmod 600 /etc/xray/xray.key

        msg_ok "Let's Encrypt ECC certificate installed"
        msg_info "Auto-renewal handled by acme.sh cron"
    else
        msg_warn "acme.sh failed — generating self-signed certificate"
        msg_info "Replace with Let's Encrypt later via menu"

        openssl req -x509 -nodes -days 3650 \
            -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -keyout /etc/xray/xray.key \
            -out /etc/xray/xray.crt \
            -subj "/CN=${domain}/O=FreeFlow/C=MY" 2>/dev/null
        chmod 644 /etc/xray/xray.crt
        chmod 600 /etc/xray/xray.key

        if [[ -f /etc/xray/xray.crt ]]; then
            msg_ok "Self-signed ECC certificate created"
        else
            msg_fail "Could not create SSL certificate"
            return 1
        fi
    fi

    systemctl start nginx 2>/dev/null
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
        proxy_redirect off;
        proxy_pass http://127.0.0.1:700;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \"upgrade\";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
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

    # Site config — Port 443 NOT included (used by Xray Reality)
    # Split into 3 server blocks:
    #   1. Non-TLS (80, 8080, 8880, 2086) — WS/HttpUpgrade/XHTTP only, NO gRPC
    #   2. TLS WebSocket (8443) — NO http2 (WS requires HTTP/1.1)
    #   3. TLS gRPC (2083, 2087) — http2 ON (gRPC requires HTTP/2)
    cat > "${NGINX_CONF}" <<NGINXEOF
# ============================================
# FreeFlow ASVPN — Nginx Reverse Proxy
# Port 443: Xray XTLS Reality (direct)
# ============================================

# --- Non-TLS Ports (WS/HttpUpgrade/XHTTP only, NO gRPC) ---
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

    location ${vless_ws_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }

    location ${vless_hu_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }

    location ${vless_xhttp_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 86400s;
    }

    location ${vmess_ws_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10005;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }

    location ${trojan_ws_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10007;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }
${ssh_ws_block}

    # Default — decoy page
    location / {
        root /var/www/html;
        index index.html;
    }
}

# --- TLS WebSocket Port (8443 — NO http2, WS requires HTTP/1.1) ---
server {
    listen 8443 ssl;
    listen [::]:8443 ssl;

    server_name ${domain};

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location ${vless_ws_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }

    location ${vless_hu_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }

    location ${vless_xhttp_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 86400s;
    }

    location ${vmess_ws_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10005;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }

    location ${trojan_ws_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10007;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_read_timeout 86400s;
    }
${ssh_ws_block}

    # Default — decoy page
    location / {
        root /var/www/html;
        index index.html;
    }
}

# --- TLS gRPC Ports (2083, 2087 — http2 ON, required for gRPC) ---
server {
    listen 2083 ssl;
    listen [::]:2083 ssl;
    listen 2087 ssl;
    listen [::]:2087 ssl;
    http2 on;

    server_name ${domain};

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location /${vless_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10004;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    location /${vmess_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10006;
        grpc_set_header X-Real-IP \$remote_addr;
    }

    location /${trojan_grpc_sn} {
        grpc_pass grpc://127.0.0.1:10008;
        grpc_set_header X-Real-IP \$remote_addr;
    }

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
