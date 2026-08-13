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

picker_store_flags_json() {
    jq -n \
        --argjson has_aur "$( [[ -n "${AUR_HELPER:-}" ]] && echo true || echo false )" \
        --argjson has_flatpak "$( command -v flatpak &>/dev/null && echo true || echo false )" \
        --argjson has_snap "$( command -v snap &>/dev/null && echo true || echo false )" \
        --argjson has_brew "$( command -v brew &>/dev/null && echo true || echo false )" \
        --argjson has_bun "$( command -v bun &>/dev/null && echo true || echo false )" \
        '{
            has_aur: $has_aur,
            has_flatpak: $has_flatpak,
            has_snap: $has_snap,
            has_brew: $has_brew,
            has_bun: $has_bun
        }'
}

picker_banner_json() {
    local show_gpu="false"
    if [[ "${PLATFORM_CLASS:-desktop}" != "server" ]]; then
        show_gpu="true"
    fi

    jq -n \
        --arg distro_label "$(ui_distro_label)" \
        --arg distro_color "$(ui_distro_color)" \
        --arg platform_label "$(ui_platform_label "${PLATFORM_CLASS:-desktop}")" \
        --arg gpu_label "$(ui_gpu_label "${GPU_CLASS:-none}")" \
        --argjson show_gpu "$show_gpu" \
        '{
            distro_label: $distro_label,
            distro_color: $distro_color,
            platform_label: $platform_label,
            gpu_label: $gpu_label,
            show_gpu: $show_gpu
        }'
}

picker_build_catalog() {
    local out="$1"
    local reg_tmp cats_tmp stores

    reg_tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-reg.XXXXXX")"
    cats_tmp="$(mktemp "${TMPDIR:-/tmp}/os-configs-cats.XXXXXX")"
    stores="$(picker_store_flags_json)"

    registry_merged_json >"$reg_tmp"
    categories_merged_json >"$cats_tmp"

    jq -n \
        --arg family "${DISTRO_FAMILY:?}" \
        --arg pc "${PLATFORM_CLASS:-desktop}" \
        --arg gpu "${GPU_CLASS:-none}" \
        --argjson stores "$stores" \
        --slurpfile reg "$reg_tmp" \
        --slurpfile cats "$cats_tmp" \
        '
        ($reg[0]) as $reg |
        ($cats[0]) as $cats |
        ($stores) as $st |

        def family_entry($app):
            ($reg[$app][$family] // $reg[$app]["*"] // null);

        def visible($app):
            ($reg[$app] != null) and
            (family_entry($app) != null) and
            (($reg[$app].platforms // ["desktop","laptop"]) | index($pc)) and
            (
                ($reg[$app].requires_gpu // "") == "" or
                ($reg[$app].requires_gpu == null) or
                ($reg[$app].requires_gpu == "gaming" and ($gpu == "igpu-gaming" or $gpu == "dgpu"))
            );

        def app_label($app):
            $reg[$app].label // ($app | gsub("-"; " ") | split(" ") | map(.[0:1] + .[1:]) | join(" "));

        def install_note($app):
            family_entry($app) as $e |
            if $e == null then null
            elif ($e.manager // "") == "aur" and ($st.has_aur | not) then "via AUR · needs yay/paru"
            elif ($e.manager // "") == "flatpak" and ($st.has_flatpak | not) then "via Flatpak · install flatpak"
            elif ($e.manager // "") == "snap" and ($st.has_snap | not) then "via Snap · install snapd"
            elif ($e.manager // "") == "brew" and ($st.has_brew | not) then "via Homebrew · install brew"
            elif ($e.manager // "") == "bun" and ($st.has_bun | not) then "via Bun · install bun"
            elif ($e.manager // "") == "github" then "via GitHub release"
            elif ($e.manager // "") == "aur" then "via AUR"
            elif ($e.manager // "") == "flatpak" then "via Flatpak"
            elif ($e.manager // "") == "snap" then "via Snap"
            elif ($e.manager // "") == "brew" then "via Homebrew"
            elif ($e.manager // "") == "bun" then "via Bun"
            else null
            end;

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
                        | . as $app
                        | {id: $app, label: app_label($app), note: install_note($app)}
                        | if .note == null then del(.note) else . end
                    ]
                }
                | select(.apps | length > 0)
            ]
            | sort_by(.label)
        }
        ' >"$out"

    rm -f "$reg_tmp" "$cats_tmp"
}

# Writes menu result JSON to $1 from input JSON at $2.
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

    for key in $(custom_category_keys); do
        custom_pick_category "$key" "$auto"
    done
}
