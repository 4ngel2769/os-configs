#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Ubuntu Server third-party repository setup
# https://github.com/4ngel2769/os-configs
#
# All repo additions are idempotent — safe to run multiple times.
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }

# ── 1. Yazi (official APT repo) ─────────────────────────────
msg_info "Setting up Yazi APT repo..."
if [[ -f /etc/apt/sources.list.d/yazi.list ]]; then
    msg_ok "Yazi repo already configured"
else
    curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg \
        | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null
    echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' \
        | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null
    msg_ok "Yazi repo added"
fi

msg_info "Refreshing APT cache..."
sudo apt update
msg_ok "All repos configured and cache refreshed"
