#!/usr/bin/env bash
set -euo pipefail

_dewm_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_dewm_repo="${REPO_ROOT:-$(cd "${_dewm_lib_dir}/.." && pwd)}"
_dewm_config="${_dewm_repo}/data/config.json"
_dewm_map="${_dewm_repo}/data/de-wm.json"
_dewm_dms="${_dewm_repo}/data/display-managers.json"

SELECTED_DE_WM=""
SELECTED_DM=""
SELECTED_DOTFILES_PKG=""

dewm_ask_enabled() {
    if [[ "${OS_CONFIGS_ASK_DE_WM:-}" == "1" || "${OS_CONFIGS_ASK_DE_WM:-}" == "true" ]]; then
        return 0
    fi
    jq -e '.ask_de_wm == true' "$_dewm_config" >/dev/null 2>&1
}

dewm_platform_needs_session() {
    [[ "$PLATFORM_CLASS" == "desktop" || "$PLATFORM_CLASS" == "laptop" ]]
}

dewm_label() {
    jq -r --arg id "$1" '.[$id].label // $id' "$_dewm_map"
}

dewm_dm_label() {
    jq -r --arg id "$1" '.[$id].label // $id' "$_dewm_dms"
}

dewm_dotfiles_pkg() {
    jq -r --arg id "$1" '.[$id].dotfiles_pkg // empty' "$_dewm_map"
}

dewm_default_dm_for_de_wm() {
    jq -r --arg id "$1" '.[$id].default_dm // empty' "$_dewm_map"
}

dewm_apply_ids() {
    local de_wm="$1"
    local dm="$2"

    SELECTED_DE_WM="$de_wm"
    SELECTED_DM="$dm"
    SELECTED_DOTFILES_PKG="$(dewm_dotfiles_pkg "$de_wm")"
    export SELECTED_DE_WM SELECTED_DM SELECTED_DOTFILES_PKG
}

dewm_apply_from_preset() {
    local preset_file="$1"
    local de_wm dm

    de_wm="$(jq -r '.de_wm_default // empty' "$preset_file")"
    dm="$(jq -r '.dm_default // empty' "$preset_file")"

    if [[ -z "$de_wm" || -z "$dm" ]]; then
        echo "dewm: preset missing de_wm_default or dm_default: ${preset_file}" >&2
        return 1
    fi

    dewm_apply_ids "$de_wm" "$dm"
}

dewm_apply_custom_defaults() {
    local de_wm dm

    de_wm="$(jq -r '.custom_defaults.de_wm // "gnome"' "$_dewm_config")"
    dm="$(jq -r '.custom_defaults.dm // "gdm"' "$_dewm_config")"
    dewm_apply_ids "$de_wm" "$dm"
}

dewm_pick_de_wm_interactive() {
    local -a de_opts=() choice

    while IFS= read -r label; do
        [[ -n "$label" ]] && de_opts+=("$label")
    done < <(jq -r '.[] | select(.type == "de") | .label' "$_dewm_map")

    ui_style_header "Desktop environments"
    choice="$(gum choose "${de_opts[@]}")"
    jq -r --arg label "$choice" 'to_entries[] | select(.value.label == $label) | .key' "$_dewm_map" | head -1
}

dewm_pick_wm_interactive() {
    local -a wm_opts=() choice id

    while IFS= read -r label; do
        [[ -n "$label" ]] && wm_opts+=("$label")
    done < <(jq -r '.[] | select(.type == "wm") | .label' "$_dewm_map")

    ui_style_header "Window managers"
    choice="$(gum choose "${wm_opts[@]}")"
    jq -r --arg label "$choice" 'to_entries[] | select(.value.label == $label) | .key' "$_dewm_map" | head -1
}

dewm_pick_de_wm_menu() {
    local mode choice id

    ui_style_header "Session type"
    mode="$(gum choose "Desktop environment" "Window manager")"

    if [[ "$mode" == "Desktop environment" ]]; then
        id="$(dewm_pick_de_wm_interactive)"
    else
        id="$(dewm_pick_wm_interactive)"
    fi

    [[ -n "$id" ]] || return 1
    echo "$id"
}

dewm_pick_dm_interactive() {
    local default_dm="$1"
    local -a opts=() choice id label

    while IFS= read -r label; do
        [[ -n "$label" ]] && opts+=("$label")
    done < <(jq -r '.[].label' "$_dewm_dms")

    ui_style_header "Display manager"
    ui_style_subheader "Default for this session: $(dewm_dm_label "$default_dm")"

    choice="$(gum choose "${opts[@]}")"
    jq -r --arg label "$choice" 'to_entries[] | select(.value.label == $label) | .key' "$_dewm_dms" | head -1
}

dewm_prompt_interactive() {
    local de_wm dm default_dm

    de_wm="$(dewm_pick_de_wm_menu)"
    default_dm="$(dewm_default_dm_for_de_wm "$de_wm")"
    dm="$(dewm_pick_dm_interactive "$default_dm")"
    dewm_apply_ids "$de_wm" "$dm"
}

dewm_resolve() {
    local auto="${1:-false}"
    local preset_file="${2:-}"

    SELECTED_DE_WM=""
    SELECTED_DM=""
    SELECTED_DOTFILES_PKG=""
    export SELECTED_DE_WM SELECTED_DM SELECTED_DOTFILES_PKG

    if ! dewm_platform_needs_session; then
        return 0
    fi

    if dewm_ask_enabled && [[ "$auto" != "true" ]]; then
        dewm_prompt_interactive
        return 0
    fi

    if [[ -n "$preset_file" ]]; then
        dewm_apply_from_preset "$preset_file"
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        dewm_prompt_interactive
        return 0
    fi

    dewm_apply_custom_defaults
}

dewm_show_summary() {
    [[ -n "$SELECTED_DE_WM" ]] || return 0
    ui_style_centered "DE/WM:     $(dewm_label "$SELECTED_DE_WM")"
    ui_style_centered "DM:        $(dewm_dm_label "$SELECTED_DM")"
}
