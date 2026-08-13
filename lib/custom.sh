#!/usr/bin/env bash
set -euo pipefail

_custom_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_custom_repo="${REPO_ROOT:-$(cd "${_custom_lib_dir}/.." && pwd)}"

SELECTED_CUSTOM_FILE=""
declare -A CUSTOM_SELECTION=()

_custom_merged_categories=""

custom_merged_categories_path() {
    if [[ -z "$_custom_merged_categories" || ! -f "$_custom_merged_categories" ]]; then
        _custom_merged_categories="${OS_CONFIGS_CACHE:-${HOME}/.cache}/os-configs/categories-merged.json"
        mkdir -p "$(dirname "$_custom_merged_categories")"
        categories_merged_json >"$_custom_merged_categories"
    fi
    echo "$_custom_merged_categories"
}

custom_category_keys() {
    jq -r 'keys[] | select(startswith("_") | not)' "$(custom_merged_categories_path)"
}

custom_category_label() {
    jq -r --arg key "$1" '.[$key].label' "$(custom_merged_categories_path)"
}

custom_category_apps() {
    local key="$1"
    local app

    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        if registry_app_visible "$app"; then
            echo "$app"
        fi
    done < <(jq -r --arg key "$key" '.[$key].apps[]?' "$(custom_merged_categories_path)")
}

custom_pick_category() {
    local key="$1"
    local auto="${2:-false}"
    local label
    local -a apps=() picked=()

    mapfile -t apps < <(custom_category_apps "$key")

    if [[ ${#apps[@]} -eq 0 ]]; then
        return 0
    fi

    label="$(custom_category_label "$key")"
    ui_style_header "$label"

    if [[ "$auto" == "true" ]]; then
        ui_style_subheader "(auto) skipping category"
        return 0
    fi

    mapfile -t picked < <(gum choose --no-limit "${apps[@]}")
    if [[ ${#picked[@]} -gt 0 ]]; then
        CUSTOM_SELECTION["$key"]="${picked[*]}"
    fi
}

custom_write_plan_json() {
    local out="$1"
    local tmp key apps_json
    tmp="$(mktemp)"

    jq -n \
        --arg name "Custom" \
        --arg platform_class "$PLATFORM_CLASS" \
        '{name: $name, platform_class: $platform_class, categories: {}}' >"$tmp"

    for key in $(custom_category_keys); do
        if [[ -n "${CUSTOM_SELECTION[$key]:-}" ]]; then
            read -r -a _apps <<<"${CUSTOM_SELECTION[$key]}"
            apps_json="$(printf '%s\n' "${_apps[@]}" | jq -R . | jq -s .)"
        else
            apps_json="[]"
        fi
        jq --argjson apps "$apps_json" ".categories[\"$key\"] = \$apps" "$tmp" >"${tmp}.new"
        mv "${tmp}.new" "$tmp"
    done

    if [[ "$PLATFORM_CLASS" == "laptop" ]]; then
        jq '. + {laptop_tuning: true}' "$tmp" >"${tmp}.new"
        mv "${tmp}.new" "$tmp"
    fi

    mv "$tmp" "$out"
}

custom_run_selection() {
    local auto="${1:-false}"
    local out_dir pick_file

    CUSTOM_SELECTION=()
    out_dir="${OS_CONFIGS_CACHE:-${HOME}/.cache}/os-configs"
    mkdir -p "$out_dir"
    SELECTED_CUSTOM_FILE="${out_dir}/custom-plan.json"
    pick_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-pick.XXXXXX")"

    if [[ "$auto" == "true" ]]; then
        picker_fallback_gum true
    elif picker_can_run && picker_run "$pick_file"; then
        picker_apply_selections "$pick_file" || picker_fallback_gum false
    else
        if [[ ! -x "$(picker_binary)" ]]; then
            ui_style_subheader "(fallback) build os-configs-picker for the full catalog UI"
        elif ! picker_has_tty; then
            ui_style_subheader "(fallback) no TTY — use ssh -t for the full picker"
        fi
        picker_fallback_gum false
    fi

    rm -f "$pick_file"
    custom_write_plan_json "$SELECTED_CUSTOM_FILE"
    export SELECTED_CUSTOM_FILE
}

custom_apply_test_selection() {
    local spec="$1"
    local out="${2:-/tmp/os-configs-custom-plan.json}"

    CUSTOM_SELECTION=()
    if [[ -n "$spec" ]]; then
        local pair cat apps
        local -a pairs=()
        IFS=',' read -r -a pairs <<<"$spec"
        for pair in "${pairs[@]}"; do
            cat="${pair%%:*}"
            apps="${pair#*:}"
            CUSTOM_SELECTION["$cat"]="${apps//+/ }"
        done
    fi

    SELECTED_CUSTOM_FILE="$out"
    custom_write_plan_json "$SELECTED_CUSTOM_FILE"
    export SELECTED_CUSTOM_FILE
}

custom_show_summary() {
    ui_style_header "Custom selection"
    jq -r '.categories | to_entries[] | select(.value | length > 0) | "\(.key): \(.value | join(", "))"' \
        "$SELECTED_CUSTOM_FILE"
}

flow_active_plan_file() {
    if [[ "$INSTALL_MODE" == "preset" ]]; then
        echo "$SELECTED_PRESET_FILE"
    else
        echo "$SELECTED_CUSTOM_FILE"
    fi
}
