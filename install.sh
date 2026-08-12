#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$ROOT"

export TERM="${TERM:-xterm-256color}"

AUTO=false
DRY_RUN=false

usage() {
    cat <<EOF
os-configs — post-install setup

Usage: install.sh [OPTIONS]

Options:
  --auto       Non-interactive (keep detected platform, pick first preset)
  --dry-run    Detect + menu flow only (no system changes)
  --help       Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto) AUTO=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
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
source "${ROOT}/lib/presets.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/flow.sh"

os_configs_detect

clear || true

if [[ "$DRY_RUN" == "true" ]]; then
    ui_style_subheader "(dry-run — no system changes)"
fi

flow_run_entry "$([[ "$AUTO" == "true" ]] && echo true || echo false)"
