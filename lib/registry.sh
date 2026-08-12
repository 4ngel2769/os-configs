#!/usr/bin/env bash
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${_lib_dir}/.." && pwd)}"
REGISTRY_FILE="${REGISTRY_FILE:-${REPO_ROOT}/data/registry.json}"
USER_REGISTRY_FILE="${USER_REGISTRY_FILE:-${REPO_ROOT}/data/user/registry.json}"
USER_CATEGORIES_FILE="${USER_CATEGORIES_FILE:-${REPO_ROOT}/data/user/categories.json}"
CATEGORIES_FILE="${CATEGORIES_FILE:-${REPO_ROOT}/data/categories.json}"

registry_user_file() {
    [[ -f "$USER_REGISTRY_FILE" ]] && echo "$USER_REGISTRY_FILE" || echo /dev/null
}

registry_entry_json() {
    local simple_name="$1"
    local family="$2"
    local base user merged

    base="$(jq -c --arg name "$simple_name" --arg family "$family" \
        '.[$name][$family] // .[$name]["*"] // empty' "$REGISTRY_FILE")"

    if [[ -f "$USER_REGISTRY_FILE" ]]; then
        user="$(jq -c --arg name "$simple_name" --arg family "$family" \
            '.[$name][$family] // .[$name]["*"] // empty' "$USER_REGISTRY_FILE")"
    else
        user=""
    fi

    if [[ -z "$user" || "$user" == "null" ]]; then
        [[ -n "$base" && "$base" != "null" ]] && echo "$base" || echo ""
        return 0
    fi

    if [[ -z "$base" || "$base" == "null" ]]; then
        echo "$user"
        return 0
    fi

    merged="$(jq -nc --argjson a "$base" --argjson b "$user" '$a * $b')"
    echo "$merged"
}

registry_has_entry() {
    local simple_name="$1"
    local family="${DISTRO_FAMILY:?DISTRO_FAMILY must be set}"
    local entry

    entry="$(registry_entry_json "$simple_name" "$family")"
    [[ -n "$entry" && "$entry" != "null" && "$entry" != "" ]]
}

registry_lookup() {
    local simple_name="$1"
    local family="${DISTRO_FAMILY:?DISTRO_FAMILY must be set}"
    local entry

    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo "registry_lookup: registry file not found: $REGISTRY_FILE" >&2
        return 1
    fi

    entry="$(registry_entry_json "$simple_name" "$family")"

    if [[ -z "$entry" || "$entry" == "null" ]]; then
        echo "registry_lookup: no entry for '${simple_name}' on family '${family}'" >&2
        return 1
    fi

    jq -r 'to_entries[]
        | select(.key != "_comment" and .key != "_schema")
        | "\(.key)=\(.value)"' <<<"$entry"
}

registry_merged_json() {
    local user_file
    user_file="$(registry_user_file)"

    if [[ "$user_file" == "/dev/null" ]]; then
        jq '.' "$REGISTRY_FILE"
        return 0
    fi

    jq -s '
        def merge_app($base; $user):
            ($base | keys) + ($user | keys) | unique | map(
                . as $name |
                {
                    ($name): (
                        if ($user[$name] // null) then
                            (($base[$name] // {}) * ($user[$name]))
                        else
                            $base[$name]
                        end
                    )
                }
            ) | add // {};
        merge_app(.[0]; .[1])
    ' "$REGISTRY_FILE" "$user_file"
}

categories_merged_json() {
    local user_file="${USER_CATEGORIES_FILE}"

    if [[ ! -f "$user_file" ]]; then
        jq '.' "$CATEGORIES_FILE"
        return 0
    fi

    jq -s '
        def merge_cats($base; $user):
            ($base | keys) + ($user | keys) | unique | map(
                . as $key |
                {
                    ($key): (
                        if ($base[$key] and $user[$key]) then
                            ($base[$key] * $user[$key])
                            | .apps = ((($base[$key].apps // []) + ($user[$key].apps // [])) | unique)
                        elif ($user[$key]) then
                            $user[$key]
                        else
                            $base[$key]
                        end
                    )
                }
            ) | add // {};
        merge_cats(.[0]; .[1])
    ' "$CATEGORIES_FILE" "$user_file"
}

registry_validate_user() {
    local user_file="${USER_REGISTRY_FILE}"
    local errors=0

    if [[ ! -f "$user_file" ]]; then
        echo "registry: no user registry at ${user_file} (optional)"
        return 0
    fi

    if ! jq empty "$user_file" 2>/dev/null; then
        echo "registry: invalid JSON in ${user_file}" >&2
        return 1
    fi

    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        local families
        families="$(jq -r --arg app "$app" '.[$app] | keys[]' "$user_file")"
        while IFS= read -r family; do
            [[ -n "$family" ]] || continue
            [[ "$family" == "_comment" || "$family" == "_schema" ]] && continue
            local manager
            manager="$(jq -r --arg app "$app" --arg family "$family" \
                '.[$app][$family].manager // empty' "$user_file")"
            if [[ -z "$manager" ]]; then
                echo "registry: ${app}[${family}] missing manager" >&2
                errors=$((errors + 1))
            fi
        done <<<"$families"
    done < <(jq -r 'keys[]' "$user_file" | grep -v '^_' || true)

    [[ "$errors" -eq 0 ]]
}
