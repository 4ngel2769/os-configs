#!/usr/bin/env bash
set -euo pipefail

_log_success=()
_log_failed=()

log_record_success() {
    _log_success+=("$1")
}

log_record_failure() {
    _log_failed+=("$1")
}

log_print_summary() {
    ui_style_divider
    ui_style_header "Install summary"

    if [[ ${#_log_success[@]} -gt 0 ]]; then
        gum style --foreground 10 "Succeeded (${#_log_success[@]}):"
        printf '  %s\n' "${_log_success[@]}"
    fi

    if [[ ${#_log_failed[@]} -gt 0 ]]; then
        gum style --foreground 9 "Failed (${#_log_failed[@]}):"
        printf '  %s\n' "${_log_failed[@]}"
    fi

    if [[ ${#_log_failed[@]} -eq 0 && ${#_log_success[@]} -gt 0 ]]; then
        gum style --foreground 10 "All packages installed successfully."
    fi
}

log_reset() {
    _log_success=()
    _log_failed=()
}
