#!/bin/bash
# ============================================================
# FreeFlow ASVPN - SSH WebSocket Module (Install/Uninstall)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

SSH_WS_PORT=700
SSH_WS_SERVICE="ssh-ws"

install_ssh_ws() {
    print_section "Installing SSH WebSocket"

    apt-get install -y python3

    # Create SSH WebSocket proxy script
    cat > /usr/local/bin/ssh-ws-proxy <<'PYEOF'
#!/usr/bin/env python3
"""SSH WebSocket Proxy — bridges WebSocket connections to SSH."""
import socket
import threading
import select
import sys
import os

LISTEN_HOST = "127.0.0.1"
LISTEN_PORT = int(os.environ.get("SSH_WS_PORT", 700))
SSH_HOST = "127.0.0.1"
SSH_PORT = 22

def handle_client(client_socket):
    """Handle incoming WebSocket client and proxy to SSH."""
    try:
        # Read the HTTP upgrade request
        request = b""
        while b"\r\n\r\n" not in request:
            data = client_socket.recv(4096)
            if not data:
                client_socket.close()
                return
            request += data

        # Send WebSocket upgrade response
        response = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            "\r\n"
        )
        client_socket.sendall(response.encode())

        # Connect to SSH
        ssh_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_socket.connect((SSH_HOST, SSH_PORT))

        # Bidirectional relay
        sockets = [client_socket, ssh_socket]
        while True:
            readable, _, exceptional = select.select(sockets, [], sockets, 60)
            if exceptional:
                break
            for sock in readable:
                data = sock.recv(8192)
                if not data:
                    raise ConnectionError("Connection closed")
                if sock is client_socket:
                    ssh_socket.sendall(data)
                else:
                    client_socket.sendall(data)
    except Exception:
        pass
    finally:
        try:
            client_socket.close()
        except Exception:
            pass
        try:
            ssh_socket.close()
        except Exception:
            pass

def main():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_HOST, LISTEN_PORT))
    server.listen(128)
    print(f"SSH-WS Proxy listening on {LISTEN_HOST}:{LISTEN_PORT}")

    while True:
        client, addr = server.accept()
        thread = threading.Thread(target=handle_client, args=(client,), daemon=True)
        thread.start()

if __name__ == "__main__":
    main()
PYEOF

    chmod +x /usr/local/bin/ssh-ws-proxy

    # Create systemd service
    cat > /etc/systemd/system/${SSH_WS_SERVICE}.service <<EOF
[Unit]
Description=SSH WebSocket Proxy
After=network.target

[Service]
Type=simple
Environment=SSH_WS_PORT=${SSH_WS_PORT}
ExecStart=/usr/bin/python3 /usr/local/bin/ssh-ws-proxy
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Mark module as installed
    mkdir -p "${CONFIG_DIR}/modules"
    touch "${CONFIG_DIR}/modules/ssh_ws_installed"

    enable_service "${SSH_WS_SERVICE}"
    restart_service "${SSH_WS_SERVICE}"

    # Regenerate nginx config to include SSH WS location
    if [[ -f "${SCRIPT_DIR}/../nginx/install_nginx.sh" ]]; then
        source "${SCRIPT_DIR}/../nginx/install_nginx.sh"
        generate_nginx_config
    fi

    msg_ok "SSH WebSocket installed on port ${SSH_WS_PORT}"
    msg_info "Accessible via Nginx at path: /ssh"
}

uninstall_ssh_ws() {
    print_section "Uninstalling SSH WebSocket"

    if ! confirm "Remove SSH WebSocket?"; then
        return 1
    fi

    systemctl stop "${SSH_WS_SERVICE}" 2>/dev/null
    systemctl disable "${SSH_WS_SERVICE}" 2>/dev/null

    rm -f /etc/systemd/system/${SSH_WS_SERVICE}.service
    rm -f /usr/local/bin/ssh-ws-proxy
    rm -f "${CONFIG_DIR}/modules/ssh_ws_installed"

    systemctl daemon-reload

    # Regenerate nginx config without SSH WS
    if [[ -f "${SCRIPT_DIR}/../nginx/install_nginx.sh" ]]; then
        source "${SCRIPT_DIR}/../nginx/install_nginx.sh"
        generate_nginx_config
    fi

    msg_ok "SSH WebSocket removed"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        uninstall) uninstall_ssh_ws ;;
        *) install_ssh_ws ;;
    esac
fi
