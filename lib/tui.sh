#!/usr/bin/env bash
set -euo pipefail

_tui_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TUI_FILE="${TUI_FILE:-${REPO_ROOT:-$(cd "${_tui_lib_dir}/.." && pwd)}/data/tui.json}"

tui_str() {
    local key="$1"
    local fallback="${2:-$key}"

    if [[ ! -f "$TUI_FILE" ]]; then
        printf '%s' "$fallback"
        return 0
    fi

    jq -r --arg k "$key" --arg fb "$fallback" '.strings[$k] // $fb' "$TUI_FILE"
}

# tui_strf key platform=Desktop gpu="Gaming iGPU" ...
tui_strf() {
    local key="$1"
    shift
    local out value pair var_name

    out="$(tui_str "$key")"
    for pair in "$@"; do
        var_name="${pair%%=*}"
        value="${pair#*=}"
        out="${out//\{\{$var_name\}\}/$value}"
    done
    printf '%s' "$out"
}

tui_theme_color() {
    local key="$1"
    local fallback="${2:-252}"

    if [[ ! -f "$TUI_FILE" ]]; then
        printf '%s' "$fallback"
        return 0
    fi

    jq -r --arg k "$key" --arg fb "$fallback" '.theme[$k] // $fb' "$TUI_FILE"
}

tui_picker_args() {
    if [[ -f "$TUI_FILE" ]]; then
        printf '%s' "--tui" "$TUI_FILE"
    fi
}
