#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Fedora Workstation Bootstrap
# https://github.com/4ngel2769/os-configs
#
# Full system restore script for Fedora Workstation (GNOME)
# Target machine: Acer Aspire A715-51G
# ─────────────────────────────────────────────────────────────

# ── Script directory ─────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ── Messaging functions ─────────────────────────────────────
msg_info()    { printf "${CYAN}[i]${NC} %s\n" "$*"; }
msg_ok()      { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
msg_warn()    { printf "${YELLOW}[⚠]${NC} %s\n" "$*"; }
msg_error()   { printf "${RED}[✗]${NC} %s\n" "$*"; }
msg_phase()   { printf "\n${BOLD}${MAGENTA}==> Phase: %s${NC}\n" "$*"; }
msg_section() { printf "${BLUE}──── %s ────${NC}\n" "$*"; }

# ── Defaults ─────────────────────────────────────────────────
MODE="interactive"  # interactive or auto
SKIP_PACKAGES=false
SKIP_REPOS=false
SKIP_GNOME=false
SKIP_DOTFILES=false
SKIP_GAMING=false
SKIP_APPIMAGES=false
SKIP_POST_INSTALL=false

# ── Phase tracking ───────────────────────────────────────────
declare -A PHASE_STATUS
PHASE_ORDER=()

track_phase() {
    local name="$1"
    PHASE_ORDER+=("$name")
    PHASE_STATUS["$name"]="pending"
}

# Initialize all phases
track_phase "Repos configured"
track_phase "DNF packages installed"
track_phase "Flatpaks installed"
track_phase "Oh My Zsh + plugins"
track_phase "nvm + Node LTS"
track_phase "bun"
track_phase "Homebrew"
track_phase "Dotfiles stowed"
track_phase "GNOME extensions installed"
track_phase "Themes applied"
track_phase "dconf settings loaded"
track_phase "Wallpaper set"
track_phase "AppImages installed"
track_phase "Gaming apps installed"
track_phase "SpotX applied"
track_phase "Aseprite"

# ── Argument parsing ─────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}os-configs — Fedora Workstation Bootstrap${NC}

${BOLD}Usage:${NC} bootstrap.sh [OPTIONS]

${BOLD}Options:${NC}
  --auto              Non-interactive, skip all prompts (assume yes)
  --interactive       Prompt before each phase (default)
  --skip-packages     Skip DNF + Flatpak install
  --skip-repos        Skip repo setup
  --skip-gnome        Skip GNOME extensions, dconf, themes
  --skip-dotfiles     Skip stow dotfiles
  --skip-gaming       Skip gaming apps (SKLauncher, LegacyLauncher, Modrinth)
  --skip-appimages    Skip AppImage installs
  --skip-post-install Skip post-install patches (SpotX, etc.)
  --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)
            MODE="auto"
            shift
            ;;
        --interactive)
            MODE="interactive"
            shift
            ;;
        --skip-packages)
            SKIP_PACKAGES=true
            shift
            ;;
        --skip-repos)
            SKIP_REPOS=true
            shift
            ;;
        --skip-gnome)
            SKIP_GNOME=true
            shift
            ;;
        --skip-dotfiles)
            SKIP_DOTFILES=true
            shift
            ;;
        --skip-gaming)
            SKIP_GAMING=true
            shift
            ;;
        --skip-appimages)
            SKIP_APPIMAGES=true
            shift
            ;;
        --skip-post-install)
            SKIP_POST_INSTALL=true
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            msg_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ── Run phase wrapper ────────────────────────────────────────
# Handles interactive prompting, error catching, and status tracking
run_phase() {
    local phase_name="$1"
    local phase_func="$2"
    local skip_flag="${3:-false}"

    msg_phase "$phase_name"

    # Check skip flag
    if [[ "$skip_flag" == "true" ]]; then
        msg_warn "Skipped (--skip flag)"
        PHASE_STATUS["$phase_name"]="skipped"
        return 0
    fi

    # Interactive prompt
    if [[ "$MODE" == "interactive" ]]; then
        printf "${BOLD}Continue? [Y/n]:${NC} "
        read -r response
        case "${response:-Y}" in
            [nN]|[nN][oO])
                msg_warn "Skipped by user"
                PHASE_STATUS["$phase_name"]="skipped"
                return 0
                ;;
        esac
    fi

    # Execute phase function, catch errors
    if ( set -euo pipefail; "$phase_func" ); then
        PHASE_STATUS["$phase_name"]="success"
        msg_ok "$phase_name — done"
    else
        PHASE_STATUS["$phase_name"]="failed"
        msg_error "$phase_name — FAILED (continuing...)"
    fi
}

