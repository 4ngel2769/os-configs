#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — top-level curl-able dispatcher
# https://github.com/4ngel2769/os-configs
#
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/setup.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/setup.sh) --auto
# ─────────────────────────────────────────────────────────────

REPO_URL="https://github.com/4ngel2769/os-configs.git"
REPO_DIR="os-configs"

# ── Colors ───────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

msg_info()  { printf "${CYAN}[i]${NC} %s\n" "$*"; }
msg_ok()    { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
msg_warn()  { printf "${YELLOW}[⚠]${NC} %s\n" "$*"; }
msg_error() { printf "${RED}[✗]${NC} %s\n" "$*"; }

# ── Banner ───────────────────────────────────────────────────
print_banner() {
    printf "\n"
    printf "${BOLD}${CYAN}"
    printf "  ┌─────────────────────────────────────┐\n"
    printf "  │         os-configs  v1.0             │\n"
    printf "  │   System Restore & Dotfile Manager   │\n"
    printf "  │   github.com/4ngel2769/os-configs    │\n"
    printf "  └─────────────────────────────────────┘\n"
    printf "${NC}\n"
}

# ── Detect if running via curl pipe ──────────────────────────
ensure_repo() {
    # If we're being piped from curl, BASH_SOURCE[0] will be empty or /dev/stdin
    local script_source="${BASH_SOURCE[0]:-}"

    if [[ -z "$script_source" || "$script_source" == "/dev/stdin" || "$script_source" == "-" ]]; then
        msg_info "Running via curl pipe — need to clone the repo first"

        # Check if repo already exists
        if [[ -d "$HOME/$REPO_DIR/.git" ]]; then
            msg_ok "Repo already exists at $HOME/$REPO_DIR — pulling latest"
            git -C "$HOME/$REPO_DIR" pull --ff-only || true
        elif [[ -d "./$REPO_DIR/.git" ]]; then
            msg_ok "Repo already exists at ./$REPO_DIR — pulling latest"
            git -C "./$REPO_DIR" pull --ff-only || true
            REPO_DIR="./$REPO_DIR"
            cd "$REPO_DIR"
            return
        else
            msg_info "Cloning $REPO_URL to $HOME/$REPO_DIR ..."
            if ! command -v git &>/dev/null; then
                msg_error "git is not installed. Please install git first."
                exit 1
            fi
            git clone "$REPO_URL" "$HOME/$REPO_DIR"
        fi

        cd "$HOME/$REPO_DIR"
    else
        # Running from a local file — find the repo root
        local script_dir
        script_dir="$(cd "$(dirname "$script_source")" && pwd)"
        cd "$script_dir"
    fi
}

# ── Detect OS ────────────────────────────────────────────────
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        msg_error "Cannot detect OS — /etc/os-release not found"
        exit 1
    fi

    # shellcheck source=/dev/null
    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_NAME="${NAME:-Unknown OS}"
    OS_VERSION="${VERSION_ID:-unknown}"
}

# ── Map OS to profile ───────────────────────────────────────
map_profile() {
    case "$OS_ID" in
        fedora)
            PROFILE_NAME="fedora-workstation"
            PROFILE_DIR="fedora-workstation"
            ;;
        ubuntu)
            PROFILE_NAME="ubuntu-server"
            PROFILE_DIR="ubuntu-server"
            ;;
        debian)
            PROFILE_NAME="debian-desktop"
            PROFILE_DIR="debian-desktop"
            ;;
        arch)
            PROFILE_NAME="arch-desktop"
            PROFILE_DIR="arch-desktop"
            ;;
        *)
            msg_error "Unsupported OS: $OS_ID ($OS_NAME)"
            msg_error "Supported: fedora, ubuntu, debian, arch"
            exit 1
            ;;
    esac
}

# ── Main ─────────────────────────────────────────────────────
main() {
    print_banner
    ensure_repo
    detect_os
    map_profile

    printf "${BOLD}  Detected OS:${NC}       %s %s\n" "$OS_NAME" "$OS_VERSION"
    printf "${BOLD}  Selected profile:${NC}  %s\n" "$PROFILE_NAME"
    printf "${BOLD}  Profile path:${NC}      %s\n\n" "$PROFILE_DIR/"

    if [[ ! -f "$PROFILE_DIR/bootstrap.sh" ]]; then
        msg_error "Bootstrap script not found: $PROFILE_DIR/bootstrap.sh"
        exit 1
    fi

    msg_info "Launching $PROFILE_NAME bootstrap..."
    printf "\n"

    bash "$PROFILE_DIR/bootstrap.sh" "$@"
}

main "$@"
