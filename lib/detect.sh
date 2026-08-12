#!/usr/bin/env bash
# shellcheck disable=SC2034
# Exported detection variables are consumed by other lib modules when sourced.
set -euo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_data_dir="${_lib_dir}/../data"

DISTRO_FAMILY=""
DISTRO_ID=""
PKG_MANAGER=""
AUR_HELPER=""
PLATFORM_CLASS=""
GPU_CLASS=""
DE_WM=""
COMPOSITOR=""
INIT_SYSTEM=""

_detect_read_os_release() {
    if [[ ! -f /etc/os-release ]]; then
        echo "detect: /etc/os-release not found" >&2
        return 1
    fi
    # shellcheck source=/dev/null
    source /etc/os-release
    DISTRO_ID="${ID:-unknown}"
}

_detect_distro_family() {
    local id id_like
    id="${ID,,}"
    id_like="${ID_LIKE:-}"
    id_like=" ${id_like,,} "

    case "$id" in
        arch | fedora | debian | ubuntu)
            DISTRO_FAMILY="$id"
            return 0
            ;;
    esac

    if [[ "$id_like" == *" ubuntu "* ]]; then
        DISTRO_FAMILY="ubuntu"
        return 0
    fi
    if [[ "$id_like" == *" debian "* ]]; then
        DISTRO_FAMILY="debian"
        return 0
    fi
    if [[ "$id_like" == *" fedora "* ]]; then
        DISTRO_FAMILY="fedora"
        return 0
    fi
    if [[ "$id_like" == *" arch "* ]]; then
        DISTRO_FAMILY="arch"
        return 0
    fi

    echo "detect: unsupported distro (ID=${ID:-unknown}, ID_LIKE=${ID_LIKE:-})" >&2
    return 1
}

_detect_pkg_manager() {
    case "$DISTRO_FAMILY" in
        arch) PKG_MANAGER="pacman" ;;
        debian | ubuntu) PKG_MANAGER="apt" ;;
        fedora) PKG_MANAGER="dnf" ;;
        *)
            echo "detect: no package manager mapping for family '${DISTRO_FAMILY}'" >&2
            return 1
            ;;
    esac
}

_detect_aur_helper() {
    AUR_HELPER=""
    [[ "$DISTRO_FAMILY" == "arch" ]] || return 0

    if command -v paru &>/dev/null; then
        AUR_HELPER="paru"
        return 0
    fi
    if command -v yay &>/dev/null; then
        AUR_HELPER="yay"
        return 0
    fi

    if [[ -t 0 ]]; then
        printf 'detect: neither paru nor yay found — enter AUR helper name (or press Enter to skip): ' >&2
        read -r AUR_HELPER
    else
        echo "detect: neither paru nor yay found (non-interactive — AUR_HELPER unset)" >&2
    fi
}

_detect_lspci_display_lines() {
    if ! command -v lspci &>/dev/null; then
        return 0
    fi
    lspci -nn 2>/dev/null | grep -iE 'vga|3d|display' || true
}

_detect_is_basic_display_line() {
    local line="$1"
    grep -qiE 'bochs|qxl|cirrus|vmware|virtualbox|virtio|hyper-v|device 1234:|device 1af4:|device 1b36:|device 15ad:' <<<"$line"
}

_detect_is_discrete_display_line() {
    local line="$1"

    if grep -qiE 'nvidia' <<<"$line"; then
        return 0
    fi
    if grep -qiE 'radeon rx|radeon pro w[0-9]' <<<"$line"; then
        return 0
    fi
    if grep -qiE 'intel.*arc.*(a[0-9]{3}|b[0-9]{3})' <<<"$line"; then
        return 0
    fi
    return 1
}

_detect_has_real_display() {
    local line
    local saw_real=false

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if _detect_is_basic_display_line "$line"; then
            continue
        fi
        saw_real=true
        break
    done < <(_detect_lspci_display_lines)

    [[ "$saw_real" == true ]]
}

_detect_has_discrete_gpu() {
    local line

    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        if _detect_is_basic_display_line "$line"; then
            continue
        fi
        if _detect_is_discrete_display_line "$line"; then
            return 0
        fi
    done < <(_detect_lspci_display_lines)

    return 1
}

_detect_cpu_model() {
    awk -F: '/model name/{print $2; exit}' /proc/cpuinfo 2>/dev/null | sed 's/^[ \t]*//'
}

_detect_cpu_matches_gaming_igpu() {
    local cpu_model="$1"
    local allowlist="${_data_dir}/gaming-igpus.json"

    [[ -n "$cpu_model" ]] || return 1
    [[ -f "$allowlist" ]] || return 1

    jq -e --arg cpu "$cpu_model" \
        '(.cpu_substrings | map(. as $s | ($cpu | contains($s))) | any)' \
        "$allowlist" >/dev/null 2>&1
}

