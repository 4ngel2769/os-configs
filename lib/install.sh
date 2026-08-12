#!/usr/bin/env bash
set -euo pipefail

_install_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${_install_lib_dir}/registry.sh"
# shellcheck source=/dev/null
source "${_install_lib_dir}/log.sh"
# shellcheck source=/dev/null
source "${_install_lib_dir}/github-install.sh"

install_parse_lookup() {
    local lookup="$1"
    INSTALL_MANAGER=""
    INSTALL_PACKAGE=""
    INSTALL_SOURCE=""
    INSTALL_COMPONENT=""
    INSTALL_REPO=""
    INSTALL_METHOD=""
    INSTALL_ASSET_PATTERN=""
    INSTALL_BIN=""
    INSTALL_INSTALL_DIR=""
    INSTALL_SCRIPT_PATH=""
    INSTALL_REF=""
    INSTALL_CLONE_DIR=""
    INSTALL_BUILD_CMD=""
    INSTALL_BUILD_PACKAGES=""

    while IFS= read -r line; do
        case "$line" in
            manager=*) INSTALL_MANAGER="${line#manager=}" ;;
            package=*) INSTALL_PACKAGE="${line#package=}" ;;
            source=*) INSTALL_SOURCE="${line#source=}" ;;
            component=*) INSTALL_COMPONENT="${line#component=}" ;;
            repo=*) INSTALL_REPO="${line#repo=}" ;;
            method=*) INSTALL_METHOD="${line#method=}" ;;
            asset_pattern=*) INSTALL_ASSET_PATTERN="${line#asset_pattern=}" ;;
            bin=*) INSTALL_BIN="${line#bin=}" ;;
            install_dir=*) INSTALL_INSTALL_DIR="${line#install_dir=}" ;;
            script_path=*) INSTALL_SCRIPT_PATH="${line#script_path=}" ;;
            ref=*) INSTALL_REF="${line#ref=}" ;;
            clone_dir=*) INSTALL_CLONE_DIR="${line#clone_dir=}" ;;
            build_cmd=*) INSTALL_BUILD_CMD="${line#build_cmd=}" ;;
            build_packages=*) INSTALL_BUILD_PACKAGES="${line#build_packages=}" ;;
        esac
    done <<<"$lookup"

    export INSTALL_MANAGER INSTALL_PACKAGE INSTALL_SOURCE INSTALL_COMPONENT
    export INSTALL_REPO INSTALL_METHOD INSTALL_ASSET_PATTERN INSTALL_BIN
    export INSTALL_INSTALL_DIR INSTALL_SCRIPT_PATH INSTALL_REF INSTALL_CLONE_DIR
    export INSTALL_BUILD_CMD INSTALL_BUILD_PACKAGES
}

install_format_label() {
    local simple_name="$1"

    case "$INSTALL_MANAGER" in
        github)
            printf '%s → github:%s (%s)' "$simple_name" "$INSTALL_REPO" "${INSTALL_METHOD:-release}"
            ;;
        *)
            printf '%s → %s:%s' "$simple_name" "$INSTALL_MANAGER" "$INSTALL_PACKAGE"
            ;;
    esac
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

install_load_build_packages() {
    local simple_name="$1"
    local entry

    entry="$(registry_entry_json "$simple_name" "${DISTRO_FAMILY}")"
    INSTALL_BUILD_PACKAGES="$(jq -r '.build_packages // [] | join(",")' <<<"$entry")"
    export INSTALL_BUILD_PACKAGES
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
    label="$(install_format_label "$simple_name")"

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
        github)
            install_load_build_packages "$simple_name"
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] ${label}"
                github_install_app "$simple_name" true || {
                    log_record_failure "${label}"
                    return 1
                }
                log_record_success "${label}"
                return 0
            fi
            if ui_spin "Installing ${simple_name} from GitHub..." github_install_app "$simple_name" false; then
                log_record_success "${label}"
                return 0
            fi
            log_record_failure "${label}"
            return 1
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

install_ensure_stow() {
    local dry_run="${1:-false}"

    if command -v stow &>/dev/null; then
        return 0
    fi

    install_app stow "$dry_run"
}
