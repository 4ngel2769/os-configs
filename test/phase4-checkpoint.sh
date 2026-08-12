#!/usr/bin/env bash
# Phase 4 checkpoint — validate preset JSON + registry coverage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/presets.sh"

echo "=== preset files ==="
for f in "${ROOT}"/data/presets/*.json; do
    jq empty "$f"
    printf '  %s\n' "$(preset_summary_line "$f")"
done

echo
echo "=== registry coverage (all families) ==="
preset_validate_all
echo "all preset apps resolve in registry for arch/debian/ubuntu/fedora"

echo
echo "=== known gaps (by design until Phase 7) ==="
echo "  discord — arch only (flatpak deferred)"
echo "  signal  — no fedora entry (flatpak deferred)"
