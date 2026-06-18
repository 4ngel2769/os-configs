#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install nvm + Node.js LTS
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

NVM_DIR="${NVM_DIR:-$HOME/.nvm}"

echo "==> Installing nvm..."

if [[ -d "$NVM_DIR" ]]; then
    echo "[✓] nvm already installed at $NVM_DIR"
else
    echo "[i] Installing nvm via official script..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
    echo "[✓] nvm installed"
fi

# Source nvm in the current shell
export NVM_DIR
# shellcheck source=/dev/null
[[ -s "$NVM_DIR/nvm.sh" ]] && source "$NVM_DIR/nvm.sh"

# Install Node.js LTS
if command -v nvm &>/dev/null; then
    echo "[i] Installing Node.js LTS..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'
    echo "[✓] Node.js LTS installed: $(node --version)"
else
    echo "[⚠] nvm function not available in current shell"
    echo "    Restart your shell and run: nvm install --lts"
fi

echo "[✓] nvm setup complete"
