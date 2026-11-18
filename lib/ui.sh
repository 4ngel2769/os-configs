#!/usr/bin/env bash
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_ui_colors_file="${_lib_dir}/../data/distro-colors.json"

UI_STEP="${UI_STEP:-0}"
UI_TOTAL="${UI_TOTAL:-0}"
UI_NAV=""
UI_FLOW_CHOICE=""
UI_FLOW_BACK="false"
UI_CONFIRM_RESULT=""

# One page renderer for every interactive decision. Falls back to gum prompts.
ui_picker_flow() {
    local title="$1"
    local subtitle="${2:-}"
    local body="${3:-}"
    local items_json="${4:-[]}"
    local multi="${5:-false}"
    local default_id="${6:-}"
    local back_label="${7:-}"
    local continue_label="${8:-}"
    local input_file result_file

    UI_FLOW_CHOICE=""
    UI_FLOW_BACK="false"
    if ! picker_can_run; then
        return 1
    fi

    input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-flow-in.XXXXXX")"
    result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-flow-out.XXXXXX")"

    jq -n \
        --argjson banner "$(picker_banner_json)" \
        --argjson step "$UI_STEP" \
        --argjson total "$UI_TOTAL" \
        --arg title "$title" \
        --arg subtitle "$subtitle" \
        --arg body "$body" \
        --argjson items "$items_json" \
        --argjson multi "$multi" \
        --arg default_id "$default_id" \
        --arg back_label "$back_label" \
        --arg continue_label "$continue_label" \
        '{banner: $banner, step: $step, total: $total, title: $title,
          subtitle: $subtitle, body: $body, items: $items, multi: $multi,
          default_id: $default_id, show_back: ($step > 1),
          back_label: $back_label, continue_label: $continue_label}' >"$input_file"

    if flow_picker_run "$result_file" "$input_file"; then
        UI_FLOW_CHOICE="$(jq -r '.choice // empty' "$result_file")"
        UI_FLOW_BACK="$(jq -r '.back // false' "$result_file")"
        [[ "$UI_FLOW_BACK" == "true" ]] && UI_NAV="back"
        rm -f "$input_file" "$result_file"
        return 0
    fi
    rm -f "$input_file" "$result_file"
    return 1
}

ui_picker_list() {
    local title="$1"
    local subtitle="${2:-}"
    local items_json="${3:-[]}"
    local default_id="${4:-}"

    if ui_picker_flow "$title" "$subtitle" "" "$items_json" false "$default_id"; then
        [[ "$UI_FLOW_BACK" == "true" ]] && return 2
        printf '%s' "$UI_FLOW_CHOICE"
        return 0
    fi
    return 1
}

# Result in UI_CONFIRM_RESULT: yes | no | back
ui_flow_confirm() {
    local title="$1"
    local yes_label="${2:-$(tui_str confirm_yes Yes)}"
    local no_label="${3:-$(tui_str confirm_no No)}"
    local body="${4:-}"
    local items

    UI_CONFIRM_RESULT=""
    items="$(jq -n --arg y "$yes_label" --arg n "$no_label" \
        '[{id:"yes",label:$y},{id:"no",label:$n}]')"

    if ui_picker_flow "$title" "" "$body" "$items" false "yes" \
        "$(tui_str button_back Back)" "$(tui_str button_continue Continue)"; then
        if [[ "$UI_FLOW_BACK" == "true" ]]; then
            UI_CONFIRM_RESULT="back"
        elif [[ "$UI_FLOW_CHOICE" == "no" ]]; then
            UI_CONFIRM_RESULT="no"
        else
            UI_CONFIRM_RESULT="yes"
        fi
        return 0
    fi

    if ui_confirm "$title" true; then
        UI_CONFIRM_RESULT="yes"
    else
        UI_CONFIRM_RESULT="no"
    fi
    return 0
}

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
    local picked
    local items='[{"id":"server","label":"Server","subtitle":"Headless"},
                  {"id":"desktop","label":"Desktop","subtitle":"Full session"},
                  {"id":"laptop","label":"Laptop","subtitle":"Portable"}]'

    if picked="$(ui_picker_list "Platform" "Choose the platform for this machine" "$items")"; then
        printf '%s\n' "$picked"
        return 0
    fi
    [[ "$UI_NAV" == "back" ]] && return 2

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
    if command -v gum &>/dev/null; then
        gum style --bold --align center --width "$(ui_term_width)" --margin "1 0 0 0" "$@"
    else
        printf '\n== %s ==\n' "$*"
    fi
}

