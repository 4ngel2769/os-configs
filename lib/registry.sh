#!/usr/bin/env bash
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${_lib_dir}/.." && pwd)}"
REGISTRY_FILE="${REGISTRY_FILE:-${REPO_ROOT}/data/registry.json}"
USER_REGISTRY_FILE="${USER_REGISTRY_FILE:-${REPO_ROOT}/data/user/registry.json}"
USER_CATEGORIES_FILE="${USER_CATEGORIES_FILE:-${REPO_ROOT}/data/user/categories.json}"
CATEGORIES_FILE="${CATEGORIES_FILE:-${REPO_ROOT}/data/categories.json}"
CATALOG_DIR="${REPO_ROOT}/data/catalog"

registry_fragment_files() {
    local f
    for f in \
        "$REGISTRY_FILE" \
        "${CATALOG_DIR}/registry-arco.json" \
        "${CATALOG_DIR}/extras.json" \
        "$USER_REGISTRY_FILE"; do
        [[ -f "$f" ]] && printf '%s\n' "$f"
    done
}

categories_fragment_files() {
    local f
    for f in \
        "$CATEGORIES_FILE" \
        "${CATALOG_DIR}/categories-arco.json" \
        "${CATALOG_DIR}/categories-extras.json" \
        "$USER_CATEGORIES_FILE"; do
        [[ -f "$f" ]] && printf '%s\n' "$f"
    done
}

registry_merged_json() {
    local -a files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(registry_fragment_files)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo '{}'
        return 0
    fi

    jq -s '
        def merge_app($a; $b):
            ($a | keys) + ($b | keys) | unique | map(
                . as $name |
                {
                    ($name): (
                        if ($b[$name] // null) then
                            (($a[$name] // {}) * ($b[$name]))
                        else
                            $a[$name]
                        end
                    )
                }
            ) | add // {};
        reduce .[] as $item ({}; merge_app(.; $item))
    ' "${files[@]}"
}

registry_entry_json() {
    local simple_name="$1"
    local family="$2"

    registry_merged_json | jq -c --arg name "$simple_name" --arg family "$family" \
        '.[$name][$family] // .[$name]["*"] // empty'
}

registry_app_label() {
    local simple_name="$1"
    registry_merged_json | jq -r --arg name "$simple_name" \
        '.[$name].label // ($name | gsub("-"; " ") | split(" ") | map(.[0:1] + .[1:]) | join(" "))'
}

registry_app_platforms_json() {
    local simple_name="$1"
    registry_merged_json | jq -c --arg name "$simple_name" \
        '.[$name].platforms // ["desktop","laptop"]'
}

registry_app_requires_gpu() {
    local simple_name="$1"
    registry_merged_json | jq -r --arg name "$simple_name" \
        '.[$name].requires_gpu // empty'
}

registry_has_entry() {
    local simple_name="$1"
    local family="${2:-${DISTRO_FAMILY:-}}"
    local entry

    if [[ -z "$family" ]]; then
        echo "registry_has_entry: family required (set DISTRO_FAMILY or pass as 2nd arg)" >&2
        return 1
    fi

    entry="$(registry_entry_json "$simple_name" "$family")"
    [[ -n "$entry" && "$entry" != "null" && "$entry" != "" ]]
}

registry_app_visible() {
    local simple_name="$1"
    local family="${DISTRO_FAMILY:?DISTRO_FAMILY must be set}"
    local pc="${PLATFORM_CLASS:-desktop}"
    local gpu="${GPU_CLASS:-none}"

    registry_merged_json | jq -e \
        --arg name "$simple_name" \
        --arg family "$family" \
        --arg pc "$pc" \
        --arg gpu "$gpu" '
        .[$name] as $app |
        ($app != null) and
        (($app[$family] // $app["*"] // null) != null) and
        (($app.platforms // ["desktop","laptop"]) | index($pc)) and
        (
            ($app.requires_gpu // "") == "" or
            $app.requires_gpu == null or
            ($app.requires_gpu == "gaming" and ($gpu == "igpu-gaming" or $gpu == "dgpu"))
        )
    ' >/dev/null
}

registry_lookup() {
    local simple_name="$1"
    local family="${DISTRO_FAMILY:?DISTRO_FAMILY must be set}"
    local entry

    entry="$(registry_entry_json "$simple_name" "$family")"

    if [[ -z "$entry" || "$entry" == "null" ]]; then
        echo "registry_lookup: no entry for '${simple_name}' on family '${family}'" >&2
        return 1
    fi

    jq -r 'to_entries[]
        | select(.key != "_comment" and .key != "_schema")
        | "\(.key)=\(.value)"' <<<"$entry"
}

categories_merged_json() {
    local -a files=()
    while IFS= read -r f; do
        files+=("$f")
    done < <(categories_fragment_files)

    if [[ ${#files[@]} -eq 0 ]]; then
        echo '{}'
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
        def normalize($cats):
            if ($cats.browser != null) then
                if ($cats.browsers != null) then
                    $cats
                    | .browsers.apps = ((.browsers.apps // []) + (.browser.apps // []) | unique)
                    | del(.browser)
                else
                    $cats
                    | .browsers = (.browser + {label: (.browser.label // "Browsers")})
                    | del(.browser)
                end
            else
                $cats
            end;
        reduce .[] as $item ({}; merge_cats(.; $item))
        | normalize(.)
    ' "${files[@]}"
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
            [[ "$family" == "_comment" || "$family" == "_schema" || "$family" == "label" || "$family" == "platforms" || "$family" == "requires_gpu" ]] && continue
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
