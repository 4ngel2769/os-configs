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

confirm_plan_text() {
    local plan_file="$1"
    local app label count=0

    printf 'Distro:   %s (%s)\n' "$(ui_distro_label)" "$DISTRO_FAMILY"
    printf 'Platform: %s\n' "$(ui_platform_label "$PLATFORM_CLASS")"
    if [[ "$PLATFORM_CLASS" != "server" ]]; then
        printf 'GPU:      %s\n' "$(ui_gpu_label "$GPU_CLASS")"
    fi
    if [[ "$INSTALL_MODE" == "preset" ]]; then
        printf 'Preset:   %s\n' "$(preset_summary_line "$plan_file")"
    else
        printf 'Mode:     custom\n'
    fi
    if [[ -n "${SELECTED_DE_WM:-}" ]]; then
        printf 'DE/WM:    %s\n' "$(dewm_label "$SELECTED_DE_WM")"
        printf 'DM:       %s\n' "$(dewm_dm_label "${SELECTED_DM:-}")"
    fi
    if [[ -n "${SELECTED_SHELL:-}" ]]; then
        printf 'Shell:    %s (default)\n' "$(shell_label "$SELECTED_SHELL")"
    fi
    printf '\nPackages:\n'
    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        label="$(registry_app_label "$app")"
        printf '  %s\n' "$label"
        count=$((count + 1))
    done < <(preset_flatten_apps "$plan_file")
    printf '\n%s app(s) total\n' "$count"
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

confirm_run() {
    local auto="${1:-false}"
    local dry_run="${2:-false}"
    local skip_dotfiles="${3:-false}"
    local skip_postlogin="${4:-false}"
    local skip_reboot="${5:-false}"
    local plan_file plan_rc=0 plan_body

    plan_file="$(flow_active_plan_file)"

    if [[ ! -f "$plan_file" ]]; then
        echo "confirm: plan file not found" >&2
        return 1
    fi

    if ! preset_validate_registry "$plan_file" "$DISTRO_FAMILY"; then
        echo "confirm: plan contains apps missing registry entries for ${DISTRO_FAMILY}" >&2
        return 1
    fi

    plan_body="$(confirm_plan_text "$plan_file")"

    if [[ "$dry_run" == "true" ]]; then
        confirm_show_plan "$plan_file"
        install_run_plan "$plan_file" true || true
        log_print_summary
        shell_apply true "$auto"
        dotfiles_deploy true "$auto" "$skip_dotfiles"
        finish_run "$auto" true "$skip_postlogin" true
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        ui_flow_confirm "Confirm installation" \
            "$(tui_str confirm_yes Yes)" "$(tui_str confirm_no No)" "$plan_body"
        case "$UI_CONFIRM_RESULT" in
            back)
                UI_NAV="back"
                return 2
                ;;
            no)
                ui_note 245 "Installation cancelled."
                return 0
                ;;
        esac
    else
        confirm_show_plan "$plan_file"
        ui_style_subheader "(auto) proceeding with installation"
    fi

    install_run_plan "$plan_file" false || plan_rc=$?
    log_print_summary
    shell_apply false "$auto"

    if [[ "$skip_dotfiles" != "true" ]] && ! command -v stow &>/dev/null; then
        os_configs_prepare_deps "$auto" "$skip_dotfiles" false
    fi

    dotfiles_deploy false "$auto" "$skip_dotfiles"
    finish_run "$auto" false "$skip_postlogin" "$skip_reboot"
    return "$plan_rc"
}

confirm_custom_install() {
    local plan_file="$1"
    local dry_run="${2:-false}"
    local auto="${3:-false}"
    local plan_rc=0

    if [[ ! -f "$plan_file" ]]; then
        echo "confirm: custom plan not found" >&2
        return 1
    fi

    if ! preset_validate_registry "$plan_file" "$DISTRO_FAMILY"; then
        return 1
    fi

    confirm_show_plan "$plan_file"

    if [[ "$dry_run" == "true" ]]; then
        install_run_plan "$plan_file" true || true
        log_print_summary
        return 0
    fi

    if [[ "$auto" != "true" ]]; then
        ui_confirm "Proceed with installation?" || return 0
    fi

    install_run_plan "$plan_file" false || plan_rc=$?
    log_print_summary
    return "$plan_rc"
}
