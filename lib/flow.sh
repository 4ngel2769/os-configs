#!/usr/bin/env bash
set -euo pipefail

_flow_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_flow_repo_root="${REPO_ROOT:-$(cd "${_flow_lib_dir}/.." && pwd)}"
_flow_menu_file="${_flow_repo_root}/data/presets-menu.json"
_flow_presets_dir="${_flow_repo_root}/data/presets"

SELECTED_PRESET_ID=""
SELECTED_PRESET_FILE=""
INSTALL_MODE="" # preset | custom

flow_preset_visible() {
    local requires_gaming="${1:-false}"

    if [[ "$requires_gaming" == "true" ]]; then
        [[ "$GPU_CLASS" == "igpu-gaming" || "$GPU_CLASS" == "dgpu" ]]
        return $?
    fi
    return 0
}

flow_build_preset_options() {
    local -n _out=$1

    if [[ ! -f "$_flow_menu_file" ]]; then
        echo "flow: preset menu not found: $_flow_menu_file" >&2
        return 1
    fi

    local rows
    rows="$(jq -r --arg pc "$PLATFORM_CLASS" --argjson gaming "$(
        if [[ "$GPU_CLASS" == "igpu-gaming" || "$GPU_CLASS" == "dgpu" ]]; then echo true; else echo false; fi
    )" '
        [.presets[]
         | select(.platform_class == $pc)
         | select((.requires_gaming_gpu // false) == false or $gaming)
         | .label
        ] | .[]
    ' "$_flow_menu_file")"

    _out=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && _out+=("$line")
    done <<<"$rows"
}

flow_list_preset_ids() {
    jq -r --arg pc "$PLATFORM_CLASS" --argjson gaming "$(
        if [[ "$GPU_CLASS" == "igpu-gaming" || "$GPU_CLASS" == "dgpu" ]]; then echo true; else echo false; fi
    )" '
        [.presets[]
         | select(.platform_class == $pc)
         | select((.requires_gaming_gpu // false) == false or $gaming)
         | .id
        ] | .[]
    ' "$_flow_menu_file"
}

flow_label_to_preset_id() {
    local label="$1"
    jq -r --arg label "$label" '.presets[] | select(.label == $label) | .id' "$_flow_menu_file" | head -1
}

flow_show_detection_summary() {
    local badge
    badge="$(ui_distro_badge)"

    ui_style_header "os-configs"
    ui_style_subheader "Post-install setup"
    ui_style_divider
    gum style "Distro:    ${badge} (${DISTRO_FAMILY})"
    gum style "Platform:  ${PLATFORM_CLASS}"
    if [[ "$PLATFORM_CLASS" != "server" ]]; then
        gum style "GPU:       ${GPU_CLASS}"
    fi
    ui_style_divider
}

flow_platform_override() {
    local auto="${1:-false}"

    flow_show_detection_summary

    if [[ "$auto" == "true" ]]; then
        ui_style_subheader "(auto) keeping detected platform: ${PLATFORM_CLASS}"
        return 0
    fi

    if ui_confirm "Keep detected platform '${PLATFORM_CLASS}'?"; then
        return 0
    fi

    local picked
    picked="$(gum choose "server" "desktop" "laptop")"
    PLATFORM_CLASS="$picked"
    export PLATFORM_CLASS
    ui_style_subheader "Platform overridden to: ${PLATFORM_CLASS}"
}

flow_select_preset_menu() {
    local auto="${1:-false}"
    local -a labels=()
    local -a rows=()
    local -a ids=()
    local choice label id i

    flow_build_preset_options labels

    if [[ ${#labels[@]} -eq 0 ]]; then
        echo "flow: no presets for platform '${PLATFORM_CLASS}'" >&2
        return 1
    fi

    for label in "${labels[@]}"; do
        rows+=("$(ui_format_preset_row "$label")")
        id="$(flow_label_to_preset_id "$label")"
        ids+=("$id")
    done
    rows+=("Custom")

    ui_style_header "Choose a preset"

    if [[ "$auto" == "true" ]]; then
        choice="${rows[0]}"
        ui_style_subheader "(auto) selected: ${choice}"
    else
        choice="$(gum choose "${rows[@]}")"
    fi

    if [[ "$choice" == "Custom" ]]; then
        INSTALL_MODE="custom"
        export INSTALL_MODE
        return 0
    fi

    id=""
    for i in "${!rows[@]}"; do
        if [[ "${rows[$i]}" == "$choice" ]]; then
            id="${ids[$i]}"
            break
        fi
    done

    if [[ -z "$id" ]]; then
        echo "flow: could not resolve preset for choice '${choice}'" >&2
        return 1
    fi

    flow_load_preset "$id"
}

flow_load_preset() {
    local id="$1"
    local file="${_flow_presets_dir}/${id}.json"

    if [[ ! -f "$file" ]]; then
        echo "flow: preset file not found: ${file}" >&2
        return 1
    fi

    SELECTED_PRESET_ID="$id"
    SELECTED_PRESET_FILE="$file"
    INSTALL_MODE="preset"
    export SELECTED_PRESET_ID SELECTED_PRESET_FILE INSTALL_MODE
}

flow_stub_custom() {
    INSTALL_MODE="custom"
    export INSTALL_MODE
    ui_style_header "Custom mode"
    gum style --foreground 245 "Category selection is implemented in Phase 5."
}

flow_stub_confirm() {
    ui_style_divider
    ui_style_header "Next step"

    if [[ "$INSTALL_MODE" == "preset" ]]; then
        gum style "Preset:    ${SELECTED_PRESET_ID}"
        gum style "File:      ${SELECTED_PRESET_FILE}"
        gum style --foreground 240 "(confirmation + install — Phase 7)"
    else
        gum style "Mode:      custom"
        gum style --foreground 240 "(category flow — Phase 5, then Phase 7)"
    fi
}

flow_run_entry() {
    local auto="${1:-false}"

    flow_platform_override "$auto"
    flow_select_preset_menu "$auto"

    if [[ "$INSTALL_MODE" == "custom" ]]; then
        flow_stub_custom
    fi

    flow_stub_confirm
}
