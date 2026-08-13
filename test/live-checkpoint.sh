#!/usr/bin/env bash
# Live-path verification: dotfiles backup, post-login once-only, extras resolve.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TERM="${TERM:-xterm-256color}"

echo "=== phase 8 (dotfiles backup) ==="
bash "${ROOT}/test/phase8-checkpoint.sh"

echo
echo "=== phase 9 (post-login service) ==="
bash "${ROOT}/test/phase9-checkpoint.sh"

echo
echo "=== post-login runs once and self-removes ==="
source "${ROOT}/lib/deps.sh"
os_configs_ensure_deps
source "${ROOT}/lib/postlogin.sh"
postlogin_run_test "$ROOT"
printf 'n\n' | "${HOME}/.local/bin/os-configs-postlogin" >/dev/null 2>&1 || true
[[ ! -f "${HOME}/.local/bin/os-configs-postlogin" ]]
[[ ! -f "${HOME}/.config/systemd/user/os-configs-postlogin.service" ]]
echo "[ok] post-login script removed itself after run"

echo
echo "=== extras registry ==="
bash "${ROOT}/test/extras-checkpoint.sh"

echo
echo "=== live checkpoint passed ==="
