#!/bin/bash
# ============================================================
# FreeFlow ASVPN - Auto Update System
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../core/common.sh"

INSTALL_DIR="/usr/local/lib/freeflow"
UPDATE_LOG="${LOG_DIR}/update.log"

# --- Check for Updates ---
check_update() {
    print_section "Checking for Updates"

    local current_version
    current_version=$(get_installed_version)
    msg_info "Current version: ${current_version}"

    # Fetch latest version from repo
    local remote_version
    remote_version=$(curl -sL "${REPO_RAW}/VERSION" 2>/dev/null)

    if [[ -z "${remote_version}" ]]; then
        msg_fail "Could not reach update server"
        return 1
    fi

    msg_info "Latest version: ${remote_version}"

    if [[ "${current_version}" == "${remote_version}" ]]; then
        msg_ok "Already running the latest version"
        return 0
    else
        msg_warn "Update available: ${current_version} → ${remote_version}"
        return 2
    fi
}

# --- Perform Update ---
do_update() {
    print_section "Updating FreeFlow ASVPN"

    local current_version
    current_version=$(get_installed_version)

    msg_info "Downloading latest version..."

    # Create temp directory for download
    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Download the latest release
    if ! wget -q "${REPO_URL}/archive/refs/heads/${REPO_BRANCH}.tar.gz" -O "${tmp_dir}/update.tar.gz"; then
        msg_fail "Download failed"
        rm -rf "${tmp_dir}"
        return 1
    fi

    # Extract — GitHub replaces / with - in archive directory names
    cd "${tmp_dir}" || return 1
    tar xzf update.tar.gz
    local branch_sanitized
    branch_sanitized=$(echo "${REPO_BRANCH}" | tr '/' '-')
    local extract_dir="${tmp_dir}/${REPO_NAME}-${branch_sanitized}"

    if [[ ! -d "${extract_dir}" ]]; then
        # Fallback: find the extracted directory
        extract_dir=$(find "${tmp_dir}" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -1)
        if [[ -z "${extract_dir}" ]]; then
            msg_fail "Extraction failed"
            rm -rf "${tmp_dir}"
            return 1
        fi
    fi

    # Backup current installation
    msg_info "Backing up current installation..."
    local backup_dir="${DATA_DIR}/backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "${backup_dir}"
    cp -r "${INSTALL_DIR}/scripts" "${backup_dir}/" 2>/dev/null

    # Update scripts
    msg_info "Installing new scripts..."
    mkdir -p "${INSTALL_DIR}"
    cp -rf "${extract_dir}/scripts/"* "${INSTALL_DIR}/scripts/"
    chmod +x "${INSTALL_DIR}/scripts/"*/*.sh

    # Update setup.sh
    if [[ -f "${extract_dir}/setup.sh" ]]; then
        cp -f "${extract_dir}/setup.sh" "${INSTALL_DIR}/setup.sh"
        chmod +x "${INSTALL_DIR}/setup.sh"
    fi

    # Update menu
    if [[ -f "${extract_dir}/scripts/menu/menu.sh" ]]; then
        cp -f "${extract_dir}/scripts/menu/menu.sh" /usr/local/bin/freeflow
        chmod +x /usr/local/bin/freeflow
        # Also link to 'menu' command
        ln -sf /usr/local/bin/freeflow /usr/local/bin/menu 2>/dev/null
    fi

    # Update version
    local new_version
    new_version=$(cat "${extract_dir}/VERSION" 2>/dev/null || echo "unknown")
    set_version "${new_version}"

    # Cleanup
    rm -rf "${tmp_dir}"

    # Restart services
    msg_info "Restarting services..."
    restart_service xray
    restart_service nginx

    echo "[$(date)] Updated ${current_version} → ${new_version}" >> "${UPDATE_LOG}"

    msg_ok "Updated to version ${new_version}"
    msg_info "Previous version backed up to: ${backup_dir}"
}

# --- Auto Update (for cron) ---
auto_update() {
    check_update
    local status=$?

    if [[ "${status}" -eq 2 ]]; then
        echo "[$(date)] Auto-update: new version available, updating..." >> "${UPDATE_LOG}"
        do_update
    fi
}

# --- Setup Auto Update Cron ---
setup_auto_update_cron() {
    print_section "Auto Update Configuration"

    echo -e " ${BOLD}Auto Update Options${NC}"
    echo -e " 1. Enable auto-update (check daily at 4 AM)"
    echo -e " 2. Disable auto-update"
    echo -e " 3. Back"
    echo ""
    read -rp " Choose: " choice

    case "${choice}" in
        1)
            local cron_cmd="0 4 * * * /bin/bash ${INSTALL_DIR}/scripts/update/auto_update.sh auto >> ${UPDATE_LOG} 2>&1"
            # Remove existing auto-update cron
            crontab -l 2>/dev/null | grep -v "auto_update.sh" | crontab -
            # Add new
            (crontab -l 2>/dev/null; echo "${cron_cmd}") | crontab -
            msg_ok "Auto-update enabled (daily at 4 AM)"
            ;;
        2)
            crontab -l 2>/dev/null | grep -v "auto_update.sh" | crontab -
            msg_ok "Auto-update disabled"
            ;;
        3) return ;;
    esac
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    check_root
    case "${1}" in
        check) check_update ;;
        update) do_update ;;
        auto) auto_update ;;
        cron) setup_auto_update_cron ;;
        *)
            check_update
            update_status=$?
            if [[ "${update_status}" -eq 2 ]]; then
                if confirm "Update now?"; then
                    do_update
                fi
            fi
            ;;
    esac
fi
