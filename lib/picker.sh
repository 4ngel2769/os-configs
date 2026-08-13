#!/usr/bin/env bash
set -euo pipefail

_picker_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${_picker_lib_dir}/.." && pwd)}"

picker_binary() {
    echo "${OS_CONFIGS_BIN:-${HOME}/.cache/os-configs/bin}/os-configs-picker"
}

picker_has_tty() {
    [[ -t 0 && -t 1 ]]
}

picker_can_run() {
    [[ -x "$(picker_binary)" ]] && picker_has_tty
}

picker_build_catalog() {
    local out="$1"
    local reg_tmp cats_tmp

    reg_tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-reg.XXXXXX")"
    cats_tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-cats.XXXXXX")"

    registry_merged_json >"$reg_tmp"
    categories_merged_json >"$cats_tmp"

    jq -n \
        --arg family "${DISTRO_FAMILY:?}" \
        --arg pc "${PLATFORM_CLASS:-desktop}" \
        --arg gpu "${GPU_CLASS:-none}" \
        --slurpfile reg "$reg_tmp" \
        --slurpfile cats "$cats_tmp" \
        '
        ($reg[0]) as $reg |
        ($cats[0]) as $cats |

        def visible($app):
            ($reg[$app] != null) and
            (($reg[$app][$family] // $reg[$app]["*"] // null) != null) and
            (($reg[$app].platforms // ["desktop","laptop"]) | index($pc)) and
            (
                ($reg[$app].requires_gpu // "") == "" or
                ($reg[$app].requires_gpu == null) or
                ($reg[$app].requires_gpu == "gaming" and ($gpu == "igpu-gaming" or $gpu == "dgpu"))
            );

        def app_label($app):
            $reg[$app].label // ($app | gsub("-"; " ") | split(" ") | map(.[0:1] + .[1:]) | join(" "));

        {
            categories: [
                $cats | to_entries[]
                | . as $entry
                | select($entry.key | startswith("_") | not)
                | {
                    id: $entry.key,
                    label: ($entry.value.label // $entry.key),
                    apps: [
                        $entry.value.apps[]?
                        | select(visible(.))
                        | {id: ., label: app_label(.)}
                    ]
                }
                | select(.apps | length > 0)
            ]
            | sort_by(.label)
        }
        ' >"$out"

    rm -f "$reg_tmp" "$cats_tmp"
}

# Writes selections JSON to $1. Do not redirect picker stdout — the TUI renders there.
picker_run() {
    local out_file="$1"
    local catalog picker

    catalog="$(mktemp "${TMPDIR:-/tmp}/os-configs-catalog.XXXXXX")"
    picker="$(picker_binary)"

    picker_build_catalog "$catalog"

    if [[ ! -x "$picker" ]]; then
        echo "picker: os-configs-picker not found at ${picker}" >&2
        rm -f "$catalog"
        return 1
    fi

    if ! picker_has_tty; then
        echo "picker: interactive picker requires a TTY (use: ssh -t host ...)" >&2
        rm -f "$catalog"
        return 1
    fi

    if ! "$picker" --catalog "$catalog" --output "$out_file"; then
        rm -f "$catalog"
        return 1
    fi

    rm -f "$catalog"
}

picker_apply_selections() {
    local json_file="$1"
    local cat_id

    CUSTOM_SELECTION=()

    if ! jq -e '.selections' "$json_file" >/dev/null 2>&1; then
        echo "picker: invalid selections JSON in ${json_file}" >&2
        return 1
    fi

    while IFS= read -r cat_id; do
        [[ -n "$cat_id" ]] || continue
        local -a apps=()
        mapfile -t apps < <(jq -r --arg cat "$cat_id" '.selections[$cat][]?' "$json_file")
        if [[ ${#apps[@]} -gt 0 ]]; then
            CUSTOM_SELECTION["$cat_id"]="${apps[*]}"
        fi
    done < <(jq -r '.selections | keys[]?' "$json_file")
}

picker_fallback_gum() {
    local auto="${1:-false}"
    local key

    for key in $(custom_category_keys); do
        custom_pick_category "$key" "$auto"
    done
}
