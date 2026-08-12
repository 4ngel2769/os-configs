#!/usr/bin/env bash
set -euo pipefail

ROOT="${DETECT_ROOT:-/tmp/os-configs-phase1}"
HOST="$(hostname)"

echo "========== ${HOST} =========="
echo "=== cpu ==="
grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 || head -5 /proc/cpuinfo
echo "=== lspci display ==="
if command -v lspci &>/dev/null; then
    lspci | grep -iE 'vga|3d|display' || echo '(no display devices)'
else
    echo '(lspci not installed)'
fi
echo "=== battery ==="
if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
    ls /sys/class/power_supply/BAT* | head -1
else
    echo none
fi
echo "=== detect.sh ==="
sed -i 's/\r$//' "${ROOT}/lib/detect.sh" 2>/dev/null || true
if ! command -v jq &>/dev/null && [[ -x /tmp/jq ]]; then
    export PATH="/tmp:${PATH}"
fi
bash "${ROOT}/lib/detect.sh"
