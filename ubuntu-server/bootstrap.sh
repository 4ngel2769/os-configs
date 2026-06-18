#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Ubuntu Server Bootstrap
# https://github.com/4ngel2769/os-configs
#
# Headless Ubuntu server setup for Docker/Portainer stack
# Target machine: blade (8TB external, Docker data-root on 8TB)
# ─────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

msg_info()    { printf "${CYAN}[i]${NC} %s\n" "$*"; }
msg_ok()      { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
msg_warn()    { printf "${YELLOW}[⚠]${NC} %s\n" "$*"; }
msg_error()   { printf "${RED}[✗]${NC} %s\n" "$*"; }
msg_phase()   { printf "\n${BOLD}${MAGENTA}==> Phase: %s${NC}\n" "$*"; }

# ── Defaults ─────────────────────────────────────────────────
MODE="interactive"
SKIP_PACKAGES=false
SKIP_DOCKER=false
SKIP_DOTFILES=false

# ── Phase tracking ───────────────────────────────────────────
declare -A PHASE_STATUS
PHASE_ORDER=()

track_phase() {
    local name="$1"
    PHASE_ORDER+=("$name")
    PHASE_STATUS["$name"]="pending"
}

track_phase "System updated"
track_phase "APT packages installed"
track_phase "Docker CE configured"
track_phase "Tailscale installed"
track_phase "Oh My Zsh + plugins"
track_phase "nvm + Node LTS"
track_phase "Dotfiles stowed"

# ── Argument parsing ─────────────────────────────────────────
usage() {
    cat <<EOF
${BOLD}os-configs — Ubuntu Server Bootstrap${NC}

${BOLD}Usage:${NC} bootstrap.sh [OPTIONS]

${BOLD}Options:${NC}
  --auto              Non-interactive, skip all prompts (assume yes)
  --skip-packages     Skip APT package install
  --skip-docker       Skip Docker CE setup
  --skip-dotfiles     Skip stow dotfiles
  --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto)          MODE="auto"; shift ;;
        --skip-packages) SKIP_PACKAGES=true; shift ;;
        --skip-docker)   SKIP_DOCKER=true; shift ;;
        --skip-dotfiles) SKIP_DOTFILES=true; shift ;;
        --help|-h)       usage; exit 0 ;;
        *)               msg_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# ── Run phase wrapper ────────────────────────────────────────
run_phase() {
    local phase_name="$1"
    local phase_func="$2"
    local skip_flag="${3:-false}"

    msg_phase "$phase_name"

    if [[ "$skip_flag" == "true" ]]; then
        msg_warn "Skipped (--skip flag)"
        PHASE_STATUS["$phase_name"]="skipped"
        return 0
    fi

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
    printf "  │   Ubuntu Server Bootstrap                 │\n"
    printf "  │   os-configs by 4ngel2769                 │\n"
    printf "  └──────────────────────────────────────────┘\n"
    printf "${NC}\n"
}

# ══════════════════════════════════════════════════════════════
# PHASE FUNCTIONS
# ══════════════════════════════════════════════════════════════

# ── Preflight ────────────────────────────────────────────────
phase_preflight() {
    if [[ ! -f /etc/os-release ]]; then
        msg_error "Cannot read /etc/os-release"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release
    if [[ "${ID:-}" != "ubuntu" ]]; then
        msg_error "This script is for Ubuntu, but detected: ${ID:-unknown}"
        exit 1
    fi

    msg_ok "Distro: $NAME $VERSION_ID"
    msg_ok "Hostname: $(hostname)"
    msg_ok "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    msg_ok "User: $(whoami)"
    msg_ok "Mode: $MODE"

    # Install stow if missing
    if ! command -v stow &>/dev/null; then
        msg_info "Installing stow..."
        sudo apt install -y stow
    fi
}

# ── 1. System update ────────────────────────────────────────
phase_update() {
    msg_info "Updating system..."
    sudo apt update
    sudo apt upgrade -y
    msg_ok "System updated"
}

