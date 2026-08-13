#!/usr/bin/env bash
set -euo pipefail

# os-configs — curl/wget entrypoint for the post-install installer (install.sh)
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh)
#   wget -qO- https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh | bash
#   wget -qO- .../bootstrap.sh | bash -s -- --dry-run --auto
#
# Environment:
#   OS_CONFIGS_REPO   Git clone URL (default: this repo)
#   OS_CONFIGS_DIR    Checkout directory (default: ~/.os-configs)
#   OS_CONFIGS_REF    Branch or tag (default: main)

OS_CONFIGS_REPO="${OS_CONFIGS_REPO:-https://github.com/4ngel2769/os-configs.git}"
OS_CONFIGS_DIR="${OS_CONFIGS_DIR:-${HOME}/.os-configs}"
OS_CONFIGS_REF="${OS_CONFIGS_REF:-main}"

_bootstrap_msg() { printf '[bootstrap] %s\n' "$*" >&2; }

# Only use a local tree when bootstrap.sh and install.sh live together (git clone).
# Piped runs (wget | bash) invoke /usr/bin/bash — never treat that as a local checkout.
_bootstrap_local_root() {
    local src="${BASH_SOURCE[0]:-}"
    local dir

    [[ -n "$src" && -f "$src" && "$(basename "$src")" == "bootstrap.sh" ]] || return 1
    dir="$(cd "$(dirname "$src")" && pwd)"
    [[ -f "${dir}/install.sh" ]] || return 1
    printf '%s\n' "$dir"
}

_bootstrap_ensure_git() {
    if command -v git &>/dev/null; then
        return 0
    fi

    _bootstrap_msg "git not found — installing..."

    if [[ ! -f /etc/os-release ]]; then
        _bootstrap_msg "cannot install git automatically (no /etc/os-release)"
        return 1
    fi

    # shellcheck source=/dev/null
    . /etc/os-release
    local id="${ID:-unknown}"

    case "${id,,}" in
        ubuntu | debian | linuxmint | pop | pop-os | zorin | elementary | neon)
            sudo apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y git
            ;;
        fedora | nobara | ultramarine)
            sudo dnf install -y git
            ;;
        arch | endeavouros | manjaro | garuda | cachyos)
            sudo pacman -Sy --noconfirm git
            ;;
        *)
            _bootstrap_msg "unsupported OS for auto git install: ${id}"
            _bootstrap_msg "install git manually, then re-run this command"
            return 1
            ;;
    esac

    command -v git &>/dev/null
}

_bootstrap_sync_repo() {
    local dest="$1"

    _bootstrap_ensure_git

    mkdir -p "$(dirname "$dest")"

    if [[ -d "${dest}/.git" ]]; then
        _bootstrap_msg "updating ${dest} (${OS_CONFIGS_REF})..."
        git -C "$dest" fetch --depth 1 origin "$OS_CONFIGS_REF"
        git -C "$dest" checkout -f "$OS_CONFIGS_REF" 2>/dev/null || git -C "$dest" checkout -f -B "$OS_CONFIGS_REF" "origin/${OS_CONFIGS_REF}"
        git -C "$dest" reset --hard "origin/${OS_CONFIGS_REF}"
        return 0
    fi

    if [[ -e "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null || true)" ]]; then
        _bootstrap_msg "replacing existing files at ${dest}..."
        rm -rf "$dest"
    fi

    _bootstrap_msg "cloning ${OS_CONFIGS_REPO} → ${dest}..."
    git clone --depth 1 --branch "$OS_CONFIGS_REF" "$OS_CONFIGS_REPO" "$dest"
}

_bootstrap_fetch_remote() {
    _bootstrap_sync_repo "$OS_CONFIGS_DIR"

    if [[ ! -f "${OS_CONFIGS_DIR}/install.sh" ]]; then
        _bootstrap_msg "install.sh not found after fetching ${OS_CONFIGS_DIR}"
        return 1
    fi

    printf '%s\n' "$OS_CONFIGS_DIR"
}

_bootstrap_repo_root() {
    local local_root=""

    if local_root="$(_bootstrap_local_root 2>/dev/null)"; then
        printf '%s\n' "$local_root"
        return 0
    fi

    _bootstrap_fetch_remote
}

main() {
    local root

    root="$(_bootstrap_repo_root)"
    if [[ ! -f "${root}/install.sh" ]]; then
        _bootstrap_msg "no install.sh at ${root} — fetch failed"
        exit 1
    fi

    cd "$root"
    export REPO_ROOT="$root"
    _bootstrap_msg "running ${root}/install.sh $*"
    exec bash "${root}/install.sh" "$@"
}

main "$@"
