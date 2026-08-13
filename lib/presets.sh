#!/usr/bin/env bash
set -euo pipefail

_presets_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_presets_registry="${REPO_ROOT:-$(cd "${_presets_lib_dir}/.." && pwd)}/data/registry.json"

preset_flatten_apps() {
    local file="$1"
    jq -r '[.categories[] | .[]] | unique | .[]' "$file"
}

preset_validate_registry() {
    local file="$1"
    local family="$2"
    local app missing=0

    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        if ! registry_has_entry "$app" "$family"; then
            echo "preset: '${app}' in $(basename "$file") has no registry entry for family '${family}'" >&2
            missing=$((missing + 1))
        fi
    done < <(preset_flatten_apps "$file")

    [[ "$missing" -eq 0 ]]
}

preset_validate_family() {
    local family="$1"
    local file dir="${REPO_ROOT}/data/presets"
    local failed=0

    for file in "${dir}"/*.json; do
        [[ -f "$file" ]] || continue
        preset_validate_registry "$file" "$family" || failed=$((failed + 1))
    done

    [[ "$failed" -eq 0 ]]
}

preset_validate_all() {
    local family failed=0

    for family in arch debian ubuntu fedora; do
        preset_validate_family "$family" || failed=$((failed + 1))
    done

    [[ "$failed" -eq 0 ]]
}

preset_summary_line() {
    local file="$1"
    local name count
    name="$(jq -r '.name' "$file")"
    count="$(jq -r '[.categories[] | .[]] | length' "$file")"
    printf '%s (%s apps)' "$name" "$count"
}