_detect_get_gpu_renderer() {
    if command -v vulkaninfo &>/dev/null; then
        vulkaninfo --summary 2>/dev/null \
            | awk -F= '/deviceName/{sub(/^ /,"",$2); print $2; exit}'
        return 0
    fi
    if command -v glxinfo &>/dev/null; then
        glxinfo 2>/dev/null \
            | awk -F: '/OpenGL renderer string/{sub(/^ /,"",$2); print $2; exit}'
        return 0
    fi
    return 1
}

_detect_renderer_is_gaming_capable() {
    local renderer="$1"

    [[ -n "$renderer" ]] || return 1

    # Software / virtual renderers are never gaming-class.
    if grep -qiE 'llvmpipe|softpipe|lavapipe|virgl|virtio|vmware|svga3d|microsoft basic|software rasterizer' <<<"$renderer"; then
        return 1
    fi

    # Legacy Intel integrated (pre-Arc) — e.g. HD 2000 on Sandy Bridge i5.
    if grep -qiE 'intel.*(hd graphics|hd graphics [0-9]|uhd graphics 6[0-2][0-9])' <<<"$renderer"; then
        return 1
    fi

    # Positive gaming iGPU / discrete-integrated signals.
    if grep -qiE 'radeon 7[89][0-9]|radeon 8[0-9]{2}|intel.*arc|geforce|radeon rx' <<<"$renderer"; then
        return 0
    fi

    return 1
}

_detect_probe_confirms_gaming_igpu() {
    local renderer
    renderer="$(_detect_get_gpu_renderer 2>/dev/null || true)"
    _detect_renderer_is_gaming_capable "$renderer"
}

_detect_gpu_class() {
    if _detect_has_discrete_gpu; then
        GPU_CLASS="dgpu"
        return 0
    fi

    local cpu_model
    cpu_model="$(_detect_cpu_model)"

    if _detect_cpu_matches_gaming_igpu "$cpu_model"; then
        GPU_CLASS="igpu-gaming"
        return 0
    fi

    if _detect_probe_confirms_gaming_igpu; then
        GPU_CLASS="igpu-gaming"
        return 0
    fi

    if _detect_has_real_display; then
        GPU_CLASS="igpu-basic"
        return 0
    fi

    GPU_CLASS="none"
}

_detect_de_wm() {
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        DE_WM="${XDG_CURRENT_DESKTOP}"
        return 0
    fi

    DE_WM=""
}

_detect_has_de_wm() {
    [[ -n "$DE_WM" ]]
}

_detect_compositor() {
    COMPOSITOR="${XDG_SESSION_TYPE:-}"
}

_detect_init_system() {
    if [[ -d /run/systemd/system ]] && command -v systemctl &>/dev/null; then
        INIT_SYSTEM="systemd"
        return 0
    fi
    INIT_SYSTEM="other"
}

_detect_platform_class() {
    if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
        PLATFORM_CLASS="laptop"
        return 0
    fi

    if [[ "${OS_CONFIGS_FORCE_DESKTOP:-}" == "1" ]]; then
        PLATFORM_CLASS="desktop"
        return 0
    fi

    if ! _detect_has_de_wm && [[ "$GPU_CLASS" == "none" ]]; then
        PLATFORM_CLASS="server"
        return 0
    fi

    PLATFORM_CLASS="desktop"
}

_detect_print_summary() {
    printf 'DISTRO_FAMILY=%s\n' "$DISTRO_FAMILY"
    printf 'DISTRO_ID=%s\n' "$DISTRO_ID"
    printf 'PKG_MANAGER=%s\n' "$PKG_MANAGER"
    printf 'AUR_HELPER=%s\n' "$AUR_HELPER"
    printf 'PLATFORM_CLASS=%s\n' "$PLATFORM_CLASS"
    printf 'GPU_CLASS=%s\n' "$GPU_CLASS"
    printf 'DE_WM=%s\n' "$DE_WM"
    printf 'COMPOSITOR=%s\n' "$COMPOSITOR"
    printf 'INIT_SYSTEM=%s\n' "$INIT_SYSTEM"
}

os_configs_detect() {
    if ! command -v jq &>/dev/null; then
        echo "detect: jq is required but not installed" >&2
        return 1
    fi

    _detect_read_os_release
    _detect_distro_family
    _detect_pkg_manager
    _detect_aur_helper
    _detect_gpu_class
    _detect_de_wm
    _detect_compositor
    _detect_init_system
    _detect_platform_class

    export DISTRO_FAMILY DISTRO_ID PKG_MANAGER AUR_HELPER
    export PLATFORM_CLASS GPU_CLASS DE_WM COMPOSITOR INIT_SYSTEM
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    os_configs_detect
    _detect_print_summary
fi
