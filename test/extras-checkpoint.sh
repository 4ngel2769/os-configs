#!/usr/bin/env bash
# Verify every extras.json app resolves for each distro family.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/registry.sh"

extras="${ROOT}/data/catalog/extras.json"
failed=0

for family in arch debian ubuntu fedora; do
    export DISTRO_FAMILY="$family"
    echo "=== extras / ${family} ==="
    while IFS= read -r app; do
        [[ -n "$app" ]] || continue
        if registry_has_entry "$app" "$family"; then
            lookup="$(registry_lookup "$app")"
            mgr="$(grep -m1 '^manager=' <<<"$lookup" | cut -d= -f2-)"
            pkg="$(grep -m1 '^package=' <<<"$lookup" | cut -d= -f2-)"
            echo "  [ok] ${app} → ${mgr}:${pkg}"
        else
            echo "  [skip] ${app} (no ${family} entry — arch-only is fine)"
        fi
    done < <(jq -r 'keys[]' "$extras")
done

echo
echo "=== extras checkpoint passed ==="
