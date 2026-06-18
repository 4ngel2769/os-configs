#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Fedora third-party repository setup
# https://github.com/4ngel2769/os-configs
#
# All repo additions are idempotent — safe to run multiple times.
# ─────────────────────────────────────────────────────────────

msg_info()  { printf "\033[0;36m[i]\033[0m %s\n" "$*"; }
msg_ok()    { printf "\033[0;32m[✓]\033[0m %s\n" "$*"; }
msg_warn()  { printf "\033[1;33m[⚠]\033[0m %s\n" "$*"; }

FEDORA_VERSION="$(rpm -E %fedora)"
msg_info "Fedora version: $FEDORA_VERSION"

# ── 1. RPM Fusion Free + Nonfree ────────────────────────────
msg_info "Setting up RPM Fusion..."
if rpm -q rpmfusion-free-release &>/dev/null; then
    msg_ok "RPM Fusion Free already installed"
else
    sudo dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
    msg_ok "RPM Fusion Free installed"
fi

if rpm -q rpmfusion-nonfree-release &>/dev/null; then
    msg_ok "RPM Fusion Nonfree already installed"
else
    sudo dnf install -y \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"
    msg_ok "RPM Fusion Nonfree installed"
fi

# ── 2. Brave Browser ────────────────────────────────────────
msg_info "Setting up Brave Browser repo..."
if [[ -f /etc/yum.repos.d/brave-browser.repo ]]; then
    msg_ok "Brave repo already configured"
else
    sudo dnf install -y dnf-plugins-core
    sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
    sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
    msg_ok "Brave repo added"
fi

# ── 3. Google Chrome ────────────────────────────────────────
msg_info "Setting up Google Chrome..."
if rpm -q google-chrome-stable &>/dev/null; then
    msg_ok "Google Chrome already installed"
else
    sudo dnf install -y \
        "https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm"
    msg_ok "Google Chrome installed (self-manages its repo)"
fi

# ── 4. VS Code ──────────────────────────────────────────────
msg_info "Setting up VS Code repo..."
if [[ -f /etc/yum.repos.d/vscode.repo ]]; then
    msg_ok "VS Code repo already configured"
else
    sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
    cat <<'REPO' | sudo tee /etc/yum.repos.d/vscode.repo > /dev/null
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
REPO
    msg_ok "VS Code repo added"
fi

# ── 5. Sublime Text ─────────────────────────────────────────
msg_info "Setting up Sublime Text repo..."
if [[ -f /etc/yum.repos.d/sublime-text.repo ]]; then
    msg_ok "Sublime Text repo already configured"
else
    sudo rpm -v --import https://download.sublimetext.com/sublimehq-rpm-pub.gpg
    cat <<'REPO' | sudo tee /etc/yum.repos.d/sublime-text.repo > /dev/null
[sublime-text]
name=Sublime Text - x86_64 - Stable
baseurl=https://download.sublimetext.com/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://download.sublimetext.com/sublimehq-rpm-pub.gpg
REPO
    msg_ok "Sublime Text repo added"
fi

# ── 6. Docker CE ────────────────────────────────────────────
msg_info "Setting up Docker CE repo..."
if [[ -f /etc/yum.repos.d/docker-ce.repo ]]; then
    msg_ok "Docker CE repo already configured"
else
    sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
    msg_ok "Docker CE repo added"
fi

# ── 7. NVIDIA Container Toolkit ─────────────────────────────
msg_info "Setting up NVIDIA Container Toolkit repo..."
if [[ -f /etc/yum.repos.d/nvidia-container-toolkit.repo ]]; then
    msg_ok "NVIDIA Container Toolkit repo already configured"
else
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo \
        | sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo > /dev/null
    msg_ok "NVIDIA Container Toolkit repo added"
fi

# ── 8. COPR: phracek/PyCharm ────────────────────────────────
msg_info "Setting up PyCharm COPR..."
if sudo dnf copr list --enabled 2>/dev/null | grep -q "phracek/PyCharm"; then
    msg_ok "PyCharm COPR already enabled"
else
    sudo dnf copr enable phracek/PyCharm -y
    msg_ok "PyCharm COPR enabled"
fi

# ── 9. COPR: sunwire/envycontrol ────────────────────────────
msg_info "Setting up EnvyControl COPR..."
if sudo dnf copr list --enabled 2>/dev/null | grep -q "sunwire/envycontrol"; then
    msg_ok "EnvyControl COPR already enabled"
else
    sudo dnf copr enable sunwire/envycontrol -y
    msg_ok "EnvyControl COPR enabled"
fi

# ── 10. Terra ────────────────────────────────────────────────
msg_info "Setting up Terra repo..."
if rpm -q terra-release &>/dev/null; then
    msg_ok "Terra repo already installed"
else
    sudo dnf install -y \
        "https://github.com/terracurse/terra/releases/latest/download/terra-release.rpm" \
        || msg_warn "Terra repo install failed — check URL manually"
    msg_ok "Terra repo installed"
fi

# ── 11. Antigravity (Google) ────────────────────────────────
msg_info "Setting up Antigravity repo..."
if [[ -f /etc/yum.repos.d/antigravity.repo ]]; then
    msg_ok "Antigravity repo already configured"
else
    cat <<'REPO' | sudo tee /etc/yum.repos.d/antigravity.repo > /dev/null
[antigravity-rpm]
name=Antigravity RPM Repository
baseurl=https://us-central1-yum.pkg.dev/projects/antigravity-auto-updater-dev/antigravity-rpm
enabled=1
gpgcheck=0
REPO
    msg_ok "Antigravity repo added"
fi

# ── Refresh cache ────────────────────────────────────────────
msg_info "Refreshing DNF cache..."
sudo dnf makecache
msg_ok "All repos configured and cache refreshed"
