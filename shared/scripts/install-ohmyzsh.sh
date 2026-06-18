#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install Oh My Zsh + plugins
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

echo "==> Installing Oh My Zsh..."

# ── Install Oh My Zsh ────────────────────────────────────────
if [[ -d "$ZSH_DIR" ]]; then
    echo "[✓] Oh My Zsh already installed at $ZSH_DIR"
else
    echo "[i] Installing Oh My Zsh (unattended)..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    echo "[✓] Oh My Zsh installed"
fi

# ── Install plugins ──────────────────────────────────────────
install_plugin() {
    local name="$1"
    local url="$2"
    local dest="$ZSH_CUSTOM/plugins/$name"

    if [[ -d "$dest" ]]; then
        echo "[✓] Plugin already installed: $name"
    else
        echo "[i] Cloning plugin: $name"
        git clone --depth=1 "$url" "$dest"
        echo "[✓] Installed: $name"
    fi
}

install_plugin "zsh-autosuggestions" \
    "https://github.com/zsh-users/zsh-autosuggestions.git"

install_plugin "zsh-syntax-highlighting" \
    "https://github.com/zsh-users/zsh-syntax-highlighting.git"

install_plugin "zsh-history-substring-search" \
    "https://github.com/zsh-users/zsh-history-substring-search.git"

# ── Set default shell to zsh ────────────────────────────────
ZSH_PATH="$(which zsh 2>/dev/null || true)"
if [[ -n "$ZSH_PATH" ]]; then
    CURRENT_SHELL="$(getent passwd "$(whoami)" | cut -d: -f7)"
    if [[ "$CURRENT_SHELL" != "$ZSH_PATH" ]]; then
        echo "[i] Changing default shell to zsh..."
        chsh -s "$ZSH_PATH" "$(whoami)" || {
            echo "[⚠] Could not change shell automatically."
            echo "    Run manually: chsh -s $ZSH_PATH"
        }
    else
        echo "[✓] Default shell is already zsh"
    fi
else
    echo "[⚠] zsh not found in PATH — install zsh first"
fi

echo "[✓] Oh My Zsh setup complete"
