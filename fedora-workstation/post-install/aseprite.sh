#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Aseprite build script (placeholder)
# https://github.com/4ngel2769/os-configs
#
# This script downloads and runs a custom Aseprite build script.
# Set the ASEPRITE_SCRIPT_URL environment variable to the URL of
# your build script before running.
#
# Usage:
#   ASEPRITE_SCRIPT_URL=https://... bash post-install/aseprite.sh
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

ASEPRITE_SCRIPT_URL="${ASEPRITE_SCRIPT_URL:-}"

if [[ -z "$ASEPRITE_SCRIPT_URL" ]]; then
    msg_warn "ASEPRITE_SCRIPT_URL not set."
    msg_info "Set it as an env var or edit this file."
    msg_info "Example: ASEPRITE_SCRIPT_URL=https://... bash post-install/aseprite.sh"
    exit 1
fi

msg_info "Downloading and running Aseprite build script..."
msg_info "URL: $ASEPRITE_SCRIPT_URL"

bash <(curl -fsSL "$ASEPRITE_SCRIPT_URL") "$@"

msg_ok "Aseprite build complete"
