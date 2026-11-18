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
    jq -r --arg lbl "$choice" 'to_entries[] | select(.value.label == $lbl) | .key' "$_dewm_map" | head -1
}

dewm_pick_wm_interactive() {
    local -a wm_opts=() choice id

    while IFS= read -r label; do
        [[ -n "$label" ]] && wm_opts+=("$label")
    done < <(jq -r '.[] | select(.type == "wm") | .label' "$_dewm_map")

    ui_style_header "Window managers"
    choice="$(gum choose "${wm_opts[@]}")"
    jq -r --arg lbl "$choice" 'to_entries[] | select(.value.label == $lbl) | .key' "$_dewm_map" | head -1
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
    jq -r --arg lbl "$choice" 'to_entries[] | select(.value.label == $lbl) | .key' "$_dewm_dms" | head -1
}

dewm_session_items_json() {
    jq -n '[{"id":"de","label":"Desktop environment","subtitle":"Full desktop session"},
            {"id":"wm","label":"Window manager","subtitle":"Lighter session"}]'
}

dewm_kind_items_json() {
    local kind="$1"
    jq --arg kind "$kind" \
        '[to_entries[] | select(.value.type == $kind) | {id: .key, label: .value.label}]' "$_dewm_map"
}

dewm_dm_items_json() {
    jq '[to_entries[] | {id: .key, label: .value.label}]' "$_dewm_dms"
}

dewm_prompt_interactive() {
    local mode de_wm dm default_dm kind_label rc=0

    if ! picker_can_run; then
        de_wm="$(dewm_pick_de_wm_menu)" || return 1
        default_dm="$(dewm_default_dm_for_de_wm "$de_wm")"
        dm="$(dewm_pick_dm_interactive "$default_dm")" || return 1
        dewm_apply_ids "$de_wm" "$dm"
        return 0
    fi

    while :; do
        de_wm=""
        UI_NAV=""
        ui_picker_flow "Session type" "Choose how your desktop session starts" \
            "" "$(dewm_session_items_json)" false "" || return 1
        if [[ "$UI_FLOW_BACK" == "true" ]]; then
            UI_NAV="back"
            return 2
        fi
        mode="$UI_FLOW_CHOICE"
        [[ "$mode" == "de" || "$mode" == "wm" ]] || continue
        if [[ "$mode" == "de" ]]; then
            kind_label="Desktop environments"
        else
            kind_label="Window managers"
        fi

        while :; do
            UI_NAV=""
            ui_picker_flow "$kind_label" "" "" "$(dewm_kind_items_json "$mode")" false "" || return 1
            if [[ "$UI_FLOW_BACK" == "true" ]]; then
                break
            fi
            de_wm="$UI_FLOW_CHOICE"
            [[ -n "$de_wm" ]] && break
        done
        [[ -n "$de_wm" ]] || continue

        default_dm="$(dewm_default_dm_for_de_wm "$de_wm")"
        while :; do
            UI_NAV=""
            ui_picker_flow "Display manager" \
                "Default for $(dewm_label "$de_wm"): $(dewm_dm_label "$default_dm")" \
                "" "$(dewm_dm_items_json)" false "$default_dm" || return 1
            if [[ "$UI_FLOW_BACK" == "true" ]]; then
                de_wm=""
                break
            fi
            dm="$UI_FLOW_CHOICE"
            [[ -n "$dm" ]] && break
        done
        [[ -z "$de_wm" ]] && continue

        dewm_apply_ids "$de_wm" "$dm"
        return 0
    done
}

dewm_resolve() {
    local auto="${1:-false}"
    local preset_file="${2:-}"
    local rc=0

    SELECTED_DE_WM=""
    SELECTED_DM=""
    SELECTED_DOTFILES_PKG=""
    export SELECTED_DE_WM SELECTED_DM SELECTED_DOTFILES_PKG

    if ! dewm_platform_needs_session; then
        return 0
    fi

    if dewm_ask_enabled && [[ "$auto" != "true" ]]; then
        dewm_prompt_interactive || rc=$?
        if [[ "$rc" -eq 2 ]]; then
            UI_NAV="back"
            return 2
        fi
        [[ "$rc" -eq 0 ]] || return "$rc"
        return 0
    fi

    if [[ -n "$preset_file" ]]; then
        dewm_apply_from_preset "$preset_file"
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        dewm_prompt_interactive || rc=$?
        if [[ "$rc" -eq 2 ]]; then
            UI_NAV="back"
            return 2
        fi
        [[ "$rc" -eq 0 ]] || return "$rc"
        return 0
    fi

    dewm_apply_custom_defaults
}

dewm_show_summary() {
    [[ -n "$SELECTED_DE_WM" ]] || return 0
    ui_style_centered "DE/WM:     $(dewm_label "$SELECTED_DE_WM")"
    ui_style_centered "DM:        $(dewm_dm_label "$SELECTED_DM")"
}
