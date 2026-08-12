#!/usr/bin/env bash
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ui_colors_file="${_lib_dir}/../data/distro-colors.json"

ui_require_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi
    echo "ui: gum is required but not installed (https://github.com/charmbracelet/gum)" >&2
    return 1
}

ui_platform_label() {
    case "${1,,}" in
        laptop) echo "Laptop" ;;
        desktop) echo "Desktop" ;;
        server) echo "Server" ;;
        *) echo "$1" ;;
    esac
}

ui_gpu_label() {
    case "${1,,}" in
        igpu-gaming) echo "Gaming capable iGPU" ;;
        igpu-basic) echo "Basic iGPU" ;;
        dgpu) echo "Dedicated Graphics" ;;
        none) echo "No GPU detected" ;;
        *) echo "$1" ;;
    esac
}

ui_platform_pick() {
    local picked

    ui_require_gum || return 1
    picked="$(gum choose "Server" "Desktop" "Laptop")"

    case "$picked" in
        Server) echo "server" ;;
        Desktop) echo "desktop" ;;
        Laptop) echo "laptop" ;;
        *)
            echo "ui: unknown platform choice '${picked}'" >&2
            return 1
            ;;
    esac
}

ui_style_header() {
    ui_require_gum || return 1
    gum style --bold --margin "1 0 0 0" "$@"
}

ui_style_subheader() {
    ui_require_gum || return 1
    gum style --foreground 245 "$@"
}

ui_style_divider() {
    ui_require_gum || return 1
    gum style --foreground 240 "────────────────────────────────────────────────"
}

ui_style() {
    ui_require_gum || return 1
    gum style "$@"
}

ui_confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-true}"

    ui_require_gum || return 1

    if [[ "$default" == "true" ]]; then
        gum confirm "$prompt"
    else
        gum confirm --default=false "$prompt"
    fi
}

ui_menu() {
    local multi=false

    if [[ "${1:-}" == "--multi" ]]; then
        multi=true
        shift
    fi

    local header="${1:-}"
    shift || true

    ui_require_gum || return 1

    if [[ -n "$header" ]]; then
        ui_style_header "$header"
    fi

    if [[ "$multi" == "true" ]]; then
        gum choose --no-limit "$@"
    else
        gum choose "$@"
    fi
}

ui_spin() {
    local title="$1"
    shift

    ui_require_gum || return 1
    gum spin --spinner dot --title "$title" -- "$@"
}

ui_distro_color() {
    local distro_id="${1:-${DISTRO_ID:-unknown}}"
    local family="${2:-${DISTRO_FAMILY:-}}"

    if [[ ! -f "$_ui_colors_file" ]]; then
        echo "ui: color map not found: $_ui_colors_file" >&2
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo "ui: jq is required for ui_distro_color" >&2
        return 1
    fi

    jq -r --arg id "${distro_id,,}" --arg family "${family,,}" '
        .ids[$id] // .family_defaults[$family] // "#CCCCCC"
    ' "$_ui_colors_file"
}

ui_distro_label() {
    local distro_id="${1:-${DISTRO_ID:-unknown}}"

    case "${distro_id,,}" in
        pop | pop-os) echo "Pop!_OS" ;;
        linuxmint) echo "Linux Mint" ;;
        endeavouros) echo "EndeavourOS" ;;
        *) echo "${distro_id^}" ;;
    esac
}

ui_distro_badge() {
    local distro_id="${1:-${DISTRO_ID:-unknown}}"
    local family="${2:-${DISTRO_FAMILY:-}}"
    local label="${3:-}"

    ui_require_gum || return 1

    [[ -n "$label" ]] || label="$(ui_distro_label "$distro_id")"

    local color
    color="$(ui_distro_color "$distro_id" "$family")"

    gum style --foreground "$color" "$label"
}

ui_format_preset_row() {
    local preset_name="$1"
    local distro_id="${2:-${DISTRO_ID:-unknown}}"
    local family="${3:-${DISTRO_FAMILY:-}}"

    ui_require_gum || return 1

    local badge
    badge="$(ui_distro_badge "$distro_id" "$family")"
    printf '%s  %s\n' "$preset_name" "$badge"
}
