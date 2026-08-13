#!/usr/bin/env bash
# Catalog + platform filter checkpoint
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/detect.sh"
source "${ROOT}/lib/registry.sh"
source "${ROOT}/lib/picker.sh"

os_configs_detect

echo "=== catalog import ==="
count="$(jq 'keys | length' "${ROOT}/data/catalog/registry-arco.json")"
[[ "$count" -gt 500 ]]
echo "[ok] registry-arco has ${count} entries"

echo
echo "=== platform filter (server hides browsers) ==="
export PLATFORM_CLASS=server
export DISTRO_FAMILY=ubuntu
registry_app_visible firefox && { echo "firefox visible on server"; exit 1; }
registry_app_visible git || { echo "git missing on server"; exit 1; }
echo "[ok] server hides GUI browsers, shows git"

echo
echo "=== platform filter (laptop shows browsers) ==="
export PLATFORM_CLASS=laptop
registry_app_visible firefox || { echo "firefox missing on laptop"; exit 1; }
echo "[ok] laptop shows firefox"

echo
echo "=== picker catalog build ==="
catalog="$(mktemp /tmp/os-configs-catalog-test.XXXXXX)"
picker_build_catalog "$catalog"
cats="$(jq '.categories | length' "$catalog")"
apps="$(jq '[.categories[].apps | length] | add' "$catalog")"
[[ "$cats" -ge 10 ]]
[[ "$apps" -ge 50 ]]
echo "[ok] catalog: ${cats} categories, ${apps} visible apps"
rm -f "$catalog"

echo
echo "=== category consolidation ==="
merged="$(categories_merged_json)"
echo "$merged" | jq -e '.browsers.apps | index("chrome")' >/dev/null
echo "$merged" | jq -e '.communication.apps | index("discord")' >/dev/null
if echo "$merged" | jq -e '.["browsers-extra"]' >/dev/null 2>&1; then
    echo "browsers-extra category should be merged into browsers"
    exit 1
fi
echo "[ok] extras merged into native categories"

echo
echo "=== catalog checkpoint passed ==="
