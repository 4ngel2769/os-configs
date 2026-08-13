#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$ROOT"

export TERM="${TERM:-xterm-256color}"

AUTO=false
DRY_RUN=false
SKIP_DOTFILES=false
SKIP_POSTLOGIN=false
SKIP_REBOOT=false
VALIDATE_USER=false

usage() {
    cat <<EOF
os-configs — post-install setup

Usage: install.sh [OPTIONS]

Run from a git clone, or use bootstrap.sh via curl/wget (see README).

Options:
  --auto              Non-interactive (keep detected platform, pick first preset)
  --dry-run           Full flow + confirmation preview (no system changes)
  --skip-dotfiles     Skip dotfiles backup and deploy
  --skip-postlogin    Skip post-login one-shot service
  --skip-reboot       Skip reboot prompt at end
  --validate-user     Validate data/user/registry.json and exit
  --ask-de-wm         Prompt for DE/WM and display manager (default: use preset/config defaults)
  --help              Show this help

Environment:
  OS_CONFIGS_ASK_DE_WM=1   Same as --ask-de-wm
  OS_CONFIGS_FORCE_PLATFORM  Override detected platform (server|desktop|laptop; testing)

Adding apps: see ADD-APPS.md
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-dotfiles) SKIP_DOTFILES=true; shift ;;
        --skip-postlogin) SKIP_POSTLOGIN=true; shift ;;
        --skip-reboot) SKIP_REBOOT=true; shift ;;
        --validate-user) VALIDATE_USER=true; shift ;;
        --ask-de-wm) export OS_CONFIGS_ASK_DE_WM=1; shift ;;
        --help | -h)
            usage
            exit 0
            ;;
        *)
            echo "install.sh: unknown option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# shellcheck source=/dev/null
source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps

# shellcheck source=/dev/null
source "${ROOT}/lib/detect.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/ui.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/registry.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/picker.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/presets.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/dewm.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/custom.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/confirm.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/flow.sh"

os_configs_detect

export OS_CONFIGS_DRY_RUN="$DRY_RUN"
export OS_CONFIGS_AUTO="$AUTO"
export OS_CONFIGS_SKIP_DOTFILES="$SKIP_DOTFILES"
export OS_CONFIGS_SKIP_POSTLOGIN="$SKIP_POSTLOGIN"
export OS_CONFIGS_SKIP_REBOOT="$SKIP_REBOOT"

if [[ "$VALIDATE_USER" == "true" ]]; then
    registry_validate_user
    exit $?
fi

clear || true

if [[ "$DRY_RUN" == "true" ]]; then
    ui_style_subheader "(dry-run — no system changes)"
fi

flow_run_entry "$([[ "$AUTO" == "true" ]] && echo true || echo false)"
