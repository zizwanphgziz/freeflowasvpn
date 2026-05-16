#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Telegram Bot Setup
# Supports all protocols: VLESS, VMESS, Trojan
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

BOT_CONFIG="${CONFIG_DIR}/telegram"
BOT_SCRIPT="/usr/local/bin/freeflow-bot"
BOT_SERVICE="freeflow-bot"

setup_telegram_bot() {
    print_section "Telegram Bot Setup"

    msg_info "You need a Telegram Bot Token and your Chat ID"
    msg_info "Get bot token from @BotFather on Telegram"
    msg_info "Get chat ID from @userinfobot on Telegram"
    echo ""

    read -rp " Telegram Bot Token: " bot_token
    if [[ -z "${bot_token}" ]]; then
        msg_fail "Bot token cannot be empty"
        return 1
    fi

    read -rp " Telegram Chat ID: " chat_id
    if [[ -z "${chat_id}" ]]; then
        msg_fail "Chat ID cannot be empty"
        return 1
    fi

    # Validate token
    local bot_info
    bot_info=$(curl -s "https://api.telegram.org/bot${bot_token}/getMe")
    if ! echo "${bot_info}" | jq -e '.ok' 2>/dev/null | grep -q true; then
        msg_fail "Invalid bot token"
        return 1
    fi

    local bot_name
    bot_name=$(echo "${bot_info}" | jq -r '.result.username')
    msg_ok "Bot verified: @${bot_name}"

    # Save config
    mkdir -p "${BOT_CONFIG}"
    echo "${bot_token}" > "${BOT_CONFIG}/token"
    echo "${chat_id}" > "${BOT_CONFIG}/chat_id"
    chmod 600 "${BOT_CONFIG}/token" "${BOT_CONFIG}/chat_id"
    chmod 700 "${BOT_CONFIG}"

    # Install Python dependencies
    apt-get install -y python3-pip 2>/dev/null
    pip3 install python-telegram-bot --break-system-packages 2>/dev/null || pip3 install python-telegram-bot 2>/dev/null

    # Generate bot script
    generate_bot_script

    # Create systemd service
    cat > /etc/systemd/system/${BOT_SERVICE}.service <<EOF
[Unit]
Description=FreeFlow ASVPN Telegram Bot
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 ${BOT_SCRIPT}
Restart=always
RestartSec=10
Environment=BOT_TOKEN=${bot_token}
Environment=CHAT_ID=${chat_id}

[Install]
WantedBy=multi-user.target
EOF

    mkdir -p "${CONFIG_DIR}/modules"
    touch "${CONFIG_DIR}/modules/telegram_installed"

    enable_service "${BOT_SERVICE}"
    restart_service "${BOT_SERVICE}"

    msg_ok "Telegram bot @${bot_name} is now running"
    msg_info "Send /menu to the bot to get started"
}

