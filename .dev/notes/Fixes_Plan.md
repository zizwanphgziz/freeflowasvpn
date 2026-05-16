# FreeFlow ASVPN v2.3 — Fixes Plan

**Based on:** MoClaw AI VPS Audit Report (2026-05-15)  
**Status:** PLAN ONLY — Awaiting Ahmad's approval before execution  
**Estimated total effort:** ~14 hours across 17 items

---

## Pre-Requisite: Stable Branch for Auto-Update

**Why this must be done first:** The 4AM auto-update cron job reads `REPO_BRANCH` from `common.sh` and downloads scripts from that branch. If we don't merge to a stable branch first, any fixes we push will be overwritten overnight by the cron job pulling from the old branch.

**Steps:**
1. Merge current `devin/1778775736-v2.1-ux-fix` branch into `init-branch`
2. In `scripts/core/common.sh` line 9: change `REPO_BRANCH="devin/1778775736-v2.1-ux-fix"` → `REPO_BRANCH="init-branch"`
3. In `setup.sh` line 14: change `REPO_BRANCH="devin/1778775736-v2.1-ux-fix"` → `REPO_BRANCH="init-branch"`
4. Push to `init-branch`

---

## Priority 1 — RED (Must Fix for Installation to Work)

### FIX 1: Nginx Config — Separate WS and gRPC Server Blocks
**File:** `scripts/nginx/install_nginx.sh` (lines 154-376)  
**Root Cause:** Current config puts WS and gRPC on same TLS ports with `http2 on`. WebSocket needs HTTP/1.1, gRPC needs HTTP/2. These are incompatible on the same server block.

**Current (broken):**
```
# Lines 267-275: Single TLS block with all protocols + http2
server {
    listen 8443 ssl;
    listen 2083 ssl;
    listen 2087 ssl;
    http2 on;           # ← breaks WebSocket
    ...
    location /vless-ws { ... }     # WS needs HTTP/1.1
    location /vless-grpc { ... }   # gRPC needs HTTP/2
}
```

**Fix — Split into 3 server blocks:**
1. **Non-TLS block** (80, 8080, 8880, 2086) — WS + HttpUpgrade + XHTTP only. Remove all gRPC locations (gRPC cannot work on plain HTTP).
2. **TLS WebSocket block** (8443) — NO `http2 on`. WS + HttpUpgrade + XHTTP only.
3. **TLS gRPC block** (2083, 2087) — `http2 on`. gRPC locations only.

**Additional fixes in the same file:**
- Remove all `if ($http_upgrade != "Websocket")` checks (lines 176, 219, 240, 286, 329, 350) — case-sensitivity bug ("Websocket" vs "websocket"). MoClaw's working config has no such checks.
- Add `proxy_buffering off` + `proxy_request_buffering off` to ALL XHTTP locations (XHTTP is streaming)
- Add `proxy_read_timeout 86400s` to ALL WS/HttpUpgrade/XHTTP locations (prevents premature connection close)
- Remove gRPC from non-TLS block entirely (lines 211-215, 232-236, 253-257)

### FIX 2: SSL — Migrate from certbot to acme.sh
**File:** `scripts/nginx/install_nginx.sh` (lines 26-76)  
**Root Cause:** All reference scripts (JinGGo, Decode, Darul Itqan, Rerechan) use `acme.sh`, not `certbot`. Certbot conflicts with Nginx on port 80 during renewal.

**Current (broken):**
```bash
# Line 41-46: certbot standalone
certbot certonly --standalone --preferred-challenges http ...
```

**Fix — Replace with acme.sh:**
```bash
curl https://get.acme.sh | sh -s email=admin@${domain}
~/.acme.sh/acme.sh --issue -d ${domain} --standalone --keylength ec-256
~/.acme.sh/acme.sh --install-cert -d ${domain} --ecc \
    --cert-file /etc/xray/xray.crt \
    --key-file /etc/xray/xray.key \
    --fullchain-file /etc/xray/xray.crt \
    --reloadcmd "systemctl reload nginx && systemctl reload xray"
```
- Remove certbot auto-renewal cron (line 72-75)
- acme.sh has its own cron for renewal (auto-installed)
- Keep self-signed fallback (lines 55-69) as backup
- Remove `apt-get install certbot` from `dependencies.sh`

