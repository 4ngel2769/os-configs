#!/usr/bin/env bash
set -euo pipefail

tools_expand_path() {
    local path="$1"
    path="${path/#\~/$HOME}"
    echo "$path"
}

tools_brew_path() {
    if command -v brew &>/dev/null; then
        command -v brew
        return 0
    fi
    for candidate in \
        "${HOME}/.linuxbrew/bin/brew" \
        "/home/linuxbrew/.linuxbrew/bin/brew" \
        "/opt/homebrew/bin/brew"; do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

tools_brew_shellenv() {
    local brew_bin
    brew_bin="$(tools_brew_path)" || return 1
    eval "$("$brew_bin" shellenv)"
}

tools_bun_path() {
    if command -v bun &>/dev/null; then
        command -v bun
        return 0
    fi
    if [[ -x "${HOME}/.bun/bin/bun" ]]; then
        echo "${HOME}/.bun/bin/bun"
        return 0
    fi
    return 1
}

tools_bun_shellenv() {
    export BUN_INSTALL="${BUN_INSTALL:-${HOME}/.bun}"
    export PATH="${BUN_INSTALL}/bin:${PATH}"
}

tools_ensure_brew() {
    local dry_run="${1:-false}"

    if tools_brew_path &>/dev/null; then
        tools_brew_shellenv
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would install Homebrew from https://brew.sh"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        echo "tools: curl required to install Homebrew" >&2
        return 1
    fi

    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    tools_brew_shellenv
}

tools_ensure_bun() {
    local dry_run="${1:-false}"

    if tools_bun_path &>/dev/null; then
        tools_bun_shellenv
        return 0
    fi

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would install Bun from https://bun.sh"
        return 0
    fi

    if ! command -v curl &>/dev/null; then
        echo "tools: curl required to install Bun" >&2
        return 1
    fi

    curl -fsSL https://bun.sh/install | bash
    tools_bun_shellenv
}

tools_manager_ready() {
    local manager="$1"
    local ensure_tool="${2:-false}"
    local dry_run="${3:-false}"

    case "$manager" in
        brew)
            if tools_brew_path &>/dev/null; then
                tools_brew_shellenv
                return 0
            fi
            [[ "$ensure_tool" == "true" ]] && tools_ensure_brew "$dry_run"
            ;;
        bun | bunx)
            if tools_bun_path &>/dev/null; then
                tools_bun_shellenv
                return 0
            fi
            [[ "$ensure_tool" == "true" ]] && tools_ensure_bun "$dry_run"
            ;;
        *)
            return 0
            ;;
    esac
}
