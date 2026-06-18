#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — SpotX: Spotify ad-blocker patcher
# https://github.com/SpotX-Official/SpotX-Bash
#
# Patches the Spotify Flatpak to block ads.
# Must run AFTER Spotify is installed via Flatpak.
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

# Parse --auto flag
FORCE_FLAG=""
for arg in "$@"; do
    case "$arg" in
        --auto) FORCE_FLAG="-f" ;;
    esac
done

# Confirm Spotify is installed (Flatpak)
if flatpak list --app 2>/dev/null | grep -q "com.spotify.Client"; then
    msg_ok "Spotify Flatpak found"
    msg_info "Running SpotX-Bash patcher..."
    bash <(curl -sSL https://spotx-official.github.io/run.sh) $FORCE_FLAG || {
        msg_warn "SpotX patcher failed — run manually later:"
        msg_info "  bash <(curl -sSL https://spotx-official.github.io/run.sh) -f"
    }
    msg_ok "SpotX applied"
else
    msg_warn "Spotify Flatpak not found — install it first, then run:"
    msg_info "  bash post-install/spotx.sh"
fi
