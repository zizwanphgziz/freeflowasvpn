#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Nginx Reverse Proxy Setup
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

install_nginx() {
    print_section "Installing Nginx"

    # Stop Apache if running (common conflict)
    systemctl stop apache2 2>/dev/null
    systemctl disable apache2 2>/dev/null

    apt-get install -y nginx
    if command -v nginx &>/dev/null; then
        msg_ok "Nginx installed: $(nginx -v 2>&1)"
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
        msg_fail "No domain configured. Run setup first."
        return 1
    fi

    msg_info "Obtaining SSL certificate for ${domain}..."

    # Stop services using port 80 temporarily
    systemctl stop nginx 2>/dev/null

    # Request certificate
    certbot certonly --standalone \
        --preferred-challenges http \
        --agree-tos \
        --email "admin@${domain}" \
        -d "${domain}" \
        --non-interactive

    if [[ -f "/etc/letsencrypt/live/${domain}/fullchain.pem" ]]; then
        # Copy certs to xray directory
        cp "/etc/letsencrypt/live/${domain}/fullchain.pem" /etc/xray/xray.crt
        cp "/etc/letsencrypt/live/${domain}/privkey.pem" /etc/xray/xray.key
        chmod 644 /etc/xray/xray.crt
        chmod 644 /etc/xray/xray.key
        msg_ok "SSL certificate obtained for ${domain}"
    else
        msg_fail "SSL certificate request failed"
        msg_info "Check that your domain points to this server's IP"
        return 1
    fi

    # Setup auto-renewal cron
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --deploy-hook 'systemctl reload nginx' && cp /etc/letsencrypt/live/${domain}/fullchain.pem /etc/xray/xray.crt && cp /etc/letsencrypt/live/${domain}/privkey.pem /etc/xray/xray.key") | crontab -
        msg_ok "SSL auto-renewal configured"
    fi
}

generate_nginx_config() {
    print_section "Generating Nginx Configuration"

    local domain
    domain=$(get_domain)

    # Load paths
    local vless_ws_path="/"
    local vless_hu_path="/vless-hu"
    local vless_xhttp_path="/vless-xhttp"
    local ssh_ws_path="/ssh"

    if [[ -f "${CONFIG_DIR}/paths.conf" ]]; then
        source "${CONFIG_DIR}/paths.conf"
    fi

    # Check if SSH WS is installed
    local ssh_ws_block=""
    if [[ -f "${CONFIG_DIR}/modules/ssh_ws_installed" ]]; then
        ssh_ws_block="
    # --- SSH WebSocket ---
    location ${ssh_ws_path} {
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

    # Generate main nginx config
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

    # Generate site config with multiport support
    cat > "${NGINX_CONF}" <<NGINXEOF
# ============================================
# FreeFlow ASVPN — Nginx Reverse Proxy Config
# ============================================

# --- Non-TLS Ports (HTTP) ---
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

    # --- VLESS WebSocket (Non-TLS) ---
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

    # --- VLESS HttpUpgrade (Non-TLS) ---
    location ${vless_hu_path} {
        if (\$http_upgrade != "Websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # --- VLESS XHTTP (Non-TLS) ---
    location ${vless_xhttp_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
    }
${ssh_ws_block}

    # --- Default: Decoy Page ---
    location / {
        root /var/www/html;
        index index.html;
    }
}

# --- TLS Ports (HTTPS) ---
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    listen 8443 ssl;
    listen [::]:8443 ssl;
    listen 2083 ssl;
    listen [::]:2083 ssl;
    listen 2087 ssl;
    listen [::]:2087 ssl;
    http2 on;

    server_name ${domain};

    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_ciphers EECDH+CHACHA20:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:!MD5;
    ssl_protocols TLSv1.2 TLSv1.3;

    # --- VLESS WebSocket (TLS) ---
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

    # --- VLESS HttpUpgrade (TLS) ---
    location ${vless_hu_path} {
        if (\$http_upgrade != "Websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }

    # --- VLESS XHTTP (TLS) ---
    location ${vless_xhttp_path} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header Host \$http_host;
    }
${ssh_ws_block}

    # --- Default: Decoy Page ---
    location / {
        root /var/www/html;
        index index.html;
    }
}
NGINXEOF

    # Remove default site config if exists
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null

    # Test nginx config
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

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    install_nginx_full
fi
