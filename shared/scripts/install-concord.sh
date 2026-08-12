#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────
# os-configs — Install Concord (Discord TUI)
# https://github.com/chojs23/concord
# ─────────────────────────────────────────────────────────────

echo "==> Installing Concord..."

if command -v concord &>/dev/null; then
    echo "[✓] Concord already installed: $(concord --version 2>/dev/null || echo 'unknown version')"
    exit 0
fi

echo "[i] Installing Concord via official release installer..."
curl --proto '=https' --tlsv1.2 -LsSf \
    https://github.com/chojs23/concord/releases/latest/download/concord-installer.sh | sh

if command -v concord &>/dev/null; then
    echo "[✓] Concord installed: $(concord --version 2>/dev/null || echo 'ok')"
else
    echo "[⚠] Concord installer finished but 'concord' is not in PATH"
    echo "    Restart your shell or add \$CARGO_HOME/bin to PATH"
fi

echo "[✓] Concord setup complete"