ui_style_subheader() {
    if command -v gum &>/dev/null; then
        gum style --align center --width "$(ui_term_width)" --foreground 245 "$@"
    else
        printf '  %s\n' "$*"
    fi
}

ui_style_divider() {
    if command -v gum &>/dev/null; then
        gum style --align center --width "$(ui_term_width)" --foreground 240 "$(ui_divider_line)"
    else
        printf '%s\n' "$(ui_divider_line)"
    fi
}

ui_style_centered() {
    if command -v gum &>/dev/null; then
        gum style --align center --width "$(ui_term_width)" "$@"
    else
        printf '%s\n' "$*"
    fi
}

ui_style() {
    if command -v gum &>/dev/null; then
        gum style "$@"
    else
        printf '%s\n' "$*"
    fi
}

# Status line with optional color. Plain text when gum is absent.
ui_note() {
    local color="$1"
    shift
    if command -v gum &>/dev/null; then
        gum style --foreground "$color" "$@"
    else
        printf '%s\n' "$*"
    fi
}

ui_confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-true}"

    if ! command -v gum &>/dev/null; then
        ui_confirm_plain "$prompt"
        return $?
    fi

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

ui_picker_menu_confirm() {
    local message="$1"
    local default_yes="${2:-true}"
    local title="${3:-Confirm}"
    local body="${4:-}"
    local yes_label="${5:-$(tui_str confirm_yes Yes)}"
    local no_label="${6:-$(tui_str confirm_no No)}"
    local show_banner="${7:-true}"
    local input_file result_file confirmed default_json banner_json show_banner_json

    if picker_can_run; then
        input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-in.XXXXXX")"
        result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-out.XXXXXX")"
        default_json="false"
        [[ "$default_yes" == "true" ]] && default_json="true"
        show_banner_json="true"
        [[ "$show_banner" == "false" ]] && show_banner_json="false"
        banner_json="$(picker_banner_json)"

        jq -n \
            --argjson banner "$banner_json" \
            --argjson step "$UI_STEP" \
            --argjson total "$UI_TOTAL" \
            --arg mode "confirm" \
            --arg title "$title" \
            --arg message "$message" \
            --arg body "$body" \
            --arg yes_label "$yes_label" \
            --arg no_label "$no_label" \
            --argjson default_yes "$default_json" \
            --argjson show_banner "$show_banner_json" \
            '{banner: $banner, step: $step, total: $total, mode: $mode, title: $title, message: $message, body: $body, yes_label: $yes_label, no_label: $no_label, default_yes: $default_yes, show_banner: $show_banner, show_back: ($step > 1)}' \
            >"$input_file"

        if menu_picker_run "$result_file" "$input_file"; then
            confirmed="$(jq -r '.confirmed // false' "$result_file")"
            [[ "$(jq -r '.back // false' "$result_file")" == "true" ]] && UI_NAV="back"
            rm -f "$input_file" "$result_file"
            [[ "$confirmed" == "true" ]]
            return $?
        fi
        rm -f "$input_file" "$result_file"
    fi

    ui_show_banner
    if [[ "${PLATFORM_CLASS:-}" != "server" ]]; then
        ui_style_centered "GPU: $(ui_gpu_label "${GPU_CLASS:-none}")"
        ui_style_divider
    fi
    ui_confirm "$message" "$default_yes"
}

