#!/usr/bin/env bash
# Phase 5 checkpoint — custom selection JSON shape + preset DE/WM defaults.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
export TERM="${TERM:-xterm-256color}"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/detect.sh"
source "${ROOT}/lib/ui.sh"
source "${ROOT}/lib/presets.sh"
source "${ROOT}/lib/dewm.sh"
source "${ROOT}/lib/custom.sh"

os_configs_detect
export PLATFORM_CLASS=laptop
export GPU_CLASS=igpu-gaming

echo "=== custom selection (simulated) ==="
custom_apply_test_selection "browsers:brave+firefox,utilities:fzf+btop" "/tmp/os-configs-custom-plan.json"
cat "/tmp/os-configs-custom-plan.json"
jq -e '.categories.browsers | index("brave")' "/tmp/os-configs-custom-plan.json" >/dev/null
jq -e '.categories.utilities | index("fzf")' "/tmp/os-configs-custom-plan.json" >/dev/null
jq -e '.laptop_tuning == true' "/tmp/os-configs-custom-plan.json" >/dev/null
echo "[ok] custom plan JSON shape"

echo
echo "=== preset DE/WM (ask disabled) ==="
INSTALL_MODE=preset
SELECTED_PRESET_FILE="${ROOT}/data/presets/laptop-gaming.json"
dewm_resolve true "$SELECTED_PRESET_FILE"
echo "DE/WM=${SELECTED_DE_WM} DM=${SELECTED_DM} dotfiles=${SELECTED_DOTFILES_PKG}"
[[ "$SELECTED_DE_WM" == "gnome" && "$SELECTED_DM" == "gdm" ]]
echo "[ok] preset uses predetermined gnome/gdm"

echo
echo "=== ask_de_wm flag ==="
jq -e '.ask_de_wm == false' "${ROOT}/data/config.json" >/dev/null
echo "[ok] ask_de_wm disabled in data/config.json (enable via OS_CONFIGS_ASK_DE_WM=1 or --ask-de-wm)"

echo
echo "=== install.sh preset path (--auto --dry-run) ==="
"${ROOT}/install.sh" --auto --dry-run </dev/null
