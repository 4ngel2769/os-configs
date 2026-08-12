# ─────────────────────────────────────────────────────────────
# os-configs — Fedora Workstation .zshrc
# https://github.com/4ngel2769/os-configs
#
# This file is stowed to ~/.zshrc and overrides the shared one.
# It sources the shared base first, then adds Fedora-specific config.
# ─────────────────────────────────────────────────────────────

# Source the shared base .zshrc
SHARED_ZSHRC="$HOME/os-configs/shared/dotfiles/zsh/.zshrc"
if [[ -f "$SHARED_ZSHRC" ]]; then
    source "$SHARED_ZSHRC"
else
    # Fallback: if shared zshrc isn't found at expected path, try common locations
    for candidate in \
        "$HOME/.local/share/os-configs/shared/dotfiles/zsh/.zshrc" \
        "$HOME/Documents/GitHub/os-configs/shared/dotfiles/zsh/.zshrc"; do
        if [[ -f "$candidate" ]]; then
            source "$candidate"
            break
        fi
    done
fi

# ── Fedora-specific overrides ────────────────────────────────

# Update alias: DNF + Flatpak
alias update='sudo dnf update -y && flatpak update -y'

# Fedora-specific aliases
alias dnfs='dnf search'
alias dnfi='sudo dnf install -y'
alias dnfr='sudo dnf remove -y'
alias dnfl='dnf list installed'

# ── Fedora-specific paths ────────────────────────────────────

# Ghostty (if installed to a custom location)
# [[ -d "/usr/local/bin" ]] && export PATH="/usr/local/bin:$PATH"

# ── Tokens & secrets ────────────────────────────────────────
# DO NOT put secrets in this file. Use ~/.zshrc.local instead.
# Example (add to ~/.zshrc.local):
#   export GITHUB_TOKEN="ghp_..."
#   export OPENAI_API_KEY="sk-..."

# ── Machine-local overrides (sourced again to ensure precedence) ──
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
