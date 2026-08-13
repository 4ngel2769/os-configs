#!/usr/bin/env bash
set -euo pipefail

_deps_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${_deps_lib_dir}/.." && pwd)}"
OS_CONFIGS_CACHE="${OS_CONFIGS_CACHE:-${XDG_CACHE_HOME:-${HOME}/.cache}/os-configs}"
OS_CONFIGS_BIN="${OS_CONFIGS_BIN:-${OS_CONFIGS_CACHE}/bin}"

JQ_VERSION="${OS_CONFIGS_JQ_VERSION:-1.7.1}"
GUM_VERSION="${OS_CONFIGS_GUM_VERSION:-0.14.5}"
PICKER_VERSION="${OS_CONFIGS_PICKER_VERSION:-7}"

_deps_msg() { printf '[deps] %s\n' "$*" >&2; }

_deps_ensure_bin_dir() {
    mkdir -p "$OS_CONFIGS_BIN"
}

_deps_arch() {
    local machine
    machine="$(uname -m)"
    case "$machine" in
        x86_64 | amd64) echo "amd64" ;;
        aarch64 | arm64) echo "arm64" ;;
        *)
            echo "deps: unsupported architecture: ${machine}" >&2
            return 1
            ;;
    esac
}

_deps_download() {
    local url="$1"
    local dest="$2"

    mkdir -p "$(dirname "$dest")"

    if command -v curl &>/dev/null; then
        curl -fsSL -o "$dest" "$url"
        return 0
    fi
    if command -v wget &>/dev/null; then
        wget -qO "$dest" "$url"
        return 0
    fi

    echo "deps: curl or wget required to fetch tools" >&2
    return 1
}

_deps_install_jq() {
    local arch dest url
    arch="$(_deps_arch)"
    dest="${OS_CONFIGS_BIN}/jq"
    url="https://github.com/jqlang/jq/releases/download/jq-${JQ_VERSION}/jq-linux-${arch}"

    if [[ -x "$dest" ]]; then
        return 0
    fi

    _deps_ensure_bin_dir

    _deps_msg "fetching jq ${JQ_VERSION} (${arch})..."
    _deps_download "$url" "$dest"
    chmod +x "$dest"
    _deps_msg "jq installed to ${dest}"
}

_deps_install_gum() {
    local arch dest tarball tmpdir url folder
    arch="$(_deps_arch)"
    dest="${OS_CONFIGS_BIN}/gum"

    if [[ -x "$dest" ]]; then
        return 0
    fi

    _deps_ensure_bin_dir

    case "$arch" in
        amd64)
            url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_x86_64.tar.gz"
            folder="gum_${GUM_VERSION}_Linux_x86_64"
            ;;
        arm64)
            url="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}/gum_${GUM_VERSION}_Linux_arm64.tar.gz"
            folder="gum_${GUM_VERSION}_Linux_arm64"
            ;;
    esac

    tmpdir="$(mktemp -d)"
    tarball="${tmpdir}/gum.tgz"

    _deps_msg "fetching gum ${GUM_VERSION} (${arch})..."
    _deps_download "$url" "$tarball"
    tar -xzf "$tarball" -C "$tmpdir"
    install -m 0755 "${tmpdir}/${folder}/gum" "$dest"
    rm -rf "$tmpdir"
    _deps_msg "gum installed to ${dest}"
}

_deps_prepend_path() {
    if [[ -d "$OS_CONFIGS_BIN" ]]; then
        case ":${PATH}:" in
            *":${OS_CONFIGS_BIN}:"*) ;;
            *) export PATH="${OS_CONFIGS_BIN}:${PATH}" ;;
        esac
    fi
}

os_configs_ensure_jq() {
    if command -v jq &>/dev/null; then
        return 0
    fi
    _deps_install_jq
    _deps_prepend_path
}

os_configs_ensure_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi
    _deps_install_gum
    _deps_prepend_path
}

os_configs_ensure_deps() {
    os_configs_ensure_jq
    os_configs_ensure_gum
    os_configs_ensure_picker
    _deps_prepend_path
}

_deps_picker_bundled() {
    echo "${REPO_ROOT}/tools/picker/bin/linux-${1}/os-configs-picker"
}

