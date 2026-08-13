#!/usr/bin/env bash
set -euo pipefail

# os-configs — curl/wget entrypoint for the post-install installer (install.sh)
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh)
#   wget -qO- https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --dry-run --auto
#
# Environment:
#   OS_CONFIGS_REPO   Git clone URL (default: this repo)
#   OS_CONFIGS_DIR    Install/checkout directory (default: ~/os-configs)
#   OS_CONFIGS_REF    Branch or tag (default: main)

OS_CONFIGS_REPO="${OS_CONFIGS_REPO:-https://github.com/4ngel2769/os-configs.git}"
OS_CONFIGS_DIR="${OS_CONFIGS_DIR:-${HOME}/os-configs}"
OS_CONFIGS_REF="${OS_CONFIGS_REF:-main}"

_bootstrap_msg() { printf '[bootstrap] %s\n' "$*" >&2; }

_bootstrap_is_remote() {
    local src="${BASH_SOURCE[0]:-}"
    [[ -n "$src" && -r "$src" && "$(basename "$src")" == "bootstrap.sh" ]] && return 1
    return 0
}

_bootstrap_download() {
    local url="$1"
    local dest="$2"

    if command -v curl &>/dev/null; then
        curl -fsSL -o "$dest" "$url"
        return 0
    fi
    if command -v wget &>/dev/null; then
        wget -qO "$dest" "$url"
        return 0
    fi

    _bootstrap_msg "curl, wget, or git is required to fetch the repo"
    return 1
}

_bootstrap_fetch_tarball() {
    local dest="$1"
    local url tmp inner

    url="https://github.com/4ngel2769/os-configs/archive/refs/heads/${OS_CONFIGS_REF}.tar.gz"
    tmp="$(mktemp -d)"
    _bootstrap_msg "fetching ${OS_CONFIGS_REF} tarball..."

    _bootstrap_download "$url" "${tmp}/repo.tgz"
    tar -xzf "${tmp}/repo.tgz" -C "$tmp"
    inner="${tmp}/os-configs-${OS_CONFIGS_REF}"

    if [[ ! -d "$inner" ]]; then
        _bootstrap_msg "unexpected archive layout (missing ${inner})"
        rm -rf "$tmp"
        return 1
    fi

    mkdir -p "$dest"
    shopt -s dotglob nullglob
    rm -rf "${dest:?}"/*
    cp -a "${inner}/." "$dest/"
    shopt -u dotglob nullglob
    rm -rf "$tmp"
}

_bootstrap_clone_git() {
    local dest="$1"

    if [[ -d "${dest}/.git" ]]; then
        _bootstrap_msg "updating ${dest} (${OS_CONFIGS_REF})..."
        git -C "$dest" fetch --depth 1 origin "$OS_CONFIGS_REF"
        git -C "$dest" checkout "$OS_CONFIGS_REF"
        git -C "$dest" reset --hard "origin/${OS_CONFIGS_REF}"
        return 0
    fi

    if [[ -e "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null || true)" ]]; then
        _bootstrap_msg "replacing non-git checkout at ${dest}..."
        rm -rf "$dest"
    fi

    _bootstrap_msg "cloning ${OS_CONFIGS_REPO} → ${dest}..."
    git clone --depth 1 --branch "$OS_CONFIGS_REF" "$OS_CONFIGS_REPO" "$dest"
}

_bootstrap_ensure_repo() {
    if command -v git &>/dev/null; then
        _bootstrap_clone_git "$OS_CONFIGS_DIR"
    else
        _bootstrap_fetch_tarball "$OS_CONFIGS_DIR"
    fi

    if [[ ! -x "${OS_CONFIGS_DIR}/install.sh" ]]; then
        _bootstrap_msg "install.sh not found in ${OS_CONFIGS_DIR}"
        return 1
    fi
}

_bootstrap_repo_root() {
    if _bootstrap_is_remote; then
        _bootstrap_ensure_repo
        printf '%s\n' "$OS_CONFIGS_DIR"
        return 0
    fi

    cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

main() {
    local root
    root="$(_bootstrap_repo_root)"
    cd "$root"
    export REPO_ROOT="$root"
    exec bash "${root}/install.sh" "$@"
}

main "$@"
