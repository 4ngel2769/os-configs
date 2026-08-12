#!/usr/bin/env bash
# Phase 3 checkpoint — non-interactive preset visibility checks.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
export TERM="${TERM:-xterm-256color}"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/detect.sh"
source "${ROOT}/lib/ui.sh"
source "${ROOT}/lib/flow.sh"

pass=0
fail=0

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local name="$3"
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "[ok] ${name}"
        pass=$((pass + 1))
    else
        echo "[FAIL] ${name} — expected '${needle}'"
        fail=$((fail + 1))
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local name="$3"
    if grep -Fq "$needle" <<<"$haystack"; then
        echo "[FAIL] ${name} — did not expect '${needle}'"
        fail=$((fail + 1))
    else
        echo "[ok] ${name}"
        pass=$((pass + 1))
    fi
}

echo "=== detection ==="
os_configs_detect
printf 'PLATFORM_CLASS=%s GPU_CLASS=%s DISTRO_FAMILY=%s\n' "$PLATFORM_CLASS" "$GPU_CLASS" "$DISTRO_FAMILY"

echo
echo "=== laptop preset list ==="
PLATFORM_CLASS=laptop
GPU_CLASS=igpu-gaming
export PLATFORM_CLASS GPU_CLASS
list="$(flow_list_preset_ids | paste -sd, -)"
echo "presets: ${list}"
assert_contains "$list" "laptop-gaming" "laptop + igpu-gaming shows Laptop Gaming"
assert_contains "$list" "laptop-minimal" "laptop shows Laptop Minimal"

echo
echo "=== laptop without gaming gpu ==="
GPU_CLASS=igpu-basic
export GPU_CLASS
list="$(flow_list_preset_ids | paste -sd, -)"
echo "presets: ${list}"
assert_not_contains "$list" "laptop-gaming" "laptop + igpu-basic hides Laptop Gaming"

echo
echo "=== platform override ==="
os_configs_detect
before="$PLATFORM_CLASS"
PLATFORM_CLASS=desktop
export PLATFORM_CLASS
list="$(flow_list_preset_ids | paste -sd, -)"
echo "overridden to desktop, presets: ${list}"
assert_contains "$list" "desktop-minimal" "override to desktop shows desktop presets"
assert_not_contains "$list" "laptop-gaming" "override to desktop hides laptop presets"

echo
echo "=== install.sh --auto --dry-run ==="
"${ROOT}/install.sh" --auto --dry-run </dev/null

echo
echo "=== results: ${pass} passed, ${fail} failed ==="
[[ "$fail" -eq 0 ]]
