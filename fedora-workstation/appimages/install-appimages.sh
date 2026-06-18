#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install AppImages (LM Studio, Free Download Manager)
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

APPIMAGES_DIR="$HOME/.local/share/appimages"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$APPIMAGES_DIR" "$DESKTOP_DIR"

# ── 1. LM Studio ────────────────────────────────────────────
msg_info "Installing LM Studio..."

LMS_APPIMAGE="$APPIMAGES_DIR/LM-Studio.AppImage"

if [[ -f "$LMS_APPIMAGE" ]]; then
    msg_ok "LM Studio already installed"
else
    msg_info "Downloading LM Studio AppImage..."

    # LM Studio provides a direct download URL pattern for Linux
    LMS_URL="https://releases.lmstudio.ai/linux/x86_64/latest/LM-Studio.AppImage"

    curl -fsSL -o "$LMS_APPIMAGE" "$LMS_URL" || {
        msg_warn "LM Studio download failed"
        msg_info "Download manually from: https://lmstudio.ai/download"
        msg_info "Save to: $LMS_APPIMAGE"
    }

    if [[ -f "$LMS_APPIMAGE" ]]; then
        chmod +x "$LMS_APPIMAGE"
        msg_ok "LM Studio downloaded"
    fi
fi

# Create .desktop entry
cat > "$DESKTOP_DIR/lm-studio.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=LM Studio
Comment=Run local LLMs on your machine
Exec=$HOME/.local/share/appimages/LM-Studio.AppImage
Icon=lm-studio
Categories=Development;Science;
Terminal=false
StartupNotify=true
DESKTOP
msg_ok "LM Studio .desktop entry created"

# ── 2. Free Download Manager ────────────────────────────────
msg_info "Installing Free Download Manager..."

FDM_APPIMAGE="$APPIMAGES_DIR/FreeDownloadManager.AppImage"

if [[ -f "$FDM_APPIMAGE" ]]; then
    msg_ok "Free Download Manager already installed"
else
    msg_info "Downloading Free Download Manager..."

    # FDM provides a direct deb/AppImage download — try the deb-based approach
    # or direct AppImage URL. The AppImage may need extraction from their site.
    FDM_URL="https://files2.freedownloadmanager.org/6/latest/freedownloadmanager.AppImage"

    curl -fsSL -o "$FDM_APPIMAGE" "$FDM_URL" || {
        msg_warn "FDM AppImage download failed"
        msg_info "Download manually from: https://www.freedownloadmanager.org/download-fdm-for-linux.htm"
        msg_info "Save AppImage to: $FDM_APPIMAGE"
    }

    if [[ -f "$FDM_APPIMAGE" ]]; then
        chmod +x "$FDM_APPIMAGE"
        msg_ok "Free Download Manager downloaded"
    fi
fi

# Create .desktop entry
cat > "$DESKTOP_DIR/freedownloadmanager.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Free Download Manager
Comment=Powerful modern download accelerator and organizer
Exec=$HOME/.local/share/appimages/FreeDownloadManager.AppImage
Icon=freedownloadmanager
Categories=Network;FileTransfer;
Terminal=false
StartupNotify=true
DESKTOP
msg_ok "Free Download Manager .desktop entry created"

# ── Register desktop entries ─────────────────────────────────
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

# ── Note about Antigravity IDE ───────────────────────────────
# Antigravity IDE may not be available as a DNF package.
# If 'antigravity-ide' is not in the repo, download the tarball manually:
#
#   1. Visit: https://antigravity.google/download
#   2. Download the Linux tarball
#   3. Extract to ~/.local/share/antigravity-ide/
#   4. Create a .desktop entry or symlink the binary to ~/.local/bin/

msg_ok "AppImage installation complete"