# ── 2. APT packages ─────────────────────────────────────────
phase_apt() {
    local pkg_file="$SCRIPT_DIR/packages/apt.txt"

    if [[ ! -f "$pkg_file" ]]; then
        msg_error "Package list not found: $pkg_file"
        return 1
    fi

    local packages=()
    while IFS= read -r line; do
        line="${line%%#*}"
        line="$(echo "$line" | xargs)"
        [[ -n "$line" ]] && packages+=("$line")
    done < "$pkg_file"

    if [[ ${#packages[@]} -eq 0 ]]; then
        msg_warn "No packages found in $pkg_file"
        return 0
    fi

    msg_info "Installing ${#packages[@]} packages..."
    sudo apt install -y "${packages[@]}"
    msg_ok "APT packages installed"
}

# ── 3. Docker CE ─────────────────────────────────────────────
phase_docker() {
    msg_info "Setting up Docker CE..."

    # Add Docker's official GPG key
    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        sudo apt install -y ca-certificates curl
        sudo install -m 0755 -d /etc/apt/keyrings
        sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        sudo chmod a+r /etc/apt/keyrings/docker.asc
    fi

    # Add Docker repo
    if [[ ! -f /etc/apt/sources.list.d/docker.list ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        echo \
            "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
            ${UBUNTU_CODENAME:-$VERSION_CODENAME} stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
    fi

    # Install Docker
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Add current user to docker group
    if ! groups "$(whoami)" | grep -q docker; then
        sudo usermod -aG docker "$(whoami)"
        msg_warn "Added $(whoami) to docker group — log out/in to take effect"
    fi

    # Enable and start Docker
    sudo systemctl enable docker
    sudo systemctl start docker

    msg_ok "Docker CE configured"
}

# ── 4. Tailscale ─────────────────────────────────────────────
phase_tailscale() {
    msg_info "Setting up Tailscale..."

    if command -v tailscale &>/dev/null; then
        msg_ok "Tailscale already installed"
    else
        curl -fsSL https://tailscale.com/install.sh | sh
        msg_ok "Tailscale installed"
    fi

    sudo systemctl enable tailscaled
    sudo systemctl start tailscaled

    msg_info "Run 'sudo tailscale up' to authenticate"
    msg_ok "Tailscale configured"
}

# ── 5. Oh My Zsh ────────────────────────────────────────────
phase_ohmyzsh() {
    bash "$REPO_ROOT/shared/scripts/install-ohmyzsh.sh"
}

# ── 6. nvm ───────────────────────────────────────────────────
phase_nvm() {
    bash "$REPO_ROOT/shared/scripts/install-nvm.sh"
}

# ── 7. Dotfiles ──────────────────────────────────────────────
phase_dotfiles() {
    msg_info "Stowing dotfiles..."

    # Stow shared dotfiles
    for pkg in "$REPO_ROOT"/shared/dotfiles/*/; do
        local pkg_name
        pkg_name="$(basename "$pkg")"
        msg_info "  Stowing shared/$pkg_name"
        stow --adopt -R -d "$REPO_ROOT/shared/dotfiles" -t "$HOME" "$pkg_name" || {
            msg_warn "  Failed to stow shared/$pkg_name"
        }
    done

    # Stow ubuntu-server dotfiles
    for pkg in "$SCRIPT_DIR"/dotfiles/*/; do
        local pkg_name
        pkg_name="$(basename "$pkg")"
        msg_info "  Stowing ubuntu-server/$pkg_name"
        stow --adopt -R -d "$SCRIPT_DIR/dotfiles" -t "$HOME" "$pkg_name" || {
            msg_warn "  Failed to stow ubuntu-server/$pkg_name"
        }
    done

    msg_ok "Dotfiles stowed"
}

# ── Summary ──────────────────────────────────────────────────
print_summary() {
    printf "\n"
    printf "${BOLD}${CYAN}"
    printf "  ╔══════════════════════════════════════╗\n"
    printf "  ║   Ubuntu Server Bootstrap – Summary  ║\n"
    printf "  ╠══════════════════════════════════════╣\n"
    printf "${NC}"

    for phase in "${PHASE_ORDER[@]}"; do
        local status="${PHASE_STATUS[$phase]}"
        local icon color
        case "$status" in
            success) icon="✓"; color="$GREEN" ;;
            skipped) icon="⚠"; color="$YELLOW" ;;
            failed)  icon="✗"; color="$RED" ;;
            *)       icon="·"; color="$DIM" ;;
        esac
        printf "  ${color}  ${icon} %-34s${NC}\n" "$phase"
    done

    printf "${BOLD}${CYAN}"
    printf "  ╠══════════════════════════════════════╣\n"
    printf "  ║  Manual steps remaining:             ║\n"
    printf "${NC}"
    printf "  ${DIM}  • Run: sudo tailscale up            ${NC}\n"
    printf "  ${DIM}  • Log out/in for docker group        ${NC}\n"
    printf "  ${DIM}  • Mount 8TB drive at /mnt/8tbv1      ${NC}\n"
    printf "${BOLD}${CYAN}"
    printf "  ╚══════════════════════════════════════╝\n"
    printf "${NC}\n"
}

# ══════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════

main() {
    print_banner
    phase_preflight

    run_phase "System updated"          phase_update     false
    run_phase "APT packages installed"  phase_apt        "$SKIP_PACKAGES"
    run_phase "Docker CE configured"    phase_docker     "$SKIP_DOCKER"
    run_phase "Tailscale installed"     phase_tailscale  false
    run_phase "Oh My Zsh + plugins"     phase_ohmyzsh    false
    run_phase "nvm + Node LTS"         phase_nvm        false
    run_phase "Dotfiles stowed"        phase_dotfiles   "$SKIP_DOTFILES"

    print_summary
}

main "$@"