# ── Banner ───────────────────────────────────────────────────
print_banner() {
    printf "\n"
    printf "${BOLD}${CYAN}"
    printf "  ┌──────────────────────────────────────────┐\n"
    printf "  │   Fedora Workstation Bootstrap            │\n"
    printf "  │   os-configs by 4ngel2769                 │\n"
    printf "  └──────────────────────────────────────────┘\n"
    printf "${NC}\n"
}

# ══════════════════════════════════════════════════════════════
# PHASE FUNCTIONS
# ══════════════════════════════════════════════════════════════

# ── 0. Preflight ─────────────────────────────────────────────
phase_preflight() {
    msg_section "Preflight checks"

    # Check distro
    if [[ ! -f /etc/os-release ]]; then
        msg_error "Cannot read /etc/os-release"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    if [[ "${ID:-}" != "fedora" ]]; then
        msg_error "This script is for Fedora, but detected: ${ID:-unknown}"
        exit 1
    fi

    msg_ok "Distro: $NAME $VERSION_ID"
    msg_ok "Hostname: $(hostname)"
    msg_ok "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    msg_ok "User: $(whoami)"
    msg_ok "Mode: $MODE"

    # Ensure essential tools
    for cmd in dnf git curl; do
        if command -v "$cmd" &>/dev/null; then
            msg_ok "Found: $cmd"
        else
            msg_error "Missing required command: $cmd"
            exit 1
        fi
    done

    # Install stow if missing
    if ! command -v stow &>/dev/null; then
        msg_info "Installing stow..."
        sudo dnf install -y stow
        msg_ok "stow installed"
    else
        msg_ok "Found: stow"
    fi
}

# ── 1. Repos ─────────────────────────────────────────────────
phase_repos() {
    msg_section "Adding third-party repositories"
    bash "$SCRIPT_DIR/packages/repos.sh"
}

# ── 2. DNF packages ─────────────────────────────────────────
phase_dnf() {
    msg_section "Installing DNF packages"
    local pkg_file="$SCRIPT_DIR/packages/dnf.txt"

    if [[ ! -f "$pkg_file" ]]; then
        msg_error "Package list not found: $pkg_file"
        return 1
    fi

    # Read non-empty, non-comment lines
    local packages=()
    while IFS= read -r line; do
        # Strip inline comments and whitespace
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -n "$line" ]] && packages+=("$line")
    done < "$pkg_file"

    if [[ ${#packages[@]} -eq 0 ]]; then
        msg_warn "No packages found in $pkg_file"
        return 0
    fi

    msg_info "Installing ${#packages[@]} packages..."
    sudo dnf install -y "${packages[@]}"
    msg_ok "DNF packages installed"
}

# ── 3. Flatpak packages ─────────────────────────────────────
phase_flatpak() {
    msg_section "Installing Flatpak apps"

    # Ensure Flathub is added
    if ! flatpak remotes | grep -q "flathub"; then
        msg_info "Adding Flathub remote..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    fi
    msg_ok "Flathub remote configured"

    local pkg_file="$SCRIPT_DIR/packages/flatpak.txt"

    if [[ ! -f "$pkg_file" ]]; then
        msg_error "Flatpak list not found: $pkg_file"
        return 1
    fi

    # Read non-empty, non-comment lines
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -z "$line" ]] && continue

        msg_info "Installing: $line"
        flatpak install -y flathub "$line" || msg_warn "Failed to install: $line"
    done < "$pkg_file"

    msg_ok "Flatpak apps installed"
}

# ── 4. Oh My Zsh ────────────────────────────────────────────
phase_ohmyzsh() {
    msg_section "Oh My Zsh"
    bash "$REPO_ROOT/shared/scripts/install-ohmyzsh.sh"
}

# ── 5. nvm ───────────────────────────────────────────────────
phase_nvm() {
    msg_section "nvm"
    bash "$REPO_ROOT/shared/scripts/install-nvm.sh"
}

# ── 6. bun ───────────────────────────────────────────────────
phase_bun() {
    msg_section "bun"
    bash "$REPO_ROOT/shared/scripts/install-bun.sh"
}

# ── 7. Homebrew ──────────────────────────────────────────────
phase_homebrew() {
    msg_section "Homebrew"
    bash "$REPO_ROOT/shared/scripts/install-homebrew.sh"
}

