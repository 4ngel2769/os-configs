#!/usr/bin/env bash
set -euo pipefail

_dotfiles_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_dotfiles_repo="${REPO_ROOT:-$(cd "${_dotfiles_lib_dir}/.." && pwd)}"
_dotfiles_root="${_dotfiles_repo}/dotfiles"

DOTFILES_BACKUP_PATH=""

dotfiles_collect_packages() {
    local -n _out=$1
    local pkg stow_dir pkg_name

    _out=()

    if [[ -d "${_dotfiles_root}/shared" ]]; then
        for pkg in "${_dotfiles_root}/shared"/*/; do
            [[ -d "$pkg" ]] || continue
            pkg_name="$(basename "$pkg")"
            if [[ "$pkg_name" == "zsh" && -n "${SELECTED_SHELL:-}" ]]; then
                continue
            fi
            _out+=("shared:${pkg_name}")
        done
    fi

    if [[ "${SHELL_APPLY_DOTFILES:-false}" == "true" && -n "${SELECTED_SHELL_STOW:-}" ]]; then
        local shell_dir shell_pkg
        shell_dir="${SELECTED_SHELL_STOW%/*}"
        shell_pkg="${SELECTED_SHELL_STOW##*/}"
        if [[ -d "${_dotfiles_root}/${shell_dir}/${shell_pkg}" ]]; then
            _out+=("${shell_dir}:${shell_pkg}")
        fi
    fi

    if [[ -n "${SELECTED_DOTFILES_PKG:-}" && -d "${_dotfiles_root}/${SELECTED_DOTFILES_PKG}" ]]; then
        for pkg in "${_dotfiles_root}/${SELECTED_DOTFILES_PKG}"/*/; do
            [[ -d "$pkg" ]] || continue
            pkg_name="$(basename "$pkg")"
            _out+=("${SELECTED_DOTFILES_PKG}:${pkg_name}")
        done
    fi
}

dotfiles_target_for_file() {
    local stow_dir="$1"
    local pkg_name="$2"
    local file_path="$3"
    local rel

    rel="${file_path#${stow_dir}/${pkg_name}/}"
    echo "${HOME}/${rel}"
}

dotfiles_collect_conflicts() {
    local -n _out=$1
    local -a packages=()
    local spec stow_dir pkg_name pkg_path file target

    _out=()
    dotfiles_collect_packages packages

    for spec in "${packages[@]}"; do
        stow_dir="${_dotfiles_root}/${spec%%:*}"
        pkg_name="${spec#*:}"
        pkg_path="${stow_dir}/${pkg_name}"

        while IFS= read -r file; do
            [[ -n "$file" ]] || continue
            target="$(dotfiles_target_for_file "$stow_dir" "$pkg_name" "$file")"
            if [[ -e "$target" && ! -L "$target" ]]; then
                _out+=("$target")
            elif [[ -L "$target" ]]; then
                local link_dest
                link_dest="$(readlink "$target")"
                if [[ "$link_dest" != *"/${spec}/${pkg_name}/"* && "$link_dest" != *"/dotfiles/${spec%%:*}/${pkg_name}/"* ]]; then
                    _out+=("$target")
                fi
            fi
        done < <(find "$pkg_path" \( -type f -o -type l \) 2>/dev/null)
    done
}

dotfiles_show_plan() {
    local -a packages=()
    local -a conflicts=()
    local spec pkg

    dotfiles_collect_packages packages

    if [[ ${#packages[@]} -eq 0 ]]; then
        gum style --foreground 245 "No dotfiles packages found."
        return 0
    fi

    ui_style_subheader "Dotfiles packages"
    for spec in "${packages[@]}"; do
        gum style "  ${spec}"
    done

    dotfiles_collect_conflicts conflicts
    if [[ ${#conflicts[@]} -gt 0 ]]; then
        ui_style_subheader "Existing files to back up (${#conflicts[@]})"
        printf '  %s\n' "${conflicts[@]}"
    else
        gum style --foreground 245 "  No existing file conflicts detected."
    fi
}

dotfiles_backup() {
    local -a conflicts=()
    local ts dest target rel

    dotfiles_collect_conflicts conflicts

    if [[ ${#conflicts[@]} -eq 0 ]]; then
        DOTFILES_BACKUP_PATH=""
        export DOTFILES_BACKUP_PATH
        return 0
    fi

    ts="$(date +%Y%m%d-%H%M%S)"
    dest="${HOME}/.os-configs-backup/${ts}"
    mkdir -p "$dest"

    for target in "${conflicts[@]}"; do
        rel="${target#${HOME}/}"
        mkdir -p "$(dirname "${dest}/${rel}")"
        cp -a "$target" "${dest}/${rel}"
    done

    DOTFILES_BACKUP_PATH="$dest"
    export DOTFILES_BACKUP_PATH
    gum style --foreground 10 "Backed up ${#conflicts[@]} file(s) to ${dest}"
}

dotfiles_stow_package() {
    local stow_dir="$1"
    local pkg_name="$2"
    local dry_run="${3:-false}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would run: stow --adopt -R -d ${stow_dir} -t ${HOME} ${pkg_name}"
        return 0
    fi

    stow --adopt -R -d "$stow_dir" -t "$HOME" "$pkg_name"
}

dotfiles_deploy() {
    local dry_run="${1:-false}"
    local auto="${2:-false}"
    local skip="${3:-false}"
    local -a packages=()
    local spec stow_dir pkg_name failed=0

    if [[ "$skip" == "true" ]]; then
        return 0
    fi

    dotfiles_collect_packages packages

    if [[ ${#packages[@]} -eq 0 ]]; then
        return 0
    fi

    ui_style_divider
    ui_style_header "Dotfiles"
    dotfiles_show_plan

    if [[ "$dry_run" == "true" ]]; then
        for spec in "${packages[@]}"; do
            stow_dir="${_dotfiles_root}/${spec%%:*}"
            pkg_name="${spec#*:}"
            dotfiles_stow_package "$stow_dir" "$pkg_name" true
        done
        gum style --foreground 245 "(dry-run — dotfiles not deployed)"
        return 0
    fi

    install_ensure_stow false || return 1

    if [[ "$auto" != "true" ]]; then
        ui_confirm "Back up existing configs and deploy dotfiles?" || {
            gum style --foreground 245 "Dotfiles deploy skipped."
            return 0
        }
    else
        ui_style_subheader "(auto) backing up and deploying dotfiles"
    fi

    dotfiles_backup

    for spec in "${packages[@]}"; do
        stow_dir="${_dotfiles_root}/${spec%%:*}"
        pkg_name="${spec#*:}"
        if ! ui_spin "Stowing ${spec}..." dotfiles_stow_package "$stow_dir" "$pkg_name" false; then
            failed=$((failed + 1))
            gum style --foreground 9 "Failed to stow ${spec}"
        fi
    done

    if [[ -n "$DOTFILES_BACKUP_PATH" ]]; then
        ui_style_subheader "Backup path: ${DOTFILES_BACKUP_PATH}"
        gum style --foreground 245 "Restore with: cp -a '${DOTFILES_BACKUP_PATH}/.' '${HOME}/'"
    fi

    [[ "$failed" -eq 0 ]]
}
