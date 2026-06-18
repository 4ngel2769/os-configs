#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install GNOME themes (icons + cursor)
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

# ── 1. Papirus Icon Theme ───────────────────────────────────
msg_info "Installing Papirus icon theme..."
if rpm -q papirus-icon-theme &>/dev/null; then
    msg_ok "Papirus icon theme already installed"
else
    sudo dnf install -y papirus-icon-theme
    msg_ok "Papirus icon theme installed"
fi

gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark'
msg_ok "Icon theme set to Papirus-Dark"

# ── 2. macOS Monterey Cursor Theme ──────────────────────────
msg_info "Installing macOS Monterey cursor theme..."

ICONS_DIR="$HOME/.local/share/icons"
mkdir -p "$ICONS_DIR"

if [[ -d "$ICONS_DIR/macOS-Monterey" ]]; then
    msg_ok "macOS Monterey cursor already installed"
else
    msg_info "Fetching latest release from ful1e5/apple_cursor..."

    CURSOR_URL=$(curl -s https://api.github.com/repos/ful1e5/apple_cursor/releases/latest \
        | grep "browser_download_url" \
        | grep "macOS-Monterey.tar.gz" \
        | head -1 \
        | cut -d '"' -f 4)

    if [[ -z "$CURSOR_URL" ]]; then
        msg_warn "Could not find macOS Monterey cursor download URL"
        msg_info "Install manually from: https://github.com/ful1e5/apple_cursor/releases"
    else
        msg_info "Downloading from: $CURSOR_URL"
        local tmp_file
        tmp_file="$(mktemp /tmp/macos-monterey-cursor.XXXXXX.tar.gz)"

        curl -fsSL -o "$tmp_file" "$CURSOR_URL"
        tar xzf "$tmp_file" -C "$ICONS_DIR"
        rm -f "$tmp_file"

        msg_ok "macOS Monterey cursor installed to $ICONS_DIR"
    fi
fi

gsettings set org.gnome.desktop.interface cursor-theme 'macOS-Monterey'
gsettings set org.gnome.desktop.interface cursor-size 24
msg_ok "Cursor theme set to macOS-Monterey (size 24)"

msg_ok "Theme installation complete"
