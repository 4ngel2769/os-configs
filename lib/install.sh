#!/usr/bin/env bash
set -euo pipefail

_install_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${_install_lib_dir}/registry.sh"
# shellcheck source=/dev/null
source "${_install_lib_dir}/log.sh"

install_parse_lookup() {
    local lookup="$1"
    INSTALL_MANAGER=""
    INSTALL_PACKAGE=""
    INSTALL_SOURCE=""
    INSTALL_COMPONENT=""

    while IFS= read -r line; do
        case "$line" in
            manager=*) INSTALL_MANAGER="${line#manager=}" ;;
            package=*) INSTALL_PACKAGE="${line#package=}" ;;
            source=*) INSTALL_SOURCE="${line#source=}" ;;
            component=*) INSTALL_COMPONENT="${line#component=}" ;;
        esac
    done <<<"$lookup"

    export INSTALL_MANAGER INSTALL_PACKAGE INSTALL_SOURCE INSTALL_COMPONENT
}

install_note_prereq() {
    local simple_name="$1"
    local note=""

    [[ -n "$INSTALL_SOURCE" ]] && note+=" source:${INSTALL_SOURCE}"
    [[ -n "$INSTALL_COMPONENT" ]] && note+=" component:${INSTALL_COMPONENT}"

    if [[ -n "$note" ]]; then
        echo "[plan] ${simple_name} requires${note}" >&2
    fi
}

install_app() {
    local simple_name="$1"
    local dry_run="${2:-false}"
    local lookup cmd label

    if ! lookup="$(registry_lookup "$simple_name" 2>&1)"; then
        log_record_failure "${simple_name} (registry lookup failed)"
        return 1
    fi

    install_parse_lookup "$lookup"
    install_note_prereq "$simple_name"
    label="${simple_name} → ${INSTALL_MANAGER}:${INSTALL_PACKAGE}"

    case "$INSTALL_MANAGER" in
        pacman)
            cmd=(sudo pacman -S --needed --noconfirm "$INSTALL_PACKAGE")
            ;;
        apt)
            cmd=(sudo apt-get install -y "$INSTALL_PACKAGE")
            ;;
        dnf)
            cmd=(sudo dnf install -y "$INSTALL_PACKAGE")
            ;;
        aur)
            if [[ -z "${AUR_HELPER:-}" ]]; then
                log_record_failure "${simple_name} (no AUR helper)"
                return 1
            fi
            cmd=(sudo "$AUR_HELPER" -S --needed --noconfirm "$INSTALL_PACKAGE")
            ;;
        *)
            log_record_failure "${simple_name} (unsupported manager: ${INSTALL_MANAGER})"
            return 1
            ;;
    esac

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] ${label}"
        echo "[dry-run] would run: ${cmd[*]}"
        log_record_success "${label}"
        return 0
    fi

    if ui_spin "Installing ${simple_name}..." "${cmd[@]}"; then
        log_record_success "${label}"
        return 0
    fi

    log_record_failure "${label}"
    return 1
}

install_run_plan() {
    local plan_file="$1"
    local dry_run="${2:-false}"
    local app

    log_reset

    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        install_app "$app" "$dry_run" || true
    done < <(preset_flatten_apps "$plan_file")
}
