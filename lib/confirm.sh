#!/usr/bin/env bash
set -euo pipefail

_confirm_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${_confirm_lib_dir}/presets.sh"
# shellcheck source=/dev/null
source "${_confirm_lib_dir}/install.sh"

confirm_format_app_line() {
    local simple_name="$1"
    local lookup manager package

    if ! lookup="$(registry_lookup "$simple_name" 2>/dev/null)"; then
        echo "  ${simple_name}  (missing registry entry)"
        return 1
    fi

    install_parse_lookup "$lookup"
    manager="$INSTALL_MANAGER"
    package="$INSTALL_PACKAGE"
    echo "  ${simple_name}  →  ${manager}:${package}"
}

confirm_show_plan() {
    local plan_file="$1"
    local summary badge platform_label

    ui_style_divider
    ui_style_header "Confirm installation"

    badge="$(ui_distro_badge)"
    platform_label="$(ui_platform_label "$PLATFORM_CLASS")"

    gum style "Distro:     ${badge} (${DISTRO_FAMILY})"
    gum style "Platform:   ${platform_label}"
    if [[ "$PLATFORM_CLASS" != "server" ]]; then
        gum style "GPU:        $(ui_gpu_label "$GPU_CLASS")"
    fi

    if [[ "$INSTALL_MODE" == "preset" ]]; then
        summary="$(preset_summary_line "$plan_file")"
        gum style "Preset:     ${summary}"
    else
        gum style "Mode:       custom"
    fi

    dewm_show_summary

    ui_style_subheader "Packages to install"
    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        confirm_format_app_line "$app" || true
    done < <(preset_flatten_apps "$plan_file")

    if [[ "${OS_CONFIGS_DRY_RUN:-false}" == "true" ]]; then
        ui_style_subheader "(dry-run — commands below are preview only)"
    fi
}

confirm_run() {
    local auto="${1:-false}"
    local dry_run="${2:-false}"
    local plan_file

    plan_file="$(flow_active_plan_file)"

    if [[ ! -f "$plan_file" ]]; then
        echo "confirm: plan file not found" >&2
        return 1
    fi

    if ! preset_validate_registry "$plan_file" "$DISTRO_FAMILY"; then
        echo "confirm: plan contains apps missing registry entries for ${DISTRO_FAMILY}" >&2
        return 1
    fi

    confirm_show_plan "$plan_file"

    if [[ "$dry_run" == "true" ]]; then
        install_run_plan "$plan_file" true
        log_print_summary
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        ui_confirm "Proceed with installation?" || {
            gum style --foreground 245 "Installation cancelled."
            return 0
        }
    else
        ui_style_subheader "(auto) proceeding with installation"
    fi

    install_run_plan "$plan_file" false
    log_print_summary
}
