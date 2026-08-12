#!/usr/bin/env bash
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTRY_FILE="${REGISTRY_FILE:-${_lib_dir}/../data/registry.json}"

registry_lookup() {
    local simple_name="$1"
    local family="${DISTRO_FAMILY:?DISTRO_FAMILY must be set}"

    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo "registry_lookup: registry file not found: $REGISTRY_FILE" >&2
        return 1
    fi

    local has_entry
    has_entry="$(jq -r --arg name "$simple_name" --arg family "$family" \
        '.[$name][$family] // empty' "$REGISTRY_FILE")"

    if [[ -z "$has_entry" ]]; then
        echo "registry_lookup: no entry for '${simple_name}' on family '${family}'" >&2
        return 1
    fi

    local manager package source component
    manager="$(jq -r '.manager' <<<"$has_entry")"
    package="$(jq -r '.package' <<<"$has_entry")"
    source="$(jq -r '.source // empty' <<<"$has_entry")"
    component="$(jq -r '.component // empty' <<<"$has_entry")"

    printf 'manager=%s\npackage=%s\nsource=%s\ncomponent=%s\n' \
        "$manager" "$package" "$source" "$component"
}
