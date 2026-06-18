#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install GNOME Shell extensions via gext
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_FILE="$SCRIPT_DIR/extensions.txt"

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

# ── Ensure gext is available ─────────────────────────────────
if ! command -v gext &>/dev/null; then
    msg_info "gext (gnome-extensions-cli) not found — installing via pip3..."
    pip3 install --user gnome-extensions-cli
    msg_ok "gext installed"
fi

# Ensure ~/.local/bin is in PATH
export PATH="$HOME/.local/bin:$PATH"

if ! command -v gext &>/dev/null; then
    msg_warn "gext still not found after install. Check pip3 --user install path."
    exit 1
fi

# ── Read extension UUIDs ─────────────────────────────────────
if [[ ! -f "$EXT_FILE" ]]; then
    msg_warn "Extension list not found: $EXT_FILE"
    exit 1
fi

FAILED_INSTALLS=()
INSTALLED=()

while IFS= read -r uuid; do
    # Skip empty lines and comments
    uuid="$(echo "$uuid" | xargs)"
    [[ -z "$uuid" || "$uuid" == \#* ]] && continue

    msg_info "Installing: $uuid"
    if gext install "$uuid" 2>/dev/null; then
        msg_ok "Installed: $uuid"
        INSTALLED+=("$uuid")
    else
        msg_warn "Failed to install: $uuid (may require manual install)"
        FAILED_INSTALLS+=("$uuid")
    fi
done < "$EXT_FILE"

# ── Enable all installed extensions ──────────────────────────
msg_info "Enabling extensions..."
for uuid in "${INSTALLED[@]}"; do
    gnome-extensions enable "$uuid" 2>/dev/null || {
        msg_warn "Could not enable: $uuid"
    }
done
msg_ok "Extensions enabled"

# ── Report ───────────────────────────────────────────────────
if [[ ${#FAILED_INSTALLS[@]} -gt 0 ]]; then
    printf "\n"
    msg_warn "The following extensions need manual installation:"
    for uuid in "${FAILED_INSTALLS[@]}"; do
        printf "  • %s\n" "$uuid"
    done
    printf "\n"
    msg_info "Install them via https://extensions.gnome.org or the Extensions app"
fi

msg_ok "GNOME extension setup complete (${#INSTALLED[@]} installed, ${#FAILED_INSTALLS[@]} failed)"
