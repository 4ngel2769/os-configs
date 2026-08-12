#!/usr/bin/env bash
# Phase 8 checkpoint — user overlay, github dry-run, dotfiles backup preview.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$ROOT"
export TERM="${TERM:-xterm-256color}"

source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/detect.sh"
source "${ROOT}/lib/ui.sh"
source "${ROOT}/lib/registry.sh"
source "${ROOT}/lib/presets.sh"
source "${ROOT}/lib/dewm.sh"
source "${ROOT}/lib/custom.sh"
source "${ROOT}/lib/install.sh"
source "${ROOT}/lib/dotfiles.sh"

os_configs_detect

echo "=== user registry merge ==="
mkdir -p "${ROOT}/data/user"
cp "${ROOT}/data/user/registry.example.json" "${ROOT}/data/user/registry.test.json"
export USER_REGISTRY_FILE="${ROOT}/data/user/registry.test.json"
registry_has_entry eza || { echo "eza not found"; exit 1; }
lookup="$(registry_lookup eza)"
echo "$lookup" | grep -q 'manager=github'
echo "$lookup" | grep -q 'repo=eza-community/eza'
echo "[ok] user registry overlay resolves github entries"

echo
echo "=== categories merge ==="
cp "${ROOT}/data/user/categories.example.json" "${ROOT}/data/user/categories.test.json"
export USER_CATEGORIES_FILE="${ROOT}/data/user/categories.test.json"
_custom_merged_categories=""
merged="$(custom_merged_categories_path)"
jq -e '.community.apps | index("eza")' "$merged" >/dev/null
jq -e '.utilities.apps | index("my-editor")' "$merged" >/dev/null
echo "[ok] user categories merged into custom menu data"

echo
echo "=== github dry-run install ==="
export DISTRO_FAMILY=ubuntu
install_app eza true | tee /tmp/phase8-eza.log
grep -q 'github:eza-community/eza' /tmp/phase8-eza.log
grep -q 'would fetch latest release' /tmp/phase8-eza.log
echo "[ok] github release dry-run"

echo
echo "=== dotfiles backup (scratch HOME) ==="
REAL_HOME="${HOME}"
TEST_HOME="$(mktemp -d /tmp/os-configs-phase8-home.XXXXXX)"
export HOME="$TEST_HOME"
export SELECTED_DOTFILES_PKG=""
export SELECTED_DE_WM="gnome"

echo "preexisting git config" >"${TEST_HOME}/.gitconfig"

dotfiles_backup
[[ -n "$DOTFILES_BACKUP_PATH" && -f "${DOTFILES_BACKUP_PATH}/.gitconfig" ]]
grep -q 'preexisting git config' "${DOTFILES_BACKUP_PATH}/.gitconfig"
echo "[ok] dotfiles backup captured existing ~/.gitconfig"
export HOME="$REAL_HOME"

echo
echo "=== full dry-run with dotfiles preview ==="
export OS_CONFIGS_DRY_RUN=true
"${ROOT}/install.sh" --auto --dry-run </dev/null | tee /tmp/phase8-full.log
grep -q 'Dotfiles' /tmp/phase8-full.log
grep -q 'shared:git' /tmp/phase8-full.log
grep -q 'dry-run.*stow' /tmp/phase8-full.log
echo "[ok] install dry-run includes dotfiles preview"

rm -rf "$TEST_HOME" "${ROOT}/data/user/registry.test.json" "${ROOT}/data/user/categories.test.json"

echo
echo "=== Phase 8 checkpoint passed ==="