ui_picker_menu_offer() {
    if picker_can_run; then
        ui_picker_menu_confirm \
            "$(tui_str arco_offer_message "Would you like to check out more apps?")" \
            true \
            "$(tui_str arco_offer_title "More apps")" \
            "$(tui_str arco_offer_body "Nice software choice, we have more you can choose from.")" \
            "$(tui_str arco_offer_yes "Of course")" \
            "$(tui_str arco_offer_no "No thanks")" \
            false
        return $?
    fi

    ui_style_subheader "$(tui_str arco_offer_body "Nice software choice, we have more you can choose from.")"
    ui_confirm "$(tui_str arco_offer_message "Would you like to check out more apps?")" true
}

ui_picker_menu_list() {
    local title="$1"
    local subtitle="$2"
    local items_json="$3"
    local input_file result_file choice

    if picker_can_run; then
        input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-in.XXXXXX")"
        result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-out.XXXXXX")"

        jq -n \
            --argjson banner "$(picker_banner_json)" \
            --argjson step "$UI_STEP" \
            --argjson total "$UI_TOTAL" \
            --arg mode "list" \
            --arg title "$title" \
            --arg subtitle "$subtitle" \
            --argjson items "$items_json" \
            '{banner: $banner, step: $step, total: $total, mode: "list", title: $title, subtitle: $subtitle, items: $items, show_back: ($step > 1)}' \
            >"$input_file"

        if menu_picker_run "$result_file" "$input_file"; then
            choice="$(jq -r '.choice // empty' "$result_file")"
            [[ "$(jq -r '.back // false' "$result_file")" == "true" ]] && UI_NAV="back"
            rm -f "$input_file" "$result_file"
            if [[ -n "$choice" ]]; then
                printf '%s' "$choice"
                return 0
            fi
        fi
        rm -f "$input_file" "$result_file"
    fi

    return 1
}

ui_picker_menu_info() {
    local title="$1"
    local body="$2"
    local input_file result_file

    if picker_can_run; then
        input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-in.XXXXXX")"
        result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-menu-out.XXXXXX")"

        jq -n \
            --argjson banner "$(picker_banner_json)" \
            --argjson step "$UI_STEP" \
            --argjson total "$UI_TOTAL" \
            --arg mode "info" \
            --arg title "$title" \
            --arg body "$body" \
            '{banner: $banner, step: $step, total: $total, mode: "info", title: $title, body: $body, show_back: ($step > 1)}' \
            >"$input_file"

        if menu_picker_run "$result_file" "$input_file"; then
            [[ "$(jq -r '.back // false' "$result_file")" == "true" ]] && UI_NAV="back"
            rm -f "$input_file" "$result_file"
            return 0
        fi
        rm -f "$input_file" "$result_file"
    fi

    return 1
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

    # gum spin opens /dev/tty directly; without a controlling terminal it fails.
    if ! command -v gum &>/dev/null || [[ ! -t 0 && ! -t 1 ]]; then
        printf '%s\n' "$title"
        "$@"
        return $?
    fi
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

    [[ -n "$label" ]] || label="$(ui_distro_label "$distro_id")"

    if command -v gum &>/dev/null; then
        local color
        color="$(ui_distro_color "$distro_id" "$family")"
        gum style --foreground "$color" "$label"
    else
        printf '%s\n' "$label"
    fi
}

ui_show_banner() {
    local badge platform_label width

    badge="$(ui_distro_label)"
    platform_label="$(ui_platform_label "${PLATFORM_CLASS:-desktop}")"
    width="$(ui_term_width)"

    if command -v gum &>/dev/null; then
        local color
        color="$(ui_distro_color)"
        gum style --bold --align center --width "$width" --margin "1 0" "$(tui_str app_title os-configs)"
        gum style --align center --width "$width" --foreground 245 "$(tui_str app_subtitle "Post-install setup")"
        ui_style_divider
        gum style --align center --width "$width" --foreground "$color" "/ ${badge} · ${platform_label} \\"
    else
        printf '\nos-configs\nPost-install setup\n'
        ui_style_divider
        printf '/ %s · %s \\\n' "$badge" "$platform_label"
    fi
    ui_style_divider
}
