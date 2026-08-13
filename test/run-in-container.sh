#!/usr/bin/env bash
# Phase 10 — validate presets per family; optional docker dry-run.
# Usage: ./test/run-in-container.sh <arch|debian|ubuntu|fedora|all>
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
TARGET="${1:?usage: $0 arch|debian|ubuntu|fedora|all}"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/registry.sh"
source "${ROOT}/lib/presets.sh"

_image() {
    case "$1" in
        arch) echo "archlinux/archlinux:latest" ;;
        debian) echo "debian:bookworm" ;;
        ubuntu) echo "ubuntu:22.04" ;;
        fedora) echo "fedora:40" ;;
        *) echo "unknown family: $1" >&2; return 1 ;;
    esac
}

_validate() {
    export DISTRO_FAMILY="$1"
    echo "=== $1: registry ==="
    preset_validate_family "$1"
    echo "[ok] $1 presets resolve in registry"
}

_dry_run() {
    local family="$1"
    local platform="$2"
    echo "=== $family: dry-run ($platform) ==="
    docker run --rm \
        -v "${ROOT}:/repo:ro" \
        -w /repo \
        -e TERM=dumb \
        -e "OS_CONFIGS_FORCE_PLATFORM=${platform}" \
        "$(_image "$family")" \
        bash -c 'bash install.sh --auto --dry-run --skip-reboot </dev/null'
    echo "[ok] $family/$platform dry-run"
}

_run() {
    _validate "$1"
    if command -v docker &>/dev/null; then
        _dry_run "$1" server
        _dry_run "$1" laptop
    else
        echo "[skip] no docker — registry only"
    fi
}

case "$TARGET" in
    all)
        for f in arch debian ubuntu fedora; do
            _run "$f"
        done
        ;;
    arch | debian | ubuntu | fedora)
        _run "$TARGET"
        ;;
    *)
        echo "unknown target: $TARGET" >&2
        exit 1
        ;;
esac

echo "=== Phase 10 passed ==="