_deps_picker_cached() {
    local dest="$1"
    local stamp="${OS_CONFIGS_BIN}/.os-configs-picker.version"

    [[ -x "$dest" && -f "$stamp" && "$(cat "$stamp")" == "$PICKER_VERSION" ]] || return 1
    _deps_picker_runnable "$dest"
}

# Bundled/cached picker must be a Linux ELF for this host arch (not a Windows PE accidentally committed).
_deps_picker_valid_elf() {
    local bin="$1"

    [[ -f "$bin" ]] || return 1

    if command -v file &>/dev/null; then
        file -b "$bin" 2>/dev/null | grep -qiE 'ELF.*(x86-64|aarch64|ARM aarch64|Intel 80386)' && return 0
        return 1
    fi

    local magic
    magic="$(head -c 4 "$bin" 2>/dev/null || true)"
    [[ "$magic" == $'\x7fELF' ]]
}

_deps_picker_runnable() {
    local bin="$1"

    [[ -f "$bin" && -x "$bin" ]] || return 1
    _deps_picker_valid_elf "$bin"
}

_deps_picker_try_source_build() {
    command -v go &>/dev/null || [[ -x "${HOME}/go/bin/go" ]]
}

_deps_install_picker_from_source() {
    local dest="$1"
    local src="${REPO_ROOT}/tools/picker"
    local arch goos goarch

    if ! command -v go &>/dev/null; then
        if [[ -x "${HOME}/go/bin/go" ]]; then
            export PATH="${HOME}/go/bin:${PATH}"
        else
            return 1
        fi
    fi

    [[ -f "${src}/main.go" ]] || return 1

    arch="$(_deps_arch)"
    goos="linux"
    goarch="$arch"

    _deps_msg "building os-configs-picker from source (${goos}/${goarch})..."
    (
        cd "$src"
        go mod tidy >/dev/null 2>&1
        GOOS="$goos" GOARCH="$goarch" go build -trimpath -ldflags "-s -w" -o "$dest" .
    )
    chmod +x "$dest"
    if ! _deps_picker_runnable "$dest"; then
        echo "deps: picker build did not produce a runnable Linux ELF binary" >&2
        rm -f "$dest"
        return 1
    fi
    printf '%s\n' "$PICKER_VERSION" >"${OS_CONFIGS_BIN}/.os-configs-picker.version"
    _deps_msg "picker built to ${dest}"
}

_deps_install_picker() {
    local dest arch bundled
    dest="${OS_CONFIGS_BIN}/os-configs-picker"
    arch="$(_deps_arch)"
    bundled="$(_deps_picker_bundled "$arch")"

    if _deps_picker_cached "$dest"; then
        return 0
    fi

    _deps_ensure_bin_dir

    if [[ -f "$bundled" ]] && _deps_picker_valid_elf "$bundled"; then
        _deps_msg "installing bundled os-configs-picker (${arch})..."
        cp "$bundled" "$dest"
        chmod +x "$dest"
        printf '%s\n' "$PICKER_VERSION" >"${OS_CONFIGS_BIN}/.os-configs-picker.version"
        _deps_msg "picker installed to ${dest}"
        return 0
    fi

    if [[ -f "$bundled" ]] && ! _deps_picker_valid_elf "$bundled"; then
        echo "deps: bundled picker is not a valid Linux ELF for ${arch}: ${bundled}" >&2
        echo "deps: rebuild with: (cd tools/picker && ./build.sh)" >&2
    fi

    if _deps_picker_try_source_build; then
        _deps_msg "building os-configs-picker from source (bundled copy unusable)..."
        _deps_install_picker_from_source "$dest"
        return $?
    fi

    if [[ "${OS_CONFIGS_PICKER_BUILD:-}" == "1" ]]; then
        _deps_install_picker_from_source "$dest"
        return $?
    fi

    echo "deps: os-configs-picker unavailable — gum fallbacks will be used" >&2
    echo "deps: install Go and re-run, or set OS_CONFIGS_PICKER_BUILD=1" >&2
    return 0
}

os_configs_ensure_picker() {
    _deps_install_picker
}

