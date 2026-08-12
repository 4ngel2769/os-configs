#!/usr/bin/env bash
set -euo pipefail
ROOT="${1:-/tmp/os-configs-phase2}"
source "${ROOT}/lib/ui.sh"
export DISTRO_ID=ubuntu
export DISTRO_FAMILY=ubuntu
echo "=== badge ==="
ui_distro_badge
echo
echo "=== preset rows ==="
ui_format_preset_row "Server Minimal"
ui_format_preset_row "Server Clean"
ui_format_preset_row "Server Everything"
echo
echo "=== divider ==="
ui_style_divider
