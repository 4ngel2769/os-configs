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
    local gaming_json="false"

    if [[ ! -f "$_flow_menu_file" ]]; then
        echo "flow: preset menu not found: $_flow_menu_file" >&2
        return 1
    fi

    if [[ "$GPU_CLASS" == "igpu-gaming" || "$GPU_CLASS" == "dgpu" ]]; then
        gaming_json="true"
    fi

    local rows
    rows="$(jq -r --arg pc "$PLATFORM_CLASS" --argjson gaming "$gaming_json" '
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
    local gaming_json="false"

    if [[ "$GPU_CLASS" == "igpu-gaming" || "$GPU_CLASS" == "dgpu" ]]; then
        gaming_json="true"
    fi

    jq -r --arg pc "$PLATFORM_CLASS" --argjson gaming "$gaming_json" '
        [.presets[]
         | select(.platform_class == $pc)
         | select((.requires_gaming_gpu // false) == false or $gaming)
         | .id
        ] | .[]
    ' "$_flow_menu_file"
}

flow_label_to_preset_id() {
    local label="$1"
    jq -r --arg lbl "$label" '.presets[] | select(.label == $lbl) | .id' "$_flow_menu_file" | head -1
}

flow_show_detection_summary() {
    local gpu_label

    ui_show_banner

    if [[ "$PLATFORM_CLASS" != "server" ]]; then
        gpu_label="$(ui_gpu_label "$GPU_CLASS")"
        ui_style_centered "GPU: ${gpu_label}"
        ui_style_divider
    fi
}

flow_platform_override() {
    local auto="${1:-false}"

    if [[ "$auto" == "true" ]]; then
        flow_show_detection_summary
        ui_style_subheader "(auto) keeping detected platform: $(ui_platform_label "$PLATFORM_CLASS")"
        return 0
    fi

    if ui_picker_menu_confirm \
        "$(tui_strf platform_confirm_message platform="$(ui_platform_label "$PLATFORM_CLASS")")" \
        true \
        "$(tui_str platform_confirm_title Platform)"; then
        return 0
    fi

    local picked
    picked="$(ui_platform_pick)"
    PLATFORM_CLASS="$picked"
    export PLATFORM_CLASS
    ui_style_subheader "Platform overridden to: $(ui_platform_label "$PLATFORM_CLASS")"
}

flow_select_preset_menu() {
    local auto="${1:-false}"
    local -a labels=()
    local -a ids=()
    local choice id i
    local input_file result_file

    flow_build_preset_options labels

    if [[ ${#labels[@]} -eq 0 ]]; then
        echo "flow: no presets for platform '${PLATFORM_CLASS}'" >&2
        return 1
    fi

    for label in "${labels[@]}"; do
        ids+=("$(flow_label_to_preset_id "$label")")
    done

    if [[ "$auto" == "true" ]]; then
        ui_style_subheader "(auto) selected: ${labels[0]}"
        flow_load_preset "${ids[0]}"
        return 0
    fi

    if picker_can_run; then
        input_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-presets-in.XXXXXX")"
        result_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-presets-out.XXXXXX")"

        jq -n \
            --arg distro_id "${DISTRO_ID}" \
            --arg distro_label "$(ui_distro_label)" \
            --arg distro_color "$(ui_distro_color)" \
            --argjson labels "$(printf '%s\n' "${labels[@]}" | jq -R . | jq -s .)" \
            --argjson ids "$(printf '%s\n' "${ids[@]}" | jq -R . | jq -s .)" \
            '{
                distro_id: $distro_id,
                distro_label: $distro_label,
                distro_color: $distro_color,
                presets: [range($labels | length) as $i | {id: $ids[$i], label: $labels[$i]}],
                custom: {id: "custom", label: "Custom", subtitle: "pick your apps"}
            }' >"$input_file"

        if preset_picker_run "$result_file" "$input_file"; then
            choice="$(jq -r '.choice // empty' "$result_file")"
            rm -f "$input_file" "$result_file"
            if [[ "$choice" == "custom" ]]; then
                INSTALL_MODE="custom"
                export INSTALL_MODE
                return 0
            fi
            if [[ -n "$choice" ]]; then
                flow_load_preset "$choice"
                return 0
            fi
        fi
        rm -f "$input_file" "$result_file"
    fi

    ui_style_header "Choose a preset"
    choice="$(gum choose "${labels[@]}" "Custom")"

    if [[ "$choice" == "Custom" ]]; then
        INSTALL_MODE="custom"
        export INSTALL_MODE
        return 0
    fi

    id=""
    for i in "${!labels[@]}"; do
        if [[ "${labels[$i]}" == "$choice" ]]; then
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

flow_run_custom() {
    local auto="${1:-false}"
    custom_run_selection "$auto"
    custom_show_summary
}

flow_run_entry() {
    local auto="${1:-false}"

    flow_platform_override "$auto"
    flow_select_preset_menu "$auto"

    if [[ "$INSTALL_MODE" == "custom" ]]; then
        flow_run_custom "$auto"
        dewm_resolve "$auto" ""
    else
        dewm_resolve "$auto" "$SELECTED_PRESET_FILE"
    fi

    shell_resolve "$auto"

    confirm_run "$auto" "${OS_CONFIGS_DRY_RUN:-false}" "${OS_CONFIGS_SKIP_DOTFILES:-false}" "${OS_CONFIGS_SKIP_POSTLOGIN:-false}" "${OS_CONFIGS_SKIP_REBOOT:-false}"
}
