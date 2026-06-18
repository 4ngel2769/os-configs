#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install gaming apps (Minecraft launchers + Modrinth)
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

GAMING_DIR="$HOME/.local/share/gaming"
APPIMAGES_DIR="$HOME/.local/share/appimages"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"

mkdir -p "$GAMING_DIR" "$APPIMAGES_DIR" "$BIN_DIR" "$DESKTOP_DIR"

# ── Check Java dependency ────────────────────────────────────
msg_info "Checking Java..."
if command -v java &>/dev/null; then
    JAVA_VERSION="$(java -version 2>&1 | head -1)"
    msg_ok "Java found: $JAVA_VERSION"
else
    msg_info "Java not found — installing java-21-openjdk..."
    sudo dnf install -y java-21-openjdk
    msg_ok "Java 21 OpenJDK installed"
fi

# ── 1. SKLauncher ────────────────────────────────────────────
msg_info "Installing SKLauncher..."

SK_DIR="$GAMING_DIR/SKlauncher"
SK_JAR="$SK_DIR/SKlauncher.jar"
mkdir -p "$SK_DIR"

if [[ -f "$SK_JAR" ]]; then
    msg_ok "SKLauncher already installed"
else
    msg_info "Downloading SKLauncher..."
    curl -fsSL -o "$SK_JAR" \
        "https://skmedv.ru/dl/SKlauncher.jar" \
        || { msg_warn "SKLauncher download failed — check URL at https://skmedv.ru/"; }

    if [[ -f "$SK_JAR" ]]; then
        msg_ok "SKLauncher downloaded"
    fi
fi

# Create wrapper script
cat > "$BIN_DIR/sklauncher" <<'WRAPPER'
#!/usr/bin/env bash
java -jar "$HOME/.local/share/gaming/SKlauncher/SKlauncher.jar" "$@"
WRAPPER
chmod +x "$BIN_DIR/sklauncher"

# Create .desktop entry
cat > "$DESKTOP_DIR/sklauncher.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=SKLauncher
Comment=Minecraft launcher (SKLauncher)
Exec=$HOME/.local/bin/sklauncher
Icon=minecraft
Categories=Game;
Terminal=false
StartupNotify=true
DESKTOP
msg_ok "SKLauncher configured"

# ── 2. LegacyLauncher ───────────────────────────────────────
msg_info "Installing LegacyLauncher..."

LL_DIR="$GAMING_DIR/LegacyLauncher"
LL_JAR="$LL_DIR/LegacyLauncher.jar"
mkdir -p "$LL_DIR"

if [[ -f "$LL_JAR" ]]; then
    msg_ok "LegacyLauncher already installed"
else
    msg_info "Downloading LegacyLauncher..."
    curl -fsSL -o "$LL_JAR" \
        "https://llaun.ch/jar" \
        || { msg_warn "LegacyLauncher download failed — check URL at https://llaun.ch/"; }

    if [[ -f "$LL_JAR" ]]; then
        msg_ok "LegacyLauncher downloaded"
    fi
fi

# Create wrapper script
cat > "$BIN_DIR/legacylauncher" <<'WRAPPER'
#!/usr/bin/env bash
java -jar "$HOME/.local/share/gaming/LegacyLauncher/LegacyLauncher.jar" "$@"
WRAPPER
chmod +x "$BIN_DIR/legacylauncher"

# Create .desktop entry
cat > "$DESKTOP_DIR/legacylauncher.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=LegacyLauncher
Comment=Minecraft launcher (LegacyLauncher)
Exec=$HOME/.local/bin/legacylauncher
Icon=minecraft
Categories=Game;
Terminal=false
StartupNotify=true
DESKTOP
msg_ok "LegacyLauncher configured"

# ── 3. Modrinth App ─────────────────────────────────────────
msg_info "Installing Modrinth App..."

MODRINTH_APPIMAGE="$APPIMAGES_DIR/Modrinth.AppImage"

if [[ -f "$MODRINTH_APPIMAGE" ]]; then
    msg_ok "Modrinth App already installed"
else
    msg_info "Fetching latest Modrinth App release..."

    MODRINTH_URL=$(curl -s https://api.github.com/repos/modrinth/theseus/releases/latest \
        | grep "browser_download_url" \
        | grep -i "appimage" \
        | head -1 \
        | cut -d '"' -f 4)

    if [[ -z "$MODRINTH_URL" ]]; then
        msg_warn "Could not find Modrinth AppImage download URL"
        msg_info "Install manually from: https://github.com/modrinth/theseus/releases"
        msg_info "Or use the Flatpak: flatpak install flathub com.modrinth.ModrinthApp"
    else
        msg_info "Downloading from: $MODRINTH_URL"
        curl -fsSL -o "$MODRINTH_APPIMAGE" "$MODRINTH_URL"
        chmod +x "$MODRINTH_APPIMAGE"
        msg_ok "Modrinth App downloaded"
    fi
fi

# Create .desktop entry
cat > "$DESKTOP_DIR/modrinth.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Modrinth App
Comment=Modrinth mod manager for Minecraft
Exec=$HOME/.local/share/appimages/Modrinth.AppImage
Icon=modrinth
Categories=Game;
Terminal=false
StartupNotify=true
DESKTOP
msg_ok "Modrinth App configured"

# ── Register desktop entries ─────────────────────────────────
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

msg_ok "Gaming apps installation complete"