generate_bot_script() {
    cat > "${BOT_SCRIPT}" <<'BOTEOF'
#!/usr/bin/env python3
"""FreeFlow ASVPN Telegram Bot — full menu control via Telegram."""
import os
import subprocess
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, CallbackQueryHandler, MessageHandler,
    filters, ContextTypes, ConversationHandler
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

BOT_TOKEN = os.environ.get("BOT_TOKEN", "")
CHAT_ID = os.environ.get("CHAT_ID", "")

WAITING_USERNAME, WAITING_UUID, WAITING_DAYS, WAITING_DOMAIN = range(4)

def authorized(func):
    """Decorator to restrict access to authorized chat ID."""
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        if str(update.effective_chat.id) != CHAT_ID:
            await update.message.reply_text("Unauthorized.")
            return
        return await func(update, context)
    return wrapper

def run_cmd(cmd):
    """Run a shell command and return output."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=30
        )
        return result.stdout.strip() or result.stderr.strip() or "Done"
    except subprocess.TimeoutExpired:
        return "Command timed out"
    except Exception as e:
        return f"Error: {e}"

@authorized
async def cmd_start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "FreeFlow ASVPN Bot v2.0\n\n"
        "Use /menu to see all options\n"
        "Use /status to check services"
    )

@authorized
async def cmd_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [InlineKeyboardButton("VLESS", callback_data="menu_vless"),
         InlineKeyboardButton("VMESS", callback_data="menu_vmess"),
         InlineKeyboardButton("Trojan", callback_data="menu_trojan")],
        [InlineKeyboardButton("SSH Users", callback_data="ssh_list"),
         InlineKeyboardButton("Online Users", callback_data="online")],
        [InlineKeyboardButton("User Usage", callback_data="usage"),
         InlineKeyboardButton("Trial Account", callback_data="menu_trial")],
        [InlineKeyboardButton("Service Status", callback_data="status"),
         InlineKeyboardButton("Restart All", callback_data="restart")],
        [InlineKeyboardButton("Server Info", callback_data="sysinfo"),
         InlineKeyboardButton("Bandwidth", callback_data="bandwidth")],
        [InlineKeyboardButton("Speedtest", callback_data="speedtest"),
         InlineKeyboardButton("RAM Monitor", callback_data="ram")],
        [InlineKeyboardButton("Netflix Check", callback_data="netflix"),
         InlineKeyboardButton("WARP Status", callback_data="warp_status")],
        [InlineKeyboardButton("Xray Logs", callback_data="xray_logs"),
         InlineKeyboardButton("Check Update", callback_data="check_update")],
        [InlineKeyboardButton("Backup to TG", callback_data="tg_backup")],
    ]
    reply_markup = InlineKeyboardMarkup(keyboard)
    await update.message.reply_text("FreeFlow ASVPN Menu:", reply_markup=reply_markup)

@authorized
async def cmd_status(update: Update, context: ContextTypes.DEFAULT_TYPE):
    services = ["xray", "nginx", "ssh-ws", "freeflow-bot"]
    lines = ["Service Status:\n"]
    for svc in services:
        status = run_cmd(f"systemctl is-active {svc}")
        icon = "🟢" if status == "active" else "🔴"
        lines.append(f"{icon} {svc}: {status}")
    await update.message.reply_text("\n".join(lines))

async def button_handler(update: Update, context: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    if str(query.from_user.id) != CHAT_ID:
        await query.answer("Unauthorized")
        return

    await query.answer()
    data = query.data

    # Protocol sub-menus
    if data == "menu_vless":
        keyboard = [
            [InlineKeyboardButton("Add VLESS", callback_data="add_vless"),
             InlineKeyboardButton("Delete VLESS", callback_data="del_vless")],
            [InlineKeyboardButton("List VLESS", callback_data="list_vless"),
             InlineKeyboardButton("Renew VLESS", callback_data="renew_vless")],
            [InlineKeyboardButton("Reactivate VLESS", callback_data="react_vless")],
            [InlineKeyboardButton("« Back", callback_data="back_menu")],
        ]
        await query.edit_message_text("VLESS User Management:", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    if data == "menu_vmess":
        keyboard = [
            [InlineKeyboardButton("Add VMESS", callback_data="add_vmess"),
             InlineKeyboardButton("Delete VMESS", callback_data="del_vmess")],
            [InlineKeyboardButton("List VMESS", callback_data="list_vmess"),
             InlineKeyboardButton("Renew VMESS", callback_data="renew_vmess")],
            [InlineKeyboardButton("Reactivate VMESS", callback_data="react_vmess")],
            [InlineKeyboardButton("« Back", callback_data="back_menu")],
        ]
        await query.edit_message_text("VMESS User Management:", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    if data == "menu_trojan":
        keyboard = [
            [InlineKeyboardButton("Add Trojan", callback_data="add_trojan"),
             InlineKeyboardButton("Delete Trojan", callback_data="del_trojan")],
            [InlineKeyboardButton("List Trojan", callback_data="list_trojan"),
             InlineKeyboardButton("Renew Trojan", callback_data="renew_trojan")],
            [InlineKeyboardButton("Reactivate Trojan", callback_data="react_trojan")],
            [InlineKeyboardButton("« Back", callback_data="back_menu")],
        ]
        await query.edit_message_text("Trojan User Management:", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    if data == "menu_trial":
        keyboard = [
            [InlineKeyboardButton("VLESS Trial", callback_data="trial_vless"),
             InlineKeyboardButton("VMESS Trial", callback_data="trial_vmess")],
            [InlineKeyboardButton("Trojan Trial", callback_data="trial_trojan")],
            [InlineKeyboardButton("« Back", callback_data="back_menu")],
        ]
        await query.edit_message_text("Create Trial Account:", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    if data == "back_menu":
        keyboard = [
            [InlineKeyboardButton("VLESS", callback_data="menu_vless"),
             InlineKeyboardButton("VMESS", callback_data="menu_vmess"),
             InlineKeyboardButton("Trojan", callback_data="menu_trojan")],
            [InlineKeyboardButton("SSH Users", callback_data="ssh_list"),
             InlineKeyboardButton("Online Users", callback_data="online")],
            [InlineKeyboardButton("User Usage", callback_data="usage"),
             InlineKeyboardButton("Trial Account", callback_data="menu_trial")],
            [InlineKeyboardButton("Service Status", callback_data="status"),
             InlineKeyboardButton("Restart All", callback_data="restart")],
            [InlineKeyboardButton("Server Info", callback_data="sysinfo"),
             InlineKeyboardButton("Bandwidth", callback_data="bandwidth")],
            [InlineKeyboardButton("Speedtest", callback_data="speedtest"),
             InlineKeyboardButton("RAM Monitor", callback_data="ram")],
            [InlineKeyboardButton("Netflix Check", callback_data="netflix"),
             InlineKeyboardButton("WARP Status", callback_data="warp_status")],
            [InlineKeyboardButton("Xray Logs", callback_data="xray_logs"),
             InlineKeyboardButton("Check Update", callback_data="check_update")],
            [InlineKeyboardButton("Backup to TG", callback_data="tg_backup")],
        ]
        await query.edit_message_text("FreeFlow ASVPN Menu:", reply_markup=InlineKeyboardMarkup(keyboard))
        return

    # Direct command mappings
    cmd_map = {
        "list_vless": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh list-active vless",
        "list_vmess": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh list-active vmess",
        "list_trojan": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh list-active trojan",
        "ssh_list": "bash /usr/local/lib/freeflow/scripts/menu/menu.sh 2>/dev/null; ls /etc/freeflow/data/users/ssh/active/ 2>/dev/null || echo 'No SSH users'",
        "usage": "bash /usr/local/lib/freeflow/scripts/user/usage_tracker.sh show",
        "online": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh online",
        "status": "systemctl is-active xray nginx ssh-ws 2>/dev/null; echo '---'; xray version | head -1",
        "restart": "systemctl restart xray nginx ssh-ws 2>/dev/null; echo 'Services restarted'",
        "sysinfo": "echo \"Hostname: $(hostname)\nOS: $(cat /etc/os-release | grep PRETTY | cut -d= -f2)\nCPU: $(nproc) cores\nRAM: $(free -h | awk '/Mem:/{print $2}')\nDisk: $(df -h / | awk 'NR==2{print $2\" (\"$5\" used)\"}')\nIP: $(curl -s4 ifconfig.me)\nUptime: $(uptime -p)\"",
        "bandwidth": "vnstat 2>/dev/null || echo 'vnstat not installed'",
        "speedtest": "speedtest --accept-license 2>/dev/null || echo 'speedtest not installed'",
        "ram": "bash /usr/local/lib/freeflow/scripts/tools/ram_monitor.sh",
        "netflix": "bash /usr/local/lib/freeflow/scripts/tools/netflix_checker.sh",
        "check_update": "bash /usr/local/lib/freeflow/scripts/update/auto_update.sh check",
        "warp_status": "warp-cli status 2>/dev/null || systemctl is-active wg-quick@warp 2>/dev/null || echo 'WARP not installed'",
        "xray_logs": "tail -20 /var/log/xray/access.log 2>/dev/null || echo 'No logs'",
        "tg_backup": "bash /usr/local/lib/freeflow/scripts/tools/tg_auto_backup.sh send",
    }

    # Trial account shortcuts
    trial_map = {
        "trial_vless": "vless",
        "trial_vmess": "vmess",
        "trial_trojan": "trojan",
    }

    if data in cmd_map:
        output = run_cmd(cmd_map[data])
        import re
        output = re.sub(r'\x1b\[[0-9;]*m', '', output)
        if len(output) > 4000:
            output = output[:4000] + "\n... (truncated)"
        await query.edit_message_text(f"```\n{output}\n```", parse_mode="Markdown")
    elif data in trial_map:
        proto = trial_map[data]
        output = run_cmd(f"bash /usr/local/lib/freeflow/scripts/user/manage_user.sh trial {proto}")
        import re
        output = re.sub(r'\x1b\[[0-9;]*m', '', output)
        if len(output) > 4000:
            output = output[:4000] + "\n... (truncated)"
        await query.edit_message_text(f"```\n{output}\n```", parse_mode="Markdown")
    elif data.startswith("add_"):
        proto = data.replace("add_", "")
        context.user_data["action"] = f"add_{proto}"
        context.user_data["protocol"] = proto
        await query.edit_message_text(f"Enter username for new {proto.upper()} user:")
        return WAITING_USERNAME
    elif data.startswith("del_"):
        proto = data.replace("del_", "")
        context.user_data["action"] = f"del_{proto}"
        context.user_data["protocol"] = proto
        await query.edit_message_text(f"Enter {proto.upper()} username to delete:")
        return WAITING_USERNAME
    elif data.startswith("renew_"):
        proto = data.replace("renew_", "")
        context.user_data["action"] = f"renew_{proto}"
        context.user_data["protocol"] = proto
        await query.edit_message_text(f"Enter {proto.upper()} username to renew:")
        return WAITING_USERNAME
    elif data.startswith("react_"):
        proto = data.replace("react_", "")
        context.user_data["action"] = f"react_{proto}"
        context.user_data["protocol"] = proto
        await query.edit_message_text(f"Enter {proto.upper()} username to reactivate:")
        return WAITING_USERNAME

async def handle_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if str(update.effective_chat.id) != CHAT_ID:
        return ConversationHandler.END

    username = update.message.text.strip()
    action = context.user_data.get("action", "")
    context.user_data["username"] = username

    if action.startswith("add_"):
        await update.message.reply_text(
            f"UUID for '{username}'?\n"
            "Send a custom name (e.g. 'Ahmad') or 'random' for auto-generated:"
        )
        return WAITING_UUID
    elif action.startswith("del_"):
        proto = context.user_data.get("protocol", "vless")
        output = run_cmd(
            f"rm -f /etc/freeflow/data/users/{proto}/active/{username} "
            f"/etc/freeflow/data/users/{proto}/expired/{username} && "
            f"jq --arg email '{username}@freeflow' '.inbounds |= map(if .settings.clients then "
            f".settings.clients = [.settings.clients[] | select(.email != $email)] else . end)' "
            f"/etc/xray/config.json > /tmp/xray_tmp.json && "
            f"mv /tmp/xray_tmp.json /etc/xray/config.json && "
            f"systemctl restart xray && echo 'User {username} deleted'"
        )
        await update.message.reply_text(output)
        return ConversationHandler.END
    elif action.startswith("renew_"):
        await update.message.reply_text("How many days to extend?")
        return WAITING_DAYS
    elif action.startswith("react_"):
        await update.message.reply_text("How many days for reactivation?")
        return WAITING_DAYS

async def handle_uuid(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if str(update.effective_chat.id) != CHAT_ID:
        return ConversationHandler.END

    uuid_input = update.message.text.strip()
    context.user_data["uuid_input"] = uuid_input
    await update.message.reply_text("Validity in days? (default: 30)")
    return WAITING_DAYS

async def handle_days(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if str(update.effective_chat.id) != CHAT_ID:
        return ConversationHandler.END

    days = update.message.text.strip() or "30"
    action = context.user_data.get("action", "")
    username = context.user_data.get("username", "")
    protocol = context.user_data.get("protocol", "vless")

    if action.startswith("add_"):
        uuid_input = context.user_data.get("uuid_input", "random")
        if uuid_input.lower() == "random":
            uuid_cmd = "cat /proc/sys/kernel/random/uuid"
        else:
            uuid_cmd = f"echo -n '{uuid_input}' | md5sum | sed 's/^\\(.\\{{8\\}}\\)\\(.\\{{4\\}}\\)\\(.\\{{4\\}}\\)\\(.\\{{4\\}}\\)\\(.\\{{12\\}}\\).*/\\1-\\2-\\3-\\4-\\5/'"

        uuid = run_cmd(uuid_cmd)
        expiry = run_cmd(f"date -d '+{days} days' +'%Y-%m-%d'")

        # Create user file
        run_cmd(
            f"bash -c '"
            f"mkdir -p /etc/freeflow/data/users/{protocol}/active && "
            f"cat > /etc/freeflow/data/users/{protocol}/active/{username} << USEREOF\n"
            f"USERNAME={username}\n"
            f"UUID={uuid}\n"
            f"PROTOCOL={protocol}\n"
            f"CREATED=$(date +%Y-%m-%d)\n"
            f"EXPIRY={expiry}\n"
            f"MAX_IP=2\n"
            f"DATA_LIMIT_GB=0\n"
            f"STATUS=active\n"
            f"USEREOF\n"
            f"echo 0 > /etc/freeflow/data/usage/{username}'"
        )

        # Add to xray config based on protocol
        if protocol == "vless":
            jq_filter = (
                f".inbounds |= map("
                f"if (.tag == \"vless-ws\" or .tag == \"vless-httpupgrade\" or .tag == \"vless-xhttp\" or .tag == \"vless-grpc\") then "
                f".settings.clients += [{{\"id\": $uuid, \"email\": $email}}] "
                f"elif .tag == \"vless-reality\" then "
                f".settings.clients += [{{\"id\": $uuid, \"flow\": \"xtls-rprx-vision\", \"email\": $email}}] "
                f"else . end)"
            )
        elif protocol == "vmess":
            jq_filter = (
                f".inbounds |= map("
                f"if .tag == \"vmess-ws\" or .tag == \"vmess-grpc\" then "
                f".settings.clients += [{{\"id\": $uuid, \"alterId\": 0, \"email\": $email}}] "
                f"else . end)"
            )
        else:  # trojan
            jq_filter = (
                f".inbounds |= map("
                f"if .tag == \"trojan-ws\" or .tag == \"trojan-grpc\" or .tag == \"trojan-tcp\" then "
                f".settings.clients += [{{\"password\": $uuid, \"email\": $email}}] "
                f"else . end)"
            )

        run_cmd(
            f"jq --arg uuid \"{uuid}\" --arg email \"{username}@freeflow\" '"
            f"{jq_filter}' "
            f"/etc/xray/config.json > /tmp/xray_tmp.json && "
            f"mv /tmp/xray_tmp.json /etc/xray/config.json && "
            f"systemctl restart xray"
        )

        domain = run_cmd("cat /etc/freeflow/domain 2>/dev/null")
        await update.message.reply_text(
            f"✅ {protocol.upper()} User Created!\n\n"
            f"Username: {username}\n"
            f"UUID: {uuid}\n"
            f"Expiry: {expiry}\n"
            f"Domain: {domain}\n\n"
            f"TLS Ports: 443,8443,2083,2087\n"
            f"nonTLS Ports: 80,8080,8880,2086"
        )
    elif action.startswith("renew_"):
        output = run_cmd(
            f"bash -c 'exp=$(grep EXPIRY /etc/freeflow/data/users/{protocol}/active/{username} | cut -d= -f2) && "
            f"new=$(date -d \"$exp + {days} days\" +%Y-%m-%d) && "
            f"sed -i \"s/^EXPIRY=.*/EXPIRY=$new/\" /etc/freeflow/data/users/{protocol}/active/{username} && "
            f"echo \"Renewed until $new\"'"
        )
        await update.message.reply_text(output)
    elif action.startswith("react_"):
        output = run_cmd(
            f"bash -c '"
            f"exp=$(date -d \"+{days} days\" +%Y-%m-%d) && "
            f"uuid=$(grep UUID /etc/freeflow/data/users/{protocol}/expired/{username} | cut -d= -f2 | tr -d \"[:cntrl:]\" | tr -d \"[:space:]\") && "
            f"sed -i \"s/^EXPIRY=.*/EXPIRY=$exp/\" /etc/freeflow/data/users/{protocol}/expired/{username} && "
            f"sed -i \"s/^STATUS=.*/STATUS=active/\" /etc/freeflow/data/users/{protocol}/expired/{username} && "
            f"mv /etc/freeflow/data/users/{protocol}/expired/{username} /etc/freeflow/data/users/{protocol}/active/{username} && "
            f"source /usr/local/lib/freeflow/scripts/user/manage_user.sh && "
            f"reactivate_xray_user {protocol} $uuid {username} && "
            f"echo \"Reactivated until $exp (UUID: $uuid)\"'"
        )
        await update.message.reply_text(output)

    return ConversationHandler.END

def main():
    if not BOT_TOKEN:
        logger.error("BOT_TOKEN not set")
        return

    app = Application.builder().token(BOT_TOKEN).build()

    conv_handler = ConversationHandler(
        entry_points=[CallbackQueryHandler(button_handler)],
        states={
            WAITING_USERNAME: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_username)],
            WAITING_UUID: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_uuid)],
            WAITING_DAYS: [MessageHandler(filters.TEXT & ~filters.COMMAND, handle_days)],
        },
        fallbacks=[CommandHandler("menu", cmd_menu)],
    )

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("menu", cmd_menu))
    app.add_handler(CommandHandler("status", cmd_status))
    app.add_handler(conv_handler)

    logger.info("Bot started")
    app.run_polling(allowed_updates=Update.ALL_TYPES)

if __name__ == "__main__":
    main()
BOTEOF

    chmod +x "${BOT_SCRIPT}"
    msg_ok "Bot script generated"
}

uninstall_telegram_bot() {
    print_section "Uninstalling Telegram Bot"

    if ! confirm "Remove Telegram bot?"; then
        return 1
    fi

    systemctl stop "${BOT_SERVICE}" 2>/dev/null
    systemctl disable "${BOT_SERVICE}" 2>/dev/null
    rm -f /etc/systemd/system/${BOT_SERVICE}.service
    rm -f "${BOT_SCRIPT}"
    rm -rf "${BOT_CONFIG}"
    rm -f "${CONFIG_DIR}/modules/telegram_installed"
    systemctl daemon-reload

    msg_ok "Telegram bot removed"
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        uninstall) uninstall_telegram_bot ;;
        *) setup_telegram_bot ;;
    esac
fi
