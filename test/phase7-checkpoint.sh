#!/usr/bin/env bash
# Phase 7 checkpoint — dry-run preset + custom paths with resolved packages.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
export TERM="${TERM:-xterm-256color}"

echo "=== preset path (--auto --dry-run) ==="
"${ROOT}/install.sh" --auto --dry-run </dev/null | tee /tmp/phase7-preset.log
grep -q 'fzf → apt:fzf' /tmp/phase7-preset.log
grep -q '\[dry-run\] would run:' /tmp/phase7-preset.log
echo "[ok] preset dry-run shows resolved packages"

echo
echo "=== custom path (simulated plan --auto --dry-run) ==="
# Drive custom path non-interactively by pre-seeding env is not wired;
# run confirm + install directly for custom plan file.
source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/detect.sh"
source "${ROOT}/lib/ui.sh"
source "${ROOT}/lib/registry.sh"
source "${ROOT}/lib/presets.sh"
source "${ROOT}/lib/dewm.sh"
source "${ROOT}/lib/custom.sh"
source "${ROOT}/lib/confirm.sh"

os_configs_detect
export PLATFORM_CLASS=laptop
export GPU_CLASS=igpu-gaming
export OS_CONFIGS_DRY_RUN=true
INSTALL_MODE=custom
custom_apply_test_selection "browsers:brave,developer:git" "/tmp/os-configs-custom-plan.json"
SELECTED_CUSTOM_FILE="/tmp/os-configs-custom-plan.json"
dewm_resolve true ""

confirm_run true true | tee /tmp/phase7-custom.log
grep -q 'brave → apt:brave-browser' /tmp/phase7-custom.log
grep -q 'git → apt:git' /tmp/phase7-custom.log
echo "[ok] custom dry-run shows resolved packages"

echo
echo "=== Phase 7 checkpoint passed ==="