_deps_has_jq() {
    command -v jq &>/dev/null || [[ -x "${OS_CONFIGS_BIN}/jq" ]]
}

_deps_has_gum() {
    command -v gum &>/dev/null || [[ -x "${OS_CONFIGS_BIN}/gum" ]]
}

_deps_has_picker() {
    _deps_picker_cached "${OS_CONFIGS_BIN}/os-configs-picker"
}

_deps_has_fetcher() {
    command -v curl &>/dev/null || command -v wget &>/dev/null
}

_deps_system_pkg_name() {
    local logical="$1"
    printf '%s' "$logical"
}

_deps_install_system_pkg() {
    local pkg="$1"

    case "${DISTRO_FAMILY:-}" in
        arch)
            sudo pacman -S --needed --noconfirm "$pkg"
            ;;
        debian | ubuntu)
            sudo apt-get update -qq
            sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
            ;;
        fedora)
            sudo dnf install -y "$pkg"
            ;;
        *)
            echo "deps: cannot install system package on unknown family: ${DISTRO_FAMILY:-?}" >&2
            return 1
            ;;
    esac
}

# Populates _out with rows: kind|id|label|note
# kind = tool | system
# tools_only=true skips system packages (used after dry-run bootstrap).
deps_collect_missing() {
    local -n _out=$1
    local skip_dotfiles="${2:-false}"
    local tools_only="${3:-false}"
    local arch bundled

    _out=()

    if [[ "$tools_only" != "true" ]] && ! _deps_has_fetcher; then
        _out+=("system|curl|curl|download installer tools")
    fi

    if ! _deps_has_jq; then
        _out+=("tool|jq|jq ${JQ_VERSION}|${OS_CONFIGS_BIN}/jq")
    fi

    if ! _deps_has_gum; then
        _out+=("tool|gum|gum ${GUM_VERSION}|${OS_CONFIGS_BIN}/gum")
    fi

    if ! _deps_has_picker; then
        arch="$(_deps_arch)"
        bundled="$(_deps_picker_bundled "$arch")"
        if [[ -f "$bundled" ]] || _deps_picker_try_source_build || [[ "${OS_CONFIGS_PICKER_BUILD:-}" == "1" ]]; then
            _out+=("tool|picker|os-configs-picker|${OS_CONFIGS_BIN}/os-configs-picker")
        else
            _out+=("tool|picker|os-configs-picker (optional)|gum fallback only")
        fi
    fi

    if [[ "$tools_only" != "true" && "$skip_dotfiles" != "true" ]] && ! command -v stow &>/dev/null; then
        _out+=("system|stow|stow|deploy dotfiles with GNU Stow")
    fi
}

deps_format_panel_body() {
    local -a items=("$@")
    local item kind _id label note
    local tool_lines="" sys_lines="" body="" mgr

    mgr="${PKG_MANAGER:-system}"

    for item in "${items[@]}"; do
        IFS='|' read -r kind _id label note <<< "$item"
        case "$kind" in
            tool)
                tool_lines+="${tool_lines:+$'\n'}  • ${label}"
                tool_lines+=$'\n'"    ${note}"
                ;;
            system)
                sys_lines+="${sys_lines:+$'\n'}  • ${label}"
                sys_lines+=$'\n'"    ${note}"
                ;;
        esac
    done

    if [[ -n "$tool_lines" ]]; then
        body="Installer tools (user cache, no sudo):"$'\n'"${tool_lines}"
    fi
    if [[ -n "$sys_lines" ]]; then
        body+="${body:+$'\n\n'}System packages (sudo · ${mgr}):"$'\n'"${sys_lines}"
    fi
    printf '%s' "$body"
}

deps_show_install_panel() {
    local -a missing=("$@")
    local body extra=""

    body="$(deps_format_panel_body "${missing[@]}")"

    if [[ "${OS_CONFIGS_DRY_RUN:-false}" == "true" ]]; then
        extra=$'\n\n'"Dry-run: installer tools will still be fetched to run the TUI. System packages are listed but not installed until a real run."
    fi

    if command -v gum &>/dev/null; then
        gum style --bold --align center --width "$(ui_term_width)" --margin "1 0 0 0" "Dependencies"
    else
        printf '\nDependencies\n\n'
    fi
    ui_panel "The following will be installed" "${body}${extra}"
}

