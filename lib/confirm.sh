#!/usr/bin/env bash
set -euo pipefail

_confirm_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${_confirm_lib_dir}/presets.sh"
# shellcheck source=/dev/null
source "${_confirm_lib_dir}/install.sh"
# shellcheck source=/dev/null
source "${_confirm_lib_dir}/dotfiles.sh"
# shellcheck source=/dev/null
source "${_confirm_lib_dir}/finish.sh"

confirm_format_app_line() {
    local simple_name="$1"
    local lookup

    if ! lookup="$(registry_lookup "$simple_name" 2>/dev/null)"; then
        echo "  ${simple_name}  (missing registry entry)"
        return 1
    fi

    install_parse_lookup "$lookup"
    echo "  $(install_format_label "$simple_name")"
}

confirm_show_plan() {
    local plan_file="$1"
    local summary badge platform_label

    ui_style_divider
    ui_style_header "Confirm installation"

    badge="$(ui_distro_badge)"
    platform_label="$(ui_platform_label "$PLATFORM_CLASS")"

    ui_style_centered "Distro:     ${badge} (${DISTRO_FAMILY})"
    ui_style_centered "Platform:   ${platform_label}"
    if [[ "$PLATFORM_CLASS" != "server" ]]; then
        ui_style_centered "GPU:        $(ui_gpu_label "$GPU_CLASS")"
    fi

    if [[ "$INSTALL_MODE" == "preset" ]]; then
        summary="$(preset_summary_line "$plan_file")"
        ui_style_centered "Preset:     ${summary}"
    else
        ui_style_centered "Mode:       custom"
    fi

    dewm_show_summary
    shell_show_summary

    ui_style_subheader "Packages to install"
    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        confirm_format_app_line "$app" || true
    done < <(preset_flatten_apps "$plan_file")

    if [[ "${OS_CONFIGS_DRY_RUN:-false}" == "true" ]]; then
        ui_style_subheader "(dry-run — commands below are preview only)"
    fi
}

confirm_plan_body() {
    local plan_file="$1"
    local -a lines=()
    local app badge platform_label summary

    badge="$(ui_distro_label)"
    platform_label="$(ui_platform_label "$PLATFORM_CLASS")"

    lines+=("Distro:     ${badge} (${DISTRO_FAMILY})")
    lines+=("Platform:   ${platform_label}")
    if [[ "$PLATFORM_CLASS" != "server" ]]; then
        lines+=("GPU:        $(ui_gpu_label "$GPU_CLASS")")
    fi

    if [[ "$INSTALL_MODE" == "preset" ]]; then
        summary="$(preset_summary_line "$plan_file")"
        lines+=("Preset:     ${summary}")
    else
        lines+=("Mode:       custom")
    fi

    if [[ -n "${SELECTED_DE_WM:-}" ]]; then
        lines+=("DE/WM:      $(dewm_label "$SELECTED_DE_WM")")
        lines+=("DM:         $(dewm_dm_label "$SELECTED_DM")")
    fi

    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        lines+=("Shell:      $(shell_label "$SELECTED_SHELL") (default)")
        if [[ "${SHELL_APPLY_DOTFILES:-false}" == "true" && -n "${SELECTED_SHELL_PROFILE:-}" ]]; then
            lines+=("Shell cfg:  $(shell_profile_label "$SELECTED_SHELL_PROFILE")")
            lines+=("            $(shell_profile_field "$SELECTED_SHELL_PROFILE" "credit")")
        fi
    fi

    lines+=("")
    lines+=("Packages to install:")
    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        if lookup="$(registry_lookup "$app" 2>/dev/null)"; then
            install_parse_lookup "$lookup"
            lines+=("  $(install_format_label "$app")")
        else
            lines+=("  ${app}  (missing registry entry)")
        fi
    done < <(preset_flatten_apps "$plan_file")

    if [[ "${OS_CONFIGS_DRY_RUN:-false}" == "true" ]]; then
        lines+=("")
        lines+=("(dry-run — commands below are preview only)")
    fi

    printf '%s\n' "${lines[@]}"
}

confirm_run() {
    local auto="${1:-false}"
    local dry_run="${2:-false}"
    local skip_dotfiles="${3:-false}"
    local skip_postlogin="${4:-false}"
    local skip_reboot="${5:-false}"
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

    if [[ "$dry_run" == "true" || "$auto" == "true" ]]; then
        confirm_show_plan "$plan_file"
    fi

    if [[ "$dry_run" == "true" ]]; then
        install_run_plan "$plan_file" true
        log_print_summary
        shell_apply true "$auto"
        dotfiles_deploy true "$auto" "$skip_dotfiles"
        finish_run "$auto" true "$skip_postlogin" true
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        local plan_body
        plan_body="$(confirm_plan_body "$plan_file")"
        if ! ui_picker_menu_confirm "Proceed with installation?" true "Confirm installation" "$plan_body"; then
            gum style --foreground 245 "Installation cancelled."
            return 0
        fi
    else
        ui_style_subheader "(auto) proceeding with installation"
    fi

    install_run_plan "$plan_file" false
    log_print_summary
    shell_apply false "$auto"

    if [[ "$skip_dotfiles" != "true" ]] && ! command -v stow &>/dev/null; then
        os_configs_prepare_deps "$auto" "$skip_dotfiles" false
    fi

    dotfiles_deploy false "$auto" "$skip_dotfiles"
    finish_run "$auto" false "$skip_postlogin" "$skip_reboot"
}

confirm_custom_install() {
    local plan_file="$1"
    local dry_run="${2:-false}"
    local auto="${3:-false}"

    if [[ ! -f "$plan_file" ]]; then
        echo "confirm: custom plan not found" >&2
        return 1
    fi

    if ! preset_validate_registry "$plan_file" "$DISTRO_FAMILY"; then
        return 1
    fi

    if [[ "$dry_run" == "true" || "$auto" == "true" ]]; then
        confirm_show_plan "$plan_file"
    fi

    if [[ "$dry_run" == "true" ]]; then
        install_run_plan "$plan_file" true
        log_print_summary
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        local plan_body
        plan_body="$(confirm_plan_body "$plan_file")"
        ui_picker_menu_confirm "Proceed with installation?" true "Confirm installation" "$plan_body" || return 0
    fi

    install_run_plan "$plan_file" false
    log_print_summary
}
