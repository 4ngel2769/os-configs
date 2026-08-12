#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$ROOT"

export TERM="${TERM:-xterm-256color}"

AUTO=false
DRY_RUN=false
SKIP_DOTFILES=false
VALIDATE_USER=false

usage() {
    cat <<EOF
os-configs — post-install setup

Usage: install.sh [OPTIONS]

Options:
  --auto              Non-interactive (keep detected platform, pick first preset)
  --dry-run           Full flow + confirmation preview (no system changes)
  --skip-dotfiles     Skip dotfiles backup and deploy
  --validate-user     Validate data/user/registry.json and exit
  --ask-de-wm         Prompt for DE/WM and display manager (default: use preset/config defaults)
  --help              Show this help

Environment:
  OS_CONFIGS_ASK_DE_WM=1   Same as --ask-de-wm

User packages:
  Copy data/user/registry.example.json   → data/user/registry.json
  Copy data/user/categories.example.json → data/user/categories.json
  Edit simple-names, per-distro package names, or github entries. See examples in those files.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --skip-dotfiles) SKIP_DOTFILES=true; shift ;;
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

if [[ "$VALIDATE_USER" == "true" ]]; then
    registry_validate_user
    exit $?
fi

clear || true

if [[ "$DRY_RUN" == "true" ]]; then
    ui_style_subheader "(dry-run — no system changes)"
fi

flow_run_entry "$([[ "$AUTO" == "true" ]] && echo true || echo false)"
