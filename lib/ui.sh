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

ui_term_width() {
    local w="${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}"
    if [[ "$w" -lt 40 ]]; then
        w=40
    elif [[ "$w" -gt 120 ]]; then
        w=120
    fi
    printf '%s' "$w"
}

ui_divider_line() {
    local w chars
    w="$(ui_term_width)"
    chars=$((w - 4))
    if [[ "$chars" -lt 20 ]]; then
        chars=20
    fi
    printf '─%.0s' $(seq 1 "$chars")
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
    local picked items_json

    items_json='[
        {"id":"server","label":"Server"},
        {"id":"desktop","label":"Desktop"},
        {"id":"laptop","label":"Laptop"}
    ]'

    if picked="$(ui_picker_menu_list "Platform" "Override detected platform" "$items_json")"; then
        printf '%s' "$picked"
        return 0
    fi

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
    gum style --bold --align center --width "$(ui_term_width)" --margin "1 0 0 0" "$@"
}

ui_style_subheader() {
    ui_require_gum || return 1
    gum style --align center --width "$(ui_term_width)" --foreground 245 "$@"
}

ui_style_divider() {
    ui_require_gum || return 1
    gum style --align center --width "$(ui_term_width)" --foreground 240 "$(ui_divider_line)"
}

ui_style_centered() {
    ui_require_gum || return 1
    gum style --align center --width "$(ui_term_width)" "$@"
}

ui_style() {
    ui_require_gum || return 1
    gum style "$@"
}

ui_picker_can_run() {
    picker_can_run
}

ui_picker_menu_list() {
    local title="$1"
    local subtitle="${2:-}"
    local items_json="$3"
    local input_file result_file choice

    if ! ui_picker_can_run; then
        return 1
    fi

    input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-in.XXXXXX")"
    result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-out.XXXXXX")"

    jq -n \
        --argjson banner "$(picker_banner_json)" \
        --arg title "$title" \
        --arg subtitle "$subtitle" \
        --argjson items "$items_json" \
        '{
            banner: $banner,
            mode: "list",
            title: $title,
            subtitle: $subtitle,
            items: $items
        }' >"$input_file"

    if menu_picker_run "$result_file" "$input_file"; then
        choice="$(jq -r '.choice // empty' "$result_file")"
        rm -f "$input_file" "$result_file"
        if [[ -n "$choice" ]]; then
            printf '%s' "$choice"
            return 0
        fi
    fi

    rm -f "$input_file" "$result_file"
    return 1
}

ui_picker_menu_confirm() {
    local message="$1"
    local default="${2:-true}"
    local title="${3:-}"
    local body="${4:-}"
    local input_file result_file confirmed

    if ! ui_picker_can_run; then
        return 1
    fi

    input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-in.XXXXXX")"
    result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-out.XXXXXX")"

    jq -n \
        --argjson banner "$(picker_banner_json)" \
        --arg mode "confirm" \
        --arg title "${title:-Confirm}" \
        --arg message "$message" \
        --arg body "$body" \
        --argjson default_yes "$( [[ "$default" == "true" ]] && echo true || echo false )" \
        '{
            banner: $banner,
            mode: "confirm",
            title: $title,
            body: $body,
            message: $message,
            default_yes: $default_yes
        }' >"$input_file"

    if menu_picker_run "$result_file" "$input_file"; then
        confirmed="$(jq -r '.confirmed // false' "$result_file")"
        rm -f "$input_file" "$result_file"
        [[ "$confirmed" == "true" ]]
        return $?
    fi

    rm -f "$input_file" "$result_file"

    ui_require_gum || return 1
    if [[ -n "$body" ]]; then
        ui_panel "$title" "$body"
    fi
    if [[ "$default" == "true" ]]; then
        gum confirm "$message"
    else
        gum confirm --default=false "$message"
    fi
}

ui_picker_menu_info() {
    local title="$1"
    local body="$2"
    local input_file result_file

    if ! ui_picker_can_run; then
        return 1
    fi

    input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-in.XXXXXX")"
    result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-out.XXXXXX")"

    jq -n \
        --argjson banner "$(picker_banner_json)" \
        --arg title "$title" \
        --arg body "$body" \
        '{
            banner: $banner,
            mode: "info",
            title: $title,
            body: $body
        }' >"$input_file"

    if menu_picker_run "$result_file" "$input_file"; then
        rm -f "$input_file" "$result_file"
        return 0
    fi

    rm -f "$input_file" "$result_file"
    return 1
}

ui_confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-true}"

    if ui_picker_menu_confirm "$prompt" "$default"; then
        return 0
    fi

    ui_require_gum || return 1

    if [[ "$default" == "true" ]]; then
        gum confirm "$prompt"
    else
        gum confirm --default=false "$prompt"
    fi
}

# Bordered panel for dependency lists and similar summaries.
ui_panel() {
    local title="$1"
    local body="$2"
    local width

    width="$(ui_term_width)"

    if command -v gum &>/dev/null; then
        gum style \
            --align left \
            --width "$width" \
            --border rounded \
            --border-foreground 86 \
            --padding "1 2" \
            --margin "1 0" \
            "$(printf '%s\n\n%s' "$title" "$body")"
        return 0
    fi

    printf '\n┌ %s\n' "$title"
    printf '%s\n' "$body" | sed 's/^/│ /'
    printf '└────────────────────────────────\n\n'
}

ui_confirm_plain() {
    local prompt="${1:-Continue?}"
    local answer

    printf '%s [Y/n] ' "$prompt"
    read -r answer
    [[ "${answer:-Y}" =~ ^[Yy]?$ ]]
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

ui_show_banner() {
    local badge platform_label color width

    ui_require_gum || return 1
    badge="$(ui_distro_label)"
    color="$(ui_distro_color)"
    platform_label="$(ui_platform_label "${PLATFORM_CLASS:-desktop}")"
    width="$(ui_term_width)"

    gum style --bold --align center --width "$width" --margin "1 0" "os-configs"
    gum style --align center --width "$width" --foreground 245 "Post-install setup"
    ui_style_divider
    gum style --align center --width "$width" --foreground "$color" "/ ${badge} · ${platform_label} \\"
    ui_style_divider
}
