#!/usr/bin/env bash
set -euo pipefail

_postlogin_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_postlogin_repo="${REPO_ROOT:-$(cd "${_postlogin_lib_dir}/.." && pwd)}"

POSTLOGIN_SERVICE_NAME="os-configs-postlogin.service"
POSTLOGIN_SCRIPT="${HOME}/.local/bin/os-configs-postlogin"
POSTLOGIN_UNIT="${HOME}/.config/systemd/user/${POSTLOGIN_SERVICE_NAME}"
POSTLOGIN_STATE="${HOME}/.cache/os-configs/postlogin.env"

postlogin_platform_eligible() {
    [[ "$PLATFORM_CLASS" == "desktop" || "$PLATFORM_CLASS" == "laptop" ]]
}

postlogin_self_remove() {
    systemctl --user disable "$POSTLOGIN_SERVICE_NAME" &>/dev/null || true
    rm -f "$POSTLOGIN_UNIT" "$POSTLOGIN_SCRIPT" "$POSTLOGIN_STATE"
    systemctl --user daemon-reload &>/dev/null || true
}

postlogin_write_runner() {
    local repo_root="$1"

    mkdir -p "$(dirname "$POSTLOGIN_SCRIPT")" "$(dirname "$POSTLOGIN_STATE")"

    cat >"$POSTLOGIN_STATE" <<EOF
REPO_ROOT=${repo_root}
EOF

    cat >"$POSTLOGIN_SCRIPT" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

STATE="${HOME}/.cache/os-configs/postlogin.env"
# shellcheck source=/dev/null
[[ -f "$STATE" ]] && source "$STATE"

cleanup() {
    systemctl --user disable os-configs-postlogin.service &>/dev/null || true
    rm -f "${HOME}/.config/systemd/user/os-configs-postlogin.service"
    rm -f "${HOME}/.local/bin/os-configs-postlogin"
    rm -f "$STATE"
    systemctl --user daemon-reload &>/dev/null || true
}
trap cleanup EXIT

export TERM="${TERM:-xterm-256color}"
export PATH="${HOME}/.local/bin:${HOME}/.bun/bin:/home/linuxbrew/.linuxbrew/bin:/opt/homebrew/bin:${PATH}"

cd "${REPO_ROOT:?REPO_ROOT missing from postlogin state}"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/deps.sh"
os_configs_ensure_deps
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/detect.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/tui.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/ui.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/registry.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/presets.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/dewm.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/custom.sh"
# shellcheck source=/dev/null
source "${REPO_ROOT}/lib/confirm.sh"

os_configs_detect

ui_style_header "os-configs"
ui_style_subheader "Optional extras after reboot"

if gum confirm "Install additional software?"; then
    INSTALL_MODE="custom"
    export INSTALL_MODE
    custom_run_selection false
    custom_show_summary
    confirm_custom_install "$SELECTED_CUSTOM_FILE" false false
else
    gum style --foreground 245 "Skipped additional software."
fi
EOF

    chmod +x "$POSTLOGIN_SCRIPT"
}

postlogin_write_unit() {
    mkdir -p "$(dirname "$POSTLOGIN_UNIT")"

    cat >"$POSTLOGIN_UNIT" <<EOF
[Unit]
Description=os-configs one-shot post-login prompt
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=oneshot
ExecStart=${POSTLOGIN_SCRIPT}
Environment=TERM=xterm-256color

[Install]
WantedBy=graphical-session.target
EOF
}

postlogin_install_service() {
    local dry_run="${1:-false}"
    local repo_root="${2:-$_postlogin_repo}"

    if ! postlogin_platform_eligible; then
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        gum style --foreground 245 "(dry-run) would install post-login one-shot service"
        gum style "  script: ${POSTLOGIN_SCRIPT}"
        gum style "  unit:   ${POSTLOGIN_UNIT}"
        return 0
    fi

    if ! command -v systemctl &>/dev/null; then
        gum style --foreground 245 "systemd not available — skipping post-login service"
        return 0
    fi

    postlogin_write_runner "$repo_root"
    postlogin_write_unit
    systemctl --user daemon-reload
    systemctl --user enable "$POSTLOGIN_SERVICE_NAME"
    gum style --foreground 10 "Post-login prompt scheduled (runs once on next graphical login)."
}

postlogin_run_test() {
    local repo_root="${1:-$_postlogin_repo}"

    postlogin_self_remove
    postlogin_write_runner "$repo_root"
    postlogin_write_unit
    [[ -x "$POSTLOGIN_SCRIPT" && -f "$POSTLOGIN_UNIT" ]]
}
