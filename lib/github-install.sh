#!/usr/bin/env bash
set -euo pipefail

_github_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

github_expand_path() {
    local path="$1"
    path="${path/#\~/$HOME}"
    echo "$path"
}

github_install_release() {
    local repo="$1"
    local asset_pattern="$2"
    local bin_name="$3"
    local install_dir="$4"
    local dry_run="${5:-false}"
    local cache_dir url tmpdir asset_name dest

    cache_dir="$(github_expand_path "${OS_CONFIGS_CACHE:-${HOME}/.cache}/os-configs/github")"
    install_dir="$(github_expand_path "$install_dir")"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would fetch latest release from github.com/${repo}"
        echo "[dry-run] would match asset: ${asset_pattern}"
        echo "[dry-run] would install ${bin_name} to ${install_dir}/"
        return 0
    fi

    mkdir -p "$cache_dir" "$install_dir"

    url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r --arg pat "$asset_pattern" '.assets[] | select(.name | test($pat)) | .browser_download_url' \
        | head -1)"

    if [[ -z "$url" || "$url" == "null" ]]; then
        echo "github: no release asset matching '${asset_pattern}' for ${repo}" >&2
        return 1
    fi

    asset_name="${url##*/}"
    tmpdir="$(mktemp -d "${cache_dir}/${bin_name}.XXXXXX")"

    curl -fsSL "$url" -o "${tmpdir}/${asset_name}"

    case "$asset_name" in
        *.tar.gz | *.tgz)
            tar -xzf "${tmpdir}/${asset_name}" -C "$tmpdir"
            ;;
        *.tar.xz)
            tar -xJf "${tmpdir}/${asset_name}" -C "$tmpdir"
            ;;
        *.zip)
            unzip -q "${tmpdir}/${asset_name}" -d "$tmpdir"
            ;;
        *)
            install -m 755 "${tmpdir}/${asset_name}" "${install_dir}/${bin_name}"
            rm -rf "$tmpdir"
            return 0
            ;;
    esac

    local found
    found="$(find "$tmpdir" -type f -name "$bin_name" | head -1)"
    if [[ -z "$found" ]]; then
        found="$(find "$tmpdir" -type f -executable | head -1)"
    fi

    if [[ -z "$found" ]]; then
        echo "github: could not find binary '${bin_name}' in ${asset_name}" >&2
        rm -rf "$tmpdir"
        return 1
    fi

    install -m 755 "$found" "${install_dir}/${bin_name}"
    rm -rf "$tmpdir"
}

github_install_script() {
    local repo="$1"
    local script_path="$2"
    local ref="$3"
    local dry_run="${4:-false}"
    local url

    url="https://raw.githubusercontent.com/${repo}/${ref}/${script_path}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would download and run: ${url}"
        return 0
    fi

    curl -fsSL "$url" | bash
}

github_install_build_deps() {
    local -a deps=()
    local dep pkg_mgr="${PKG_MANAGER:-apt}"
    local dry_run="${1:-false}"
    shift
    deps=("$@")

    for dep in "${deps[@]}"; do
        [[ -n "$dep" ]] || continue
        case "$pkg_mgr" in
            apt)
                if [[ "$dry_run" == "true" ]]; then
                    echo "[dry-run] would run: sudo apt-get install -y ${dep}"
                else
                    sudo apt-get install -y "$dep" || return 1
                fi
                ;;
            dnf)
                if [[ "$dry_run" == "true" ]]; then
                    echo "[dry-run] would run: sudo dnf install -y ${dep}"
                else
                    sudo dnf install -y "$dep" || return 1
                fi
                ;;
            pacman)
                if [[ "$dry_run" == "true" ]]; then
                    echo "[dry-run] would run: sudo pacman -S --needed --noconfirm ${dep}"
                else
                    sudo pacman -S --needed --noconfirm "$dep" || return 1
                fi
                ;;
        esac
    done
}

github_install_build() {
    local repo="$1"
    local clone_dir="$2"
    local ref="$3"
    local build_cmd="$4"
    local dry_run="${5:-false}"
    local -a build_packages=()
    local pkg

    if [[ -n "${6:-}" ]]; then
        IFS=',' read -r -a build_packages <<<"$6"
    fi

    clone_dir="$(github_expand_path "$clone_dir")"

    if [[ ${#build_packages[@]} -gt 0 ]]; then
        github_install_build_deps "$dry_run" "${build_packages[@]}" || return 1
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would clone https://github.com/${repo}.git (${ref}) to ${clone_dir}"
        echo "[dry-run] would run: ${build_cmd}"
        return 0
    fi

    mkdir -p "$(dirname "$clone_dir")"
    if [[ -d "$clone_dir/.git" ]]; then
        git -C "$clone_dir" fetch --depth 1 origin "$ref"
        git -C "$clone_dir" checkout "$ref"
        git -C "$clone_dir" pull --ff-only || true
    else
        git clone --depth 1 --branch "$ref" "https://github.com/${repo}.git" "$clone_dir"
    fi

    bash -c "cd $(printf '%q' "$clone_dir") && ${build_cmd}"
}

github_install_app() {
    local simple_name="$1"
    local dry_run="${2:-false}"

    case "${INSTALL_METHOD:-release}" in
        release)
            github_install_release \
                "${INSTALL_REPO:?}" \
                "${INSTALL_ASSET_PATTERN:?}" \
                "${INSTALL_BIN:-$simple_name}" \
                "${INSTALL_INSTALL_DIR:-${HOME}/.local/bin}" \
                "$dry_run"
            ;;
        script)
            github_install_script \
                "${INSTALL_REPO:?}" \
                "${INSTALL_SCRIPT_PATH:?}" \
                "${INSTALL_REF:-main}" \
                "$dry_run"
            ;;
        build)
            github_install_build \
                "${INSTALL_REPO:?}" \
                "${INSTALL_CLONE_DIR:-${HOME}/.cache/os-configs/build/${simple_name}}" \
                "${INSTALL_REF:-main}" \
                "${INSTALL_BUILD_CMD:?}" \
                "$dry_run" \
                "${INSTALL_BUILD_PACKAGES:-}"
            ;;
        *)
            echo "github: unsupported method '${INSTALL_METHOD}' for ${simple_name}" >&2
            return 1
            ;;
    esac
}
