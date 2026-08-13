#!/usr/bin/env bash
set -euo pipefail

sources_run() {
    local dry_run="$1"
    shift
    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would run: $*"
        return 0
    fi
    "$@"
}

sources_ensure_component() {
    local component="$1"
    local dry_run="${2:-false}"

    case "${DISTRO_FAMILY}:${component}" in
        ubuntu:multiverse)
            sources_run "$dry_run" sudo apt-get install -y software-properties-common
            sources_run "$dry_run" sudo add-apt-repository -y multiverse
            ;;
        debian:non-free)
            # non-free is usually in sources.list on Debian — refresh only
            sources_run "$dry_run" sudo apt-get update -qq
            ;;
        fedora:rpmfusion-nonfree)
            local ver
            ver="$(rpm -E %fedora 2>/dev/null || echo "")"
            [[ -n "$ver" ]] || return 1
            if ! rpm -q rpmfusion-nonfree-release &>/dev/null; then
                sources_run "$dry_run" sudo dnf install -y \
                    "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm"
            fi
            ;;
    esac
}

sources_ensure() {
    local source_id="$1"
    local dry_run="${2:-false}"

    case "${DISTRO_FAMILY}:${source_id}" in
        debian:brave | ubuntu:brave)
            if [[ ! -f /etc/apt/sources.list.d/brave-browser-release.list ]]; then
                sources_run "$dry_run" sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
                    https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
        fedora:brave)
            if [[ ! -f /etc/yum.repos.d/brave-browser.repo ]]; then
                sources_run "$dry_run" sudo rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
                sources_run "$dry_run" sudo dnf config-manager addrepo \
                    --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
            fi
            ;;
        debian:google-chrome | ubuntu:google-chrome)
            if [[ ! -f /etc/apt/sources.list.d/google-chrome.list ]]; then
                sources_run "$dry_run" sudo curl -fsSLo /usr/share/keyrings/google-chrome.gpg \
                    https://dl.google.com/linux/linux_signing_key.pub
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
        fedora:google-chrome)
            if ! rpm -q google-chrome-stable &>/dev/null; then
                sources_run "$dry_run" sudo dnf install -y \
                    https://dl.google.com/linux/direct/google-chrome-stable_current_x86_64.rpm
            fi
            ;;
        debian:vivaldi | ubuntu:vivaldi)
            if [[ ! -f /etc/apt/sources.list.d/vivaldi.list ]]; then
                sources_run "$dry_run" wget -qO- https://repo.vivaldi.com/stable/linux_signing_key.pub \
                    | sudo gpg --dearmor -o /usr/share/keyrings/vivaldi.gpg
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/vivaldi.list >/dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/vivaldi.gpg] https://repo.vivaldi.com/stable/deb/ stable main
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
        fedora:vivaldi)
            if [[ ! -f /etc/yum.repos.d/vivaldi.repo ]]; then
                sources_run "$dry_run" sudo dnf config-manager addrepo \
                    --from-repofile=https://repo.vivaldi.com/stable/vivaldi-fedora.repo
            fi
            ;;
        debian:opera | ubuntu:opera)
            if [[ ! -f /etc/apt/sources.list.d/opera-stable.list ]]; then
                sources_run "$dry_run" wget -qO- https://deb.opera.com/archive.key \
                    | sudo gpg --dearmor -o /usr/share/keyrings/opera.gpg
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/opera-stable.list >/dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/opera.gpg] https://deb.opera.com/opera-stable/ stable non-free
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
        fedora:opera)
            if [[ ! -f /etc/yum.repos.d/opera.repo ]]; then
                sources_run "$dry_run" sudo tee /etc/yum.repos.d/opera.repo >/dev/null <<'EOF'
[opera]
name=Opera
baseurl=https://rpm.opera.com/rpm/
enabled=1
gpgcheck=1
gpgkey=https://rpm.opera.com/rpmrepo.key
EOF
            fi
            ;;
        debian:signal | ubuntu:signal)
            if [[ ! -f /etc/apt/sources.list.d/signal-desktop.list ]]; then
                sources_run "$dry_run" wget -qO- https://updates.signal.org/desktop/apt/dists/stable/Release.gpg \
                    | sudo gpg --dearmor -o /usr/share/keyrings/signal-desktop.gpg
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/signal-desktop.list >/dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/signal-desktop.gpg] https://updates.signal.org/desktop/apt stable main
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
        debian:vscode | ubuntu:vscode)
            if [[ ! -f /etc/apt/sources.list.d/vscode.list ]]; then
                sources_run "$dry_run" wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
                    | sudo gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null <<'EOF'
deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
        fedora:vscode)
            if [[ ! -f /etc/yum.repos.d/vscode.repo ]]; then
                sources_run "$dry_run" sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
                sources_run "$dry_run" sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
            fi
            ;;
        fedora:yazi)
            if ! sudo dnf copr list --enabled 2>/dev/null | grep -q "lihaohong/yazi"; then
                sources_run "$dry_run" sudo dnf copr enable -y lihaohong/yazi
            fi
            ;;
        debian:yazi | ubuntu:yazi)
            if [[ ! -f /etc/apt/sources.list.d/yazi.list ]]; then
                sources_run "$dry_run" curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg \
                    | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null
                sources_run "$dry_run" sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null <<'EOF'
deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main
EOF
                sources_run "$dry_run" sudo apt-get update -qq
            fi
            ;;
    esac
}

flatpak_ensure() {
    local dry_run="${1:-false}"

    if command -v flatpak &>/dev/null; then
        flatpak_ensure_flathub "$dry_run"
        return 0
    fi

    case "${DISTRO_FAMILY}" in
        arch) sources_run "$dry_run" sudo pacman -S --needed --noconfirm flatpak ;;
        debian | ubuntu) sources_run "$dry_run" sudo apt-get install -y flatpak ;;
        fedora) sources_run "$dry_run" sudo dnf install -y flatpak ;;
    esac
    flatpak_ensure_flathub "$dry_run"
}

flatpak_ensure_flathub() {
    local dry_run="${1:-false}"

    if flatpak remotes 2>/dev/null | grep -q flathub; then
        return 0
    fi
    sources_run "$dry_run" flatpak remote-add --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo
}
