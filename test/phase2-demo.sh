#!/usr/bin/env bash
# Phase 2 checkpoint — static preset-list demo (no install logic).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/lib/ui.sh"

export DISTRO_ID="${DISTRO_ID:-ubuntu}"
export DISTRO_FAMILY="${DISTRO_FAMILY:-ubuntu}"

ui_require_gum

clear || true

ui_style_header "os-configs"
ui_style_subheader "Post-install setup · static Phase 2 demo"
ui_style_divider

badge="$(ui_distro_badge)"
ui_style_subheader "Detected distro: ${badge}"

ui_style_divider
ui_style_header "Server presets"

options=(
    "$(ui_format_preset_row "Server Minimal")"
    "$(ui_format_preset_row "Server Clean")"
    "$(ui_format_preset_row "Server Everything")"
    "Custom"
)

choice="$(gum choose "${options[@]}")"

ui_style_divider
gum style --foreground 245 "Selected: ${choice}"
gum style --margin "1 0 0 0" --foreground 240 "(demo only — no install ran)"
