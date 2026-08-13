#!/usr/bin/env bash
# Phase 9 checkpoint — post-login service install + self-remove + optional brew skip.
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
source "${ROOT}/lib/install.sh"
source "${ROOT}/lib/postlogin.sh"

os_configs_detect
export PLATFORM_CLASS=laptop

echo "=== post-login service files ==="
postlogin_run_test "$ROOT"
test -x "${HOME}/.local/bin/os-configs-postlogin"
test -f "${HOME}/.config/systemd/user/os-configs-postlogin.service"
echo "[ok] post-login script and unit written"

echo
echo "=== post-login self-remove ==="
postlogin_self_remove
[[ ! -f "${HOME}/.local/bin/os-configs-postlogin" ]]
[[ ! -f "${HOME}/.config/systemd/user/os-configs-postlogin.service" ]]
echo "[ok] post-login service removed"

echo
echo "=== optional brew skip ==="
export USER_REGISTRY_FILE="${ROOT}/data/user/registry.example.json"
export DISTRO_FAMILY=ubuntu
log_reset
install_app ripgrep-brew true | tee /tmp/phase9-brew.log || true
grep -q 'skipped' /tmp/phase9-brew.log
echo "[ok] optional brew entry skips when brew missing"

echo
echo "=== dry-run finish includes post-login ==="
export OS_CONFIGS_DRY_RUN=true
"${ROOT}/install.sh" --auto --dry-run </dev/null | tee /tmp/phase9-full.log
grep -q 'post-login' /tmp/phase9-full.log
echo "[ok] dry-run mentions post-login service"

echo
echo "=== Phase 9 checkpoint passed ==="