### FIX 3: setup.sh Install Ordering — SSH WS Before Nginx Config
**File:** `setup.sh` (lines 157-164)  
**Root Cause:** `install_nginx_full` is called BEFORE SSH WS installation. When Nginx config is generated, `ssh_ws_installed` flag doesn't exist yet, so the `/ssh` location block is never written. SSH WS clients hit the decoy page (HTTP 200 instead of 101).

**Current order (broken):**
```bash
# Line 157-160: Xray first
install_xray_core
generate_xray_config

# Line 162-164: Nginx second (generates config HERE)
install_nginx_full    # ← generates config, but SSH WS not installed yet

# SSH WS is never installed in setup.sh!
```

**Fix:**
```bash
install_xray_core
generate_xray_config

# Install SSH WS BEFORE Nginx config generation
source "${INSTALL_DIR}/scripts/ssh/install_ssh_ws.sh"
install_ssh_ws

# Then generate Nginx config (will see ssh_ws_installed flag)
install_nginx_full
```

### FIX 4: Firewall Rules During Installation
**File:** `setup.sh` (new section after dependencies)  
**Root Cause:** No iptables/ufw rules are set during installation. Ports appear open but kernel blocks them.

**Fix — Add after dependencies install:**
```bash
# Open all VPN ports
for port in 80 443 8080 8443 8880 2083 2086 2087; do
    iptables -I INPUT -p tcp --dport ${port} -j ACCEPT
done
# Xray internal (localhost only, already allowed)
# Save rules
apt-get install -y iptables-persistent > /dev/null 2>&1
netfilter-persistent save 2>/dev/null
```

### FIX 5: Xray loglevel "warning" → "none"
**File:** `scripts/xray/install_xray.sh` (in `generate_xray_config()`)  
**Root Cause:** With `loglevel: "warning"`, Xray does NOT write accepted connections to `access.log`. The `check_login_users()` function greps `access.log` for user emails, so it always returns zero online users.

**Fix:** In the Xray config JSON generation, change:
```json
"log": { "loglevel": "warning" }
```
to:
```json
"log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "none"
}
```
Note: "none" in Xray means "log everything to files but no console output" — this is how JinGGo and all reference scripts work.

### FIX 6: Ads Blocker — Replace /etc/hosts with dnsmasq
**File:** `scripts/tools/ads_blocker.sh` (lines 12-49)  
**Root Cause:** Appending 82,000+ entries to `/etc/hosts` causes O(n) linear scan per DNS lookup. On a VPN server with multiple users, this causes noticeable latency on ALL connections.

**Fix — Replace with dnsmasq:**
```bash
install_ads_blocker() {
    apt-get install -y dnsmasq
    wget -qO- "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" \
        | grep "^0.0.0.0" | grep -v "0.0.0.0 0.0.0.0" \
        | awk '{print "address=/"$2"/0.0.0.0"}' \
        > /etc/dnsmasq.d/freeflow-ads.conf
    systemctl restart dnsmasq
}
uninstall_ads_blocker() {
    rm -f /etc/dnsmasq.d/freeflow-ads.conf
    systemctl restart dnsmasq
}
```
Also clean up existing /etc/hosts pollution on uninstall:
```bash
sed -i '/# FreeFlow Ads Blocker/,/# FreeFlow Ads Blocker — End/d' /etc/hosts
```

### FIX 7: CF-Aware Setup + Share Links
**Files:** `setup.sh`, `scripts/user/manage_user.sh`  
**Root Cause:** Malaysian/SEA ISPs block direct VPS connections. Users must use Cloudflare CDN as relay. Currently, share links use the VPS IP/domain directly, which doesn't work behind CF CDN.

**Fix in setup.sh — Add one optional question:**
```bash
read -rp " Will you use Cloudflare CDN proxy? [y/N]: " use_cf
if [[ "${use_cf}" =~ ^[Yy] ]]; then
    echo "cloudflare" > "${CONFIG_DIR}/cf_mode"
    # Print CF setup checklist
    echo "REQUIRED Cloudflare settings:"
    echo "  SSL/TLS → Flexible"
    echo "  Network → WebSockets ON"
    echo "  Network → gRPC ON"
    echo "  DNS → A record → Proxied (orange cloud)"
fi
```

**Fix in manage_user.sh — Share link generation:**
```bash
if [[ -f "${CONFIG_DIR}/cf_mode" ]]; then
    # CF mode: address = CF IP, host = domain
    # For non-TLS WS connections through CF
    link="vless://${uuid}@${cf_ip}:80?path=...&type=ws&host=${domain}"
else
    link="vless://${uuid}@${domain}:80?path=...&type=ws&host=${domain}"
fi
```

