#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install Homebrew for Linux
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

echo "==> Installing Homebrew..."

if command -v brew &>/dev/null; then
    echo "[✓] Homebrew already installed: $(brew --version | head -1)"
else
    echo "[i] Installing Homebrew for Linux (non-interactive)..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo "[✓] Homebrew installed"

    # Add Homebrew to PATH for the current session
    if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        echo "[✓] Homebrew version: $(brew --version | head -1)"
    else
        echo "[⚠] Homebrew installed but not yet in PATH"
        echo "    Restart your shell or run:"
        echo '    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'
    fi
fi

echo "[✓] Homebrew setup complete"