# ── 8. Dotfiles ──────────────────────────────────────────────
phase_dotfiles() {
    msg_section "Stowing dotfiles"

    # Stow shared dotfiles first
    msg_info "Stowing shared dotfiles..."
    for pkg in "$REPO_ROOT"/shared/dotfiles/*/; do
        local pkg_name
        pkg_name="$(basename "$pkg")"
        msg_info "  Stowing shared/$pkg_name"
        stow --adopt -R -d "$REPO_ROOT/shared/dotfiles" -t "$HOME" "$pkg_name" || {
            msg_warn "  Failed to stow shared/$pkg_name"
        }
    done

    # Stow fedora-specific dotfiles
    msg_info "Stowing fedora-workstation dotfiles..."
    for pkg in "$SCRIPT_DIR"/dotfiles/*/; do
        local pkg_name
        pkg_name="$(basename "$pkg")"
        msg_info "  Stowing fedora-workstation/$pkg_name"
        stow --adopt -R -d "$SCRIPT_DIR/dotfiles" -t "$HOME" "$pkg_name" || {
            msg_warn "  Failed to stow fedora-workstation/$pkg_name"
        }
    done

    # Check for adopted files
    local git_diff
    git_diff="$(cd "$REPO_ROOT" && git diff --stat 2>/dev/null || true)"
    if [[ -n "$git_diff" ]]; then
        msg_warn "stow --adopt pulled in existing files. Review changes:"
        printf "${DIM}%s${NC}\n" "$git_diff"
        msg_info "Run 'cd $REPO_ROOT && git diff' to review, then commit if OK"
    fi

    msg_ok "Dotfiles stowed"
}

# ── 9. GNOME extensions ─────────────────────────────────────
phase_gnome_extensions() {
    msg_section "GNOME extensions"
    bash "$SCRIPT_DIR/gnome/install-extensions.sh"
}

# ── 10. GNOME themes ────────────────────────────────────────
phase_gnome_themes() {
    msg_section "GNOME themes"
    bash "$SCRIPT_DIR/themes/install-themes.sh"
}

# ── 11. GNOME dconf ─────────────────────────────────────────
phase_dconf() {
    msg_section "Loading dconf settings"

    local gnome_dir="$SCRIPT_DIR/gnome"

    # Load extension settings
    if [[ -f "$gnome_dir/dconf-extensions.conf" ]]; then
        msg_info "Loading extension settings..."
        dconf load /org/gnome/shell/extensions/ < "$gnome_dir/dconf-extensions.conf"
        msg_ok "Extension dconf loaded"
    fi

    # Load interface settings
    if [[ -f "$gnome_dir/dconf-interface.conf" ]]; then
        msg_info "Loading interface settings..."
        dconf load /org/gnome/desktop/interface/ < "$gnome_dir/dconf-interface.conf"
        msg_ok "Interface dconf loaded"
    fi

    # Load background settings (substitute $HOME)
    if [[ -f "$gnome_dir/dconf-background.conf" ]]; then
        msg_info "Loading background settings..."
        sed "s|/home/user|$HOME|g" "$gnome_dir/dconf-background.conf" \
            | dconf load /org/gnome/desktop/background/
        msg_ok "Background dconf loaded"
    fi

    # Load keybinding settings
    if [[ -f "$gnome_dir/dconf-keybindings.conf" ]]; then
        msg_info "Loading keybinding settings..."
        dconf load /org/gnome/desktop/wm/keybindings/ < "$gnome_dir/dconf-keybindings.conf"
        msg_ok "Keybinding dconf loaded"
    fi

    msg_ok "dconf settings applied"
}

# ── 12. Wallpaper ────────────────────────────────────────────
phase_wallpaper() {
    msg_section "Setting wallpaper"

    local wp_src="$SCRIPT_DIR/wallpaper/wallpaper.jpg"
    local wp_dest="$HOME/.local/share/wallpapers/wallpaper.jpg"

    mkdir -p "$(dirname "$wp_dest")"

    if [[ -f "$wp_src" ]]; then
        cp "$wp_src" "$wp_dest"
        msg_ok "Wallpaper copied to $wp_dest"
    else
        msg_warn "Wallpaper source not found: $wp_src"
        msg_info "Attempting to download from Immich..."
        curl -fsSL -o "$wp_dest" \
            "https://ipp.angellabs.xyz/share/photo/Ea3WHvx4w3gJmUpfMLF3X4Ly8M8GDlppmf9WyOAPjngwW1u_XPmgrca9C2vBNySbWlY/12bce6bb-c691-49bc-ac9a-73dc169bd288/original" \
            || { msg_warn "Download failed — set wallpaper manually"; return 0; }
        msg_ok "Wallpaper downloaded"
    fi

    # Set wallpaper for both light and dark
    local wp_uri="file://$wp_dest"
    gsettings set org.gnome.desktop.background picture-uri "$wp_uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$wp_uri"
    gsettings set org.gnome.desktop.background picture-options 'zoom'

    msg_ok "Wallpaper set"
}