### FIX 8: REPO_BRANCH → Stable Branch
**Files:** `scripts/core/common.sh` line 9, `setup.sh` line 14  
(Covered in Pre-Requisite section above)

---

## Priority 2 — ORANGE (Should Fix)

### FIX 9: Usage Stats Delta Tracking
**File:** `scripts/user/usage_tracker.sh` (lines 40-82)  
**Root Cause:** `xray api statsquery -reset` is NOT a valid flag. The reset is silently ignored. Every 5-minute cron cycle adds the same cumulative total on top of itself — a user doing 100MB/hour appears to use 1.2GB/hour.

**Fix — Delta tracking:**
```bash
# In record_usage(), after getting up/down:
total=$((up + down))
last=$(cat "${USAGE_DIR}/${username}.xray_last" 2>/dev/null || echo "0")
delta=$((total - last))
[[ "${delta}" -lt 0 ]] && delta="${total}"  # handle xray restart
echo "${total}" > "${USAGE_DIR}/${username}.xray_last"
new_total=$((stored + delta))
```
Remove the broken `xray api statsquery -reset` line (line 81).

### FIX 10: Trial Account Hour Precision
**File:** `scripts/user/manage_user.sh` line 574  
**Root Cause:** `date -d "+${minutes} minutes" +"%Y-%m-%d"` strips the time. A 1-hour trial created at 11PM stores tomorrow's date and lasts up to 25 hours.

**Fix:**
```bash
# Line 574: Add time
expiry=$(date -d "+${minutes} minutes" +"%Y-%m-%d %H:%M")

# Update is_expired() to compare datetime:
is_expired() {
    local expiry_date="$1"
    local now=$(date +"%Y-%m-%d %H:%M")
    [[ "${now}" > "${expiry_date}" ]]
}
```

### FIX 11: Add delete_warp_route() Function
**File:** `scripts/warp/install_warp.sh`  
**Root Cause:** Menu option 4 calls `delete_warp_route` but the function doesn't exist → `bash: delete_warp_route: command not found`

**Fix — Add function:**
```bash
delete_warp_route() {
    print_section "Remove WARP Domain Route"
    [[ ! -f "${WARP_CONFIG}/domains" ]] && { msg_warn "No domains configured"; return; }
    cat -n "${WARP_CONFIG}/domains"
    read -rp " Line number to remove: " line_num
    sed -i "${line_num}d" "${WARP_CONFIG}/domains"
    msg_ok "Domain removed"
}
```

### FIX 12: Telegram Bot Reactivate — Re-Add UUID to Xray
**File:** `scripts/telegram/setup_bot.sh` (in `handle_days()` react_ branch)  
**Root Cause:** Shell menu reactivate correctly moves file + re-adds UUID to Xray config + restarts xray. But Telegram bot reactivate only moves the file — UUID is not added back to Xray config.

**Fix:** After `mv expired→active` in the bot handler, add jq command to re-add UUID to Xray config (copy the same logic from `reactivate_protocol_user()` in `manage_user.sh`).

### FIX 13: Post-Install Verify Script
**File:** New file `scripts/core/verify.sh`  
**Purpose:** Run after installation to check every layer and catch issues immediately.

**Checks:**
```bash
verify_installation() {
    echo "=== FreeFlow Post-Install Verification ==="
    # 1. DNS: domain resolves to this server's IP
    # 2. Nginx: systemctl is-active nginx
    # 3. Xray: systemctl is-active xray
    # 4. SSL: openssl s_client -connect domain:8443
    # 5. Ports: test WS upgrade on 80, 8080, 8443
    # 6. Xray config: jq empty /etc/xray/config.json
    # 7. Firewall: iptables -L INPUT | grep VPN ports
    # 8. Generate test share link and print
}
```

---

## Priority 3 — YELLOW (Nice to Fix)

### FIX 14: Backup tar Command
**File:** `scripts/menu/menu.sh` (in `backup_restore_menu()`)  
**Root Cause:** `tar r` (append) does NOT work on gzip archives. Config files are silently missing from backups.

**Fix:** Single `tar czf` with all paths:
```bash
tar czf "${backup_file}" \
    -C "${DATA_DIR}" users/ usage/ \
    -C "${CONFIG_DIR}" domain paths.conf default_uuid 2>/dev/null
```