deps_install_item() {
    local row="$1"
    local defer_system="${2:-false}"
    local kind _id label note

    IFS='|' read -r kind _id label note <<< "$row"

    if [[ "$kind" == "system" && "$defer_system" == "true" && "$_id" != "curl" ]]; then
        _deps_msg "skipping system package ${_id} (dry-run)"
        return 0
    fi

    case "${kind}:${_id}" in
        tool:jq)
            _deps_install_jq
            ;;
        tool:gum)
            _deps_install_gum
            ;;
        tool:picker)
            if [[ "$note" == *"not available"* ]]; then
                echo "deps: ${note}" >&2
                return 0
            fi
            _deps_install_picker || true
            ;;
        system:curl)
            _deps_install_system_pkg "curl"
            ;;
        system:stow)
            _deps_install_system_pkg "stow"
            ;;
        system:*)
            _deps_install_system_pkg "$_id"
            ;;
        *)
            echo "deps: unknown dependency row: ${row}" >&2
            return 1
            ;;
    esac
}

deps_install_missing() {
    local defer_system="${1:-false}"
    shift
    local -a missing=("$@")
    local row kind _id

    for row in "${missing[@]}"; do
        IFS='|' read -r kind _id _ _ <<< "$row"
        [[ "$kind" == "system" && "$_id" == "curl" ]] || continue
        deps_install_item "$row" "$defer_system"
    done
    for row in "${missing[@]}"; do
        IFS='|' read -r kind _id _ _ <<< "$row"
        [[ "$kind" == "tool" ]] || continue
        deps_install_item "$row" "$defer_system"
    done
    for row in "${missing[@]}"; do
        IFS='|' read -r kind _id _ _ <<< "$row"
        [[ "$kind" == "system" && "$_id" != "curl" ]] || continue
        deps_install_item "$row" "$defer_system"
    done

    _deps_prepend_path
}

deps_confirm_install_prompt() {
    if command -v gum &>/dev/null; then
        gum confirm "Install these dependencies now?"
        return $?
    fi
    ui_confirm_plain "Install these dependencies now?"
}

# Audit, prompt, and install missing deps before the main installer flow.
os_configs_prepare_deps() {
    local auto="${1:-false}"
    local skip_dotfiles="${2:-false}"
    local dry_run="${3:-false}"
    local -a missing=()

    if [[ -z "${DISTRO_FAMILY:-}" ]]; then
        echo "deps: DISTRO_FAMILY not set — run os_configs_detect_minimal first" >&2
        return 1
    fi

    deps_collect_missing missing "$skip_dotfiles"

    if [[ ${#missing[@]} -eq 0 ]]; then
        _deps_prepend_path
        return 0
    fi

    if [[ "$auto" == "true" ]]; then
        _deps_msg "installing ${#missing[@]} missing dependencies (--auto)..."
        deps_install_missing "$([[ "$dry_run" == "true" ]] && echo true || echo false)" "${missing[@]}"
        return 0
    fi

    deps_show_install_panel "${missing[@]}"

    if ! deps_confirm_install_prompt; then
        echo "deps: dependency installation cancelled" >&2
        return 1
    fi

    deps_install_missing "$([[ "$dry_run" == "true" ]] && echo true || echo false)" "${missing[@]}"

    if [[ "$dry_run" == "true" ]]; then
        deps_collect_missing missing "$skip_dotfiles" true
    else
        deps_collect_missing missing "$skip_dotfiles" false
    fi
    if [[ ${#missing[@]} -gt 0 ]]; then
        local still=""
        for row in "${missing[@]}"; do
            IFS='|' read -r _kind _id label _note <<< "$row"
            [[ "$_id" == "picker" ]] && continue
            still+="${still:+, }${label}"
        done
        if [[ -n "$still" ]]; then
            echo "deps: still missing after install: ${still}" >&2
            return 1
        fi
    fi
}

os_configs_ensure_deps() {
    os_configs_prepare_deps true false false
}
