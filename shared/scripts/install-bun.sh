#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install bun
# https://github.com/4ngel2769/os-configs
# ─────────────────────────────────────────────────────────────

echo "==> Installing bun..."

if command -v bun &>/dev/null; then
    echo "[✓] bun already installed: $(bun --version)"
else
    echo "[i] Installing bun via official script..."
    curl -fsSL https://bun.sh/install | bash
    echo "[✓] bun installed"

    # Make bun available in current shell
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"

    if command -v bun &>/dev/null; then
        echo "[✓] bun version: $(bun --version)"
    else
        echo "[⚠] bun installed but not in current PATH"
        echo "    Restart your shell to use bun"
    fi
fi

echo "[✓] bun setup complete"