### FIX 15: WARP Debian 13 Fix
**File:** `scripts/warp/install_warp.sh` (lines 27-29)  
**Root Cause:** `lsb_release` not installed on Debian 13 (trixie). Falls back to "bullseye" → wrong packages.

**Fix:**
```bash
codename=$(. /etc/os-release && echo "${VERSION_CODENAME}")
[[ "${OS_NAME}" == "debian" && "${OS_VERSION}" -ge 13 ]] && codename="bookworm"
```

### FIX 16: Bot Token Security
**File:** `scripts/telegram/setup_bot.sh` (systemd service file generation)  
**Root Cause:** Bot token visible in plaintext via `systemctl show freeflow-bot`

**Fix:**
```bash
echo "BOT_TOKEN=${bot_token}" > /etc/freeflow/telegram/bot.env
chmod 600 /etc/freeflow/telegram/bot.env
# In service: EnvironmentFile=/etc/freeflow/telegram/bot.env
```

### FIX 17: SSH WS Proxy — Replace with websockify
**File:** `scripts/ssh/install_ssh_ws.sh`  
**Root Cause:** Custom Python proxy sends 101 upgrade then relays raw bytes, but WS data has frame headers + XOR masking. SSH daemon receives garbled data with standard SSH-WS tools.

**Fix:**
```bash
pip3 install websockify
# Service ExecStart: /usr/bin/websockify 127.0.0.1:700 127.0.0.1:22
```

---

## Priority 4 — GREEN (Enhancements)

### FIX 18: SSH Auto-Kill Implementation
**File:** `scripts/menu/menu.sh` (in `ssh_auto_kill()`)  
**Root Cause:** Current code is a literal placeholder that prints "Auto-kill enabled" but does nothing.

### FIX 19: Reality Destination Configurable
**File:** `scripts/xray/install_xray.sh`  
**Purpose:** Allow users in censored regions to change Reality destination (currently hardcoded to `www.google.com`).

---

## Files Changed Summary

| File | Changes |
|------|---------|
| `setup.sh` | REPO_BRANCH fix, install ordering, firewall rules, CF-aware prompt |
| `scripts/core/common.sh` | REPO_BRANCH fix |
| `scripts/nginx/install_nginx.sh` | Complete nginx config rewrite (3 blocks), acme.sh migration |
| `scripts/xray/install_xray.sh` | loglevel fix, Reality destination |
| `scripts/user/manage_user.sh` | Trial expiry precision, CF-aware share links |
| `scripts/user/usage_tracker.sh` | Delta tracking, remove broken -reset |
| `scripts/tools/ads_blocker.sh` | Replace /etc/hosts with dnsmasq |
| `scripts/warp/install_warp.sh` | delete_warp_route(), Debian 13 codename |
| `scripts/telegram/setup_bot.sh` | Reactivate UUID fix, bot token security |
| `scripts/ssh/install_ssh_ws.sh` | websockify replacement |
| `scripts/menu/menu.sh` | Backup tar fix, SSH auto-kill, CF guide |
| `scripts/core/verify.sh` | NEW — post-install verification |

---

## What Works Well — Don't Change (per MoClaw)

- Nginx + Xray split architecture (design is correct)
- Shell menu user management (add/delete/expire/reactivate)
- Per-user UUID + email tagging in Xray
- jq-based Xray config manipulation
- Multiple protocol support (VLESS/VMESS/Trojan + Reality)
- Xray Stats API design (just needs delta fix)
- WARP domain routing via Xray outbound
- Telegram bot inline keyboard UI
- Backup to Telegram feature
- Trial account system

---

## Execution Order (when Ahmad approves)

1. **Pre-req:** Merge to stable branch, fix REPO_BRANCH
2. **FIX 1:** Nginx config rewrite (highest impact — makes WS actually work)
3. **FIX 2:** acme.sh migration (fixes SSL properly)
4. **FIX 3:** setup.sh ordering (SSH WS before Nginx)
5. **FIX 4:** Firewall rules
6. **FIX 5:** Xray loglevel
7. **FIX 6:** Ads blocker → dnsmasq
8. **FIX 7:** CF-aware setup + share links
9. **FIX 13:** Post-install verify script
10. **FIX 9-12:** Orange priority fixes
11. **FIX 14-17:** Yellow priority fixes
12. **FIX 18-19:** Green enhancements

After each group, push and test on VPS before proceeding.
