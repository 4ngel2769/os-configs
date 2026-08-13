#!/usr/bin/env bash
set -euo pipefail

_finish_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${_finish_lib_dir}/postlogin.sh"

finish_run() {
    local auto="${1:-false}"
    local dry_run="${2:-false}"
    local skip_postlogin="${3:-false}"
    local skip_reboot="${4:-false}"
    local repo_root="${REPO_ROOT:-$(cd "${_finish_lib_dir}/.." && pwd)}"

    ui_style_divider
    ui_style_header "All done"

    if [[ -n "${DOTFILES_BACKUP_PATH:-}" ]]; then
        gum style "Dotfiles backup: ${DOTFILES_BACKUP_PATH}"
    fi

    if [[ "$skip_postlogin" != "true" ]]; then
        postlogin_install_service "$dry_run" "$repo_root"
    fi

    if [[ "$dry_run" == "true" || "$skip_reboot" == "true" ]]; then
        gum style --foreground 245 "Reboot skipped."
        return 0
    fi

    if [[ "$auto" == "true" ]]; then
        ui_style_subheader "(auto) reboot deferred — run sudo reboot when ready"
        return 0
    fi

    if ui_confirm "Reboot now?"; then
        ui_style_subheader "Rebooting..."
        sudo reboot
    else
        gum style --foreground 245 "Reboot deferred."
    fi
}
