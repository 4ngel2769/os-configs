#!/usr/bin/env bash
set -euo pipefail

# Offline checks for the parts that must never silently rot.
# Usage: ./test/smoke.sh

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export REPO_ROOT="$ROOT"

fail=0
ok()  { printf '[ok]   %s\n' "$*"; }
bad() { printf '[FAIL] %s\n' "$*" >&2; fail=$((fail + 1)); }

while IFS= read -r f; do
    if bash -n "$f" 2>/dev/null; then
        ok "syntax ${f#${ROOT}/}"
    else
        bad "syntax ${f#${ROOT}/}"
    fi
done < <(find "$ROOT" -type f -name '*.sh' -not -path '*/.git/*' | sort)

while IFS= read -r f; do
    if jq empty "$f" 2>/dev/null; then
        ok "json ${f#${ROOT}/}"
    else
        bad "invalid JSON ${f#${ROOT}/}"
    fi
done < <(find "$ROOT/data" -type f -name '*.json' | sort)

# shellcheck source=/dev/null
source "${ROOT}/lib/deps.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/registry.sh"
# shellcheck source=/dev/null
source "${ROOT}/lib/presets.sh"

for family in arch debian ubuntu fedora; do
    if preset_validate_family "$family" 2>/dev/null; then
        ok "registry ${family}"
    else
        bad "registry ${family}"
    fi
done

while IFS= read -r pid; do
    [[ -f "${ROOT}/data/presets/${pid}.json" ]] || bad "preset file missing: ${pid}"
done < <(jq -r '.presets[].id' "${ROOT}/data/presets-menu.json")

for entrypoint in bootstrap.sh setup.sh; do
    if bash "${ROOT}/${entrypoint}" --help 2>/dev/null | grep -q 'os-configs bootstrap'; then
        ok "${entrypoint} --help"
    else
        bad "${entrypoint} --help"
    fi
done

if bash "${ROOT}/lib/detect.sh" >/dev/null 2>&1; then
    ok "detection"
else
    bad "detection"
fi

for bin in "${ROOT}"/tools/picker/bin/linux-*/os-configs-picker; do
    [[ -f "$bin" ]] || continue
    if file -b "$bin" 2>/dev/null | grep -qi ELF; then
        ok "picker ELF $(basename "$(dirname "$bin")")"
    else
        bad "picker is not an ELF: ${bin}"
    fi
done

if [[ "$fail" -gt 0 ]]; then
    printf '%s check(s) failed\n' "$fail" >&2
    exit 1
fi
printf 'smoke passed\n'