# ── 13. AppImages ────────────────────────────────────────────
phase_appimages() {
    msg_section "AppImages"
    bash "$SCRIPT_DIR/appimages/install-appimages.sh"
}

# ── 14. Gaming ───────────────────────────────────────────────
phase_gaming() {
    msg_section "Gaming apps"
    bash "$SCRIPT_DIR/gaming/install-gaming.sh"
}

# ── 15. SpotX ────────────────────────────────────────────────
phase_spotx() {
    msg_section "SpotX (Spotify patcher)"

    local auto_flag=""
    [[ "$MODE" == "auto" ]] && auto_flag="--auto"

    bash "$SCRIPT_DIR/post-install/spotx.sh" $auto_flag
}

# ── 16. Aseprite ─────────────────────────────────────────────
phase_aseprite() {
    msg_section "Aseprite"
    bash "$SCRIPT_DIR/post-install/aseprite.sh" || true
}

# ── Summary ──────────────────────────────────────────────────
print_summary() {
    printf "\n"
    printf "${BOLD}${CYAN}"
    printf "  ╔══════════════════════════════════════╗\n"
    printf "  ║     Bootstrap Complete – Summary     ║\n"
    printf "  ╠══════════════════════════════════════╣\n"
    printf "${NC}"

    for phase in "${PHASE_ORDER[@]}"; do
        local status="${PHASE_STATUS[$phase]}"
        local icon color extra=""
        case "$status" in
            success)
                icon="✓"
                color="$GREEN"
                ;;
            skipped)
                icon="⚠"
                color="$YELLOW"
                ;;
            failed)
                icon="✗"
                color="$RED"
                ;;
            *)
                icon="·"
                color="$DIM"
                ;;
        esac

        # Special note for Aseprite
        if [[ "$phase" == "Aseprite" && "$status" != "success" ]]; then
            extra=" ASEPRITE_SCRIPT_URL"
            printf "  ${color}  ${icon} %-34s${NC}\n" "$phase:"
            printf "  ${DIM}    not set — run manually${NC}\n"
        else
            printf "  ${color}  ${icon} %-34s${NC}\n" "$phase"
        fi
    done

    printf "${BOLD}${CYAN}"
    printf "  ╠══════════════════════════════════════╣\n"
    printf "  ║  Manual steps remaining:             ║\n"
    printf "${NC}"
    printf "  ${DIM}  • Log in to Brave Browser           ${NC}\n"
    printf "  ${DIM}  • Install ProtonPass browser ext     ${NC}\n"
    printf "  ${DIM}  • Run: tailscale up                  ${NC}\n"
    printf "  ${DIM}  • Log out and back in (GNOME)        ${NC}\n"
    printf "${BOLD}${CYAN}"
    printf "  ╚══════════════════════════════════════╝\n"
    printf "${NC}\n"
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

main() {
    print_banner

    # Preflight (always runs, not skippable)
    phase_preflight

    # Run phases in order
    run_phase "Repos configured"            phase_repos            "$SKIP_REPOS"
    run_phase "DNF packages installed"      phase_dnf              "$SKIP_PACKAGES"
    run_phase "Flatpaks installed"          phase_flatpak          "$SKIP_PACKAGES"
    run_phase "Oh My Zsh + plugins"         phase_ohmyzsh          false
    run_phase "nvm + Node LTS"             phase_nvm              false
    run_phase "bun"                        phase_bun              false
    run_phase "Homebrew"                   phase_homebrew          false
    run_phase "Dotfiles stowed"            phase_dotfiles          "$SKIP_DOTFILES"
    run_phase "GNOME extensions installed" phase_gnome_extensions  "$SKIP_GNOME"
    run_phase "Themes applied"             phase_gnome_themes      "$SKIP_GNOME"
    run_phase "dconf settings loaded"      phase_dconf             "$SKIP_GNOME"
    run_phase "Wallpaper set"              phase_wallpaper         "$SKIP_GNOME"
    run_phase "AppImages installed"        phase_appimages         "$SKIP_APPIMAGES"
    run_phase "Gaming apps installed"      phase_gaming            "$SKIP_GAMING"
    run_phase "SpotX applied"              phase_spotx             "$SKIP_POST_INSTALL"
    run_phase "Aseprite"                   phase_aseprite          "$SKIP_POST_INSTALL"

    # Print summary
    print_summary
}

main "$@"
