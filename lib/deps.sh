#!/usr/bin/env bash
set -euo pipefail

_deps_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "${_deps_lib_dir}/.." && pwd)}"
OS_CONFIGS_CACHE="${OS_CONFIGS_CACHE:-${XDG_CACHE_HOME:-${HOME}/.cache}/os-configs}"
OS_CONFIGS_BIN="${OS_CONFIGS_BIN:-${OS_CONFIGS_CACHE}/bin}"

JQ_VERSION="${OS_CONFIGS_JQ_VERSION:-1.7.1}"
GUM_VERSION="${OS_CONFIGS_GUM_VERSION:-0.14.5}"

_deps_msg() { printf '[deps] %s\n' "$*" >&2; }

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

_deps_install_picker() {
    local dest src
    dest="${OS_CONFIGS_BIN}/os-configs-picker"
    src="${REPO_ROOT}/tools/picker"

    if [[ -x "$dest" ]]; then
        return 0
    fi

    if ! command -v go &>/dev/null; then
        if [[ -x "${HOME}/go/bin/go" ]]; then
            export PATH="${HOME}/go/bin:${PATH}"
        else
            _deps_msg "go not installed — software picker will fall back to gum choose"
            return 0
        fi
    fi

    if [[ ! -f "${src}/main.go" ]]; then
        _deps_msg "picker source missing at ${src}"
        return 0
    fi

    _deps_msg "building os-configs-picker..."
    (cd "$src" && go mod tidy >/dev/null 2>&1 && go build -o "$dest" .)
    chmod +x "$dest"
    _deps_msg "picker installed to ${dest}"
}

os_configs_ensure_picker() {
    _deps_install_picker
}
