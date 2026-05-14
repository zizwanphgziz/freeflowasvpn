#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Telegram Bot Setup
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
    chmod 600 "${BOT_CONFIG}/token"

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

# Conversation states
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
        "FreeFlow ASVPN Bot\n\n"
        "Use /menu to see all options\n"
        "Use /status to check services"
    )

@authorized
async def cmd_menu(update: Update, context: ContextTypes.DEFAULT_TYPE):
    keyboard = [
        [
            InlineKeyboardButton("Add VLESS User", callback_data="add_user"),
            InlineKeyboardButton("List Users", callback_data="list_users"),
        ],
        [
            InlineKeyboardButton("Active Users", callback_data="list_active"),
            InlineKeyboardButton("Expired Users", callback_data="list_expired"),
        ],
        [
            InlineKeyboardButton("Delete User", callback_data="del_user"),
            InlineKeyboardButton("Renew User", callback_data="renew_user"),
        ],
        [
            InlineKeyboardButton("Reactivate User", callback_data="reactivate_user"),
            InlineKeyboardButton("User Usage", callback_data="usage"),
        ],
        [
            InlineKeyboardButton("Service Status", callback_data="status"),
            InlineKeyboardButton("Restart Services", callback_data="restart"),
        ],
        [
            InlineKeyboardButton("Server Info", callback_data="sysinfo"),
            InlineKeyboardButton("Bandwidth", callback_data="bandwidth"),
        ],
        [
            InlineKeyboardButton("Speedtest", callback_data="speedtest"),
            InlineKeyboardButton("Check Update", callback_data="check_update"),
        ],
        [
            InlineKeyboardButton("WARP Status", callback_data="warp_status"),
            InlineKeyboardButton("Xray Logs", callback_data="xray_logs"),
        ],
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

    cmd_map = {
        "list_users": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh list",
        "list_active": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh list-active",
        "list_expired": "bash /usr/local/lib/freeflow/scripts/user/manage_user.sh list-expired",
        "usage": "bash /usr/local/lib/freeflow/scripts/user/usage_tracker.sh show",
        "status": "systemctl is-active xray nginx ssh-ws 2>/dev/null; echo '---'; xray version | head -1",
        "restart": "systemctl restart xray nginx ssh-ws 2>/dev/null; echo 'Services restarted'",
        "sysinfo": "echo \"Hostname: $(hostname)\nOS: $(cat /etc/os-release | grep PRETTY | cut -d= -f2)\nCPU: $(nproc) cores\nRAM: $(free -h | awk '/Mem:/{print $2}')\nDisk: $(df -h / | awk 'NR==2{print $2\" (\"$5\" used)\"}')\nIP: $(curl -s4 ifconfig.me)\nUptime: $(uptime -p)\"",
        "bandwidth": "vnstat 2>/dev/null || echo 'vnstat not installed'",
        "speedtest": "speedtest --accept-license 2>/dev/null || echo 'speedtest not installed'",
        "check_update": "bash /usr/local/lib/freeflow/scripts/update/auto_update.sh check",
        "warp_status": "warp-cli status 2>/dev/null || systemctl is-active wg-quick@warp 2>/dev/null || echo 'WARP not installed'",
        "xray_logs": "tail -20 /var/log/xray/access.log 2>/dev/null || echo 'No logs'",
    }

    if data in cmd_map:
        output = run_cmd(cmd_map[data])
        # Strip ANSI codes for Telegram
        import re
        output = re.sub(r'\x1b\[[0-9;]*m', '', output)
        # Truncate if too long
        if len(output) > 4000:
            output = output[:4000] + "\n... (truncated)"
        await query.edit_message_text(f"```\n{output}\n```", parse_mode="Markdown")
    elif data == "add_user":
        context.user_data["action"] = "add_user"
        await query.edit_message_text("Enter username for new VLESS user:")
        return WAITING_USERNAME
    elif data == "del_user":
        context.user_data["action"] = "del_user"
        await query.edit_message_text("Enter username to delete:")
        return WAITING_USERNAME
    elif data == "renew_user":
        context.user_data["action"] = "renew_user"
        await query.edit_message_text("Enter username to renew:")
        return WAITING_USERNAME
    elif data == "reactivate_user":
        context.user_data["action"] = "reactivate_user"
        await query.edit_message_text("Enter username to reactivate:")
        return WAITING_USERNAME

async def handle_username(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if str(update.effective_chat.id) != CHAT_ID:
        return ConversationHandler.END

    username = update.message.text.strip()
    action = context.user_data.get("action", "")
    context.user_data["username"] = username

    if action == "add_user":
        await update.message.reply_text(
            f"UUID for '{username}'?\n"
            "Send a custom name (e.g. 'Ahmad') or 'random' for auto-generated:"
        )
        return WAITING_UUID
    elif action == "del_user":
        output = run_cmd(
            f"bash -c 'source /usr/local/lib/freeflow/scripts/user/manage_user.sh; "
            f"echo y | delete_vless_user_noninteractive \"{username}\"' 2>/dev/null || "
            f"echo \"User {username} — manual deletion needed via VPS\""
        )
        await update.message.reply_text(output)
        return ConversationHandler.END
    elif action == "renew_user":
        await update.message.reply_text("How many days to extend?")
        return WAITING_DAYS
    elif action == "reactivate_user":
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

    if action == "add_user":
        uuid_input = context.user_data.get("uuid_input", "random")
        # Create user via script
        if uuid_input.lower() == "random":
            uuid_cmd = "cat /proc/sys/kernel/random/uuid"
        else:
            uuid_cmd = f"echo -n '{uuid_input}' | md5sum | sed 's/^\\(.\\{{8\\}}\\)\\(.\\{{4\\}}\\)\\(.\\{{4\\}}\\)\\(.\\{{4\\}}\\)\\(.\\{{12\\}}\\).*/\\1-\\2-\\3-\\4-\\5/'"

        uuid = run_cmd(uuid_cmd)
        expiry = run_cmd(f"date -d '+{days} days' +'%Y-%m-%d'")

        # Add to system
        output = run_cmd(
            f"bash -c '"
            f"source /usr/local/lib/freeflow/scripts/core/common.sh && "
            f"setup_directories && "
            f"echo \"USERNAME={username}\" > /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"UUID={uuid}\" >> /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"CREATED=$(date +%Y-%m-%d)\" >> /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"EXPIRY={expiry}\" >> /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"MAX_IP=2\" >> /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"DATA_LIMIT_GB=0\" >> /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"STATUS=active\" >> /etc/freeflow/data/users/vless/active/{username} && "
            f"echo 0 > /etc/freeflow/data/usage/{username}'"
        )

        # Add to xray config
        run_cmd(
            f"jq --arg uuid \"{uuid}\" --arg email \"{username}@freeflow\" '"
            f".inbounds |= map(if .tag == \"vless-ws\" or .tag == \"vless-httpupgrade\" or .tag == \"vless-xhttp\" "
            f"then .settings.clients += [{{\"id\": $uuid, \"email\": $email}}] else . end)' "
            f"/etc/xray/config.json > /tmp/xray_tmp.json && mv /tmp/xray_tmp.json /etc/xray/config.json && "
            f"systemctl restart xray"
        )

        domain = run_cmd("cat /etc/freeflow/domain 2>/dev/null")
        await update.message.reply_text(
            f"User Created!\n\n"
            f"Username: {username}\n"
            f"UUID: {uuid}\n"
            f"Expiry: {expiry}\n"
            f"Domain: {domain}\n\n"
            f"Ports (TLS): 443,8443,2083,2087\n"
            f"Ports (nonTLS): 80,8080,8880,2086"
        )
    elif action == "renew_user":
        output = run_cmd(
            f"bash -c 'exp=$(grep EXPIRY /etc/freeflow/data/users/vless/active/{username} | cut -d= -f2) && "
            f"new=$(date -d \"$exp + {days} days\" +%Y-%m-%d) && "
            f"sed -i \"s/^EXPIRY=.*/EXPIRY=$new/\" /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"Renewed until $new\"'"
        )
        await update.message.reply_text(output)
    elif action == "reactivate_user":
        output = run_cmd(
            f"bash -c 'source /usr/local/lib/freeflow/scripts/core/common.sh && "
            f"exp=$(date -d \"+{days} days\" +%Y-%m-%d) && "
            f"uuid=$(grep UUID /etc/freeflow/data/users/vless/expired/{username} | cut -d= -f2) && "
            f"sed -i \"s/^EXPIRY=.*/EXPIRY=$exp/\" /etc/freeflow/data/users/vless/expired/{username} && "
            f"sed -i \"s/^STATUS=.*/STATUS=active/\" /etc/freeflow/data/users/vless/expired/{username} && "
            f"mv /etc/freeflow/data/users/vless/expired/{username} /etc/freeflow/data/users/vless/active/{username} && "
            f"echo \"Reactivated until $exp (UUID: $uuid)\"'"
        )
        await update.message.reply_text(output)

    return ConversationHandler.END

def main():
    if not BOT_TOKEN:
        logger.error("BOT_TOKEN not set")
        return

    app = Application.builder().token(BOT_TOKEN).build()

    # Conversation handler for multi-step commands
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
