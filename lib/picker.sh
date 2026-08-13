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
    if ! picker_has_tty; then
        return 1
    fi
    local bin
    bin="$(picker_binary)"
    [[ -x "$bin" ]] || return 1
    if declare -F _deps_picker_valid_elf &>/dev/null; then
        _deps_picker_valid_elf "$bin"
        return $?
    fi
    return 0
}

# phase: main (core catalog), arco (extended catalog), all (legacy full merge)
picker_build_catalog() {
    local out="$1"
    local phase="${2:-main}"
    local reg_tmp cats_tmp
    local title subtitle reg_fn cats_fn

    reg_tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-reg.XXXXXX")"
    cats_tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-cats.XXXXXX")"

    case "$phase" in
        arco)
            reg_fn=registry_merged_json
            cats_fn=categories_arco_json
            title="More apps"
            subtitle="Extended catalog"
            ;;
        all)
            reg_fn=registry_merged_json
            cats_fn=categories_merged_json
            title="Custom software"
            subtitle=""
            ;;
        main | *)
            reg_fn=registry_main_json
            cats_fn=categories_main_json
            title="Custom software"
            subtitle=""
            ;;
    esac

    "$reg_fn" >"$reg_tmp"
    "$cats_fn" >"$cats_tmp"

    jq -n \
        --arg family "${DISTRO_FAMILY:?}" \
        --arg pc "${PLATFORM_CLASS:-desktop}" \
        --arg gpu "${GPU_CLASS:-none}" \
        --arg distro_id "${DISTRO_ID:-unknown}" \
        --arg distro_label "$(ui_distro_label)" \
        --arg distro_color "$(ui_distro_color)" \
        --arg machine_arch "$(uname -m 2>/dev/null || true)" \
        --arg platform_label "$(ui_platform_label "${PLATFORM_CLASS:-desktop}")" \
        --arg gpu_label "$(ui_gpu_label "${GPU_CLASS:-none}")" \
        --arg title "$title" \
        --arg subtitle "$subtitle" \
        --argjson show_gpu "$( [[ "${PLATFORM_CLASS:-}" != "server" ]] && echo true || echo false )" \
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
            banner: {
                distro_id: $distro_id,
                distro_label: $distro_label,
                distro_color: $distro_color,
                machine_arch: $machine_arch,
                platform_label: $platform_label,
                gpu_label: $gpu_label,
                show_gpu: $show_gpu
            },
            title: $title,
            subtitle: $subtitle,
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

picker_arco_has_apps() {
    local tmp count
    [[ -f "${REPO_ROOT}/data/catalog/categories-arco.json" ]] || return 1
    tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-arco-check.XXXXXX")"
    picker_build_catalog "$tmp" arco
    count="$(jq '[.categories[].apps | length] | add // 0' "$tmp")"
    rm -f "$tmp"
    [[ "${count:-0}" -gt 0 ]]
}

# Writes selections JSON to $1. Do not redirect picker stdout — the TUI renders there.
# Optional 2nd arg: catalog phase (main|arco).
picker_run() {
    local out_file="$1"
    local phase="${2:-main}"
    local catalog picker

    catalog="$(mktemp "${TMPDIR:-/tmp}/os-configs-catalog.XXXXXX")"
    picker="$(picker_binary)"

    picker_build_catalog "$catalog" "$phase"

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

picker_merge_selections() {
    local json_file="$1"
    local cat_id

    if ! jq -e '.selections' "$json_file" >/dev/null 2>&1; then
        echo "picker: invalid selections JSON in ${json_file}" >&2
        return 1
    fi

    while IFS= read -r cat_id; do
        [[ -n "$cat_id" ]] || continue
        local -a apps=() merged=() existing
        mapfile -t apps < <(jq -r --arg cat "$cat_id" '.selections[$cat][]?' "$json_file")
        [[ ${#apps[@]} -gt 0 ]] || continue

        existing="${CUSTOM_SELECTION[$cat_id]:-}"
        if [[ -n "$existing" ]]; then
            read -r -a merged <<<"$existing"
            merged+=("${apps[@]}")
            mapfile -t merged < <(printf '%s\n' "${merged[@]}" | awk '!seen[$0]++')
            CUSTOM_SELECTION["$cat_id"]="${merged[*]}"
        else
            CUSTOM_SELECTION["$cat_id"]="${apps[*]}"
        fi
    done < <(jq -r '.selections | keys[]?' "$json_file")
}

picker_offer_arco_catalog() {
    local auto="${1:-false}"
    local pick_file

    [[ "$auto" == "true" ]] && return 1
    picker_arco_has_apps || return 1
    ui_picker_menu_offer || return 1

    pick_file="$(mktemp "${TMPDIR:-/tmp}/os-configs-pick-arco.XXXXXX")"
    if picker_run "$pick_file" arco; then
        picker_merge_selections "$pick_file"
        rm -f "$pick_file"
        return 0
    fi
    rm -f "$pick_file"
    return 1
}

picker_banner_json() {
    local gpu_label show_gpu="false"

    if [[ "${PLATFORM_CLASS:-}" != "server" ]]; then
        gpu_label="$(ui_gpu_label "${GPU_CLASS:-none}")"
        show_gpu="true"
    fi

    jq -n \
        --arg distro_id "${DISTRO_ID:-unknown}" \
        --arg distro_label "$(ui_distro_label)" \
        --arg distro_color "$(ui_distro_color)" \
        --arg machine_arch "$(uname -m 2>/dev/null || true)" \
        --arg platform_label "$(ui_platform_label "${PLATFORM_CLASS:-desktop}")" \
        --arg gpu_label "$gpu_label" \
        --argjson show_gpu "$show_gpu" \
        '{
            distro_id: $distro_id,
            distro_label: $distro_label,
            distro_color: $distro_color,
            machine_arch: $machine_arch,
            platform_label: $platform_label,
            gpu_label: $gpu_label,
            show_gpu: $show_gpu
        }'
}

menu_picker_run() {
    local out_file="$1"
    local input_file="$2"
    local picker

    picker="$(picker_binary)"

    if [[ ! -f "$input_file" ]]; then
        echo "picker: menu input not found: ${input_file}" >&2
        return 1
    fi

    if [[ ! -x "$picker" ]]; then
        echo "picker: os-configs-picker not found at ${picker}" >&2
        return 1
    fi

    if ! picker_has_tty; then
        echo "picker: menu picker requires a TTY (use: ssh -t host ...)" >&2
        return 1
    fi

    "$picker" --menu "$input_file" --output "$out_file"
}

# Writes preset choice JSON { "choice": "<id>|custom" } to $1 using input JSON at $2.
preset_picker_run() {
    local out_file="$1"
    local input_file="$2"
    local picker

    picker="$(picker_binary)"

    if [[ ! -f "$input_file" ]]; then
        echo "picker: preset input not found: ${input_file}" >&2
        return 1
    fi

    if [[ ! -x "$picker" ]]; then
        echo "picker: os-configs-picker not found at ${picker}" >&2
        return 1
    fi

    if ! picker_has_tty; then
        echo "picker: preset grid requires a TTY (use: ssh -t host ...)" >&2
        return 1
    fi

    "$picker" --presets "$input_file" --output "$out_file"
}

picker_fallback_gum() {
    local auto="${1:-false}"
    local key

    for key in $(custom_main_category_keys); do
        custom_pick_category "$key" "$auto" main
    done

    if [[ "$auto" != "true" ]] && picker_arco_has_apps; then
        if ui_picker_menu_offer; then
            for key in $(custom_arco_category_keys); do
                custom_pick_category "$key" false arco
            done
        fi
    fi
}
