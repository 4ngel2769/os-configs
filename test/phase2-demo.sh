#!/usr/bin/env bash
# Phase 2 checkpoint — static preset-list demo (no install logic).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"

export TERM="${TERM:-xterm-256color}"

# shellcheck source=/dev/null
source "$ROOT/lib/deps.sh"
os_configs_ensure_deps

# shellcheck source=/dev/null
source "$ROOT/lib/ui.sh"

export DISTRO_ID="${DISTRO_ID:-ubuntu}"
export DISTRO_FAMILY="${DISTRO_FAMILY:-ubuntu}"

AUTO=false
if [[ "${1:-}" == "--auto" ]]; then
    AUTO=true
fi

clear || true

ui_style_header "os-configs"
ui_style_subheader "Post-install setup · static Phase 2 demo"
ui_style_divider

badge="$(ui_distro_badge)"
ui_style_subheader "Detected distro: ${badge}"

ui_style_divider
ui_style_header "Server presets"

options=(
    "Server Minimal"
    "Server Clean"
    "Server Everything"
    "Custom"
)

if [[ "$AUTO" == "true" ]]; then
    choice="${options[0]}"
    gum style --foreground 245 "(auto) selected first preset"
else
    choice="$(gum choose "${options[@]}")"
fi

ui_style_divider
gum style --foreground 245 "Selected: ${choice}"
gum style --margin "1 0 0 0" --foreground 240 "(demo only — no install ran)"
