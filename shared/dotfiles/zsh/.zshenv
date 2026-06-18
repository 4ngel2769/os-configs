# ─────────────────────────────────────────────────────────────
# os-configs — shared .zshenv
# Sourced by zsh on every invocation (login, interactive, script)
# Keep this lightweight — only truly global env vars belong here
# ─────────────────────────────────────────────────────────────

# XDG Base Directory Specification
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

# Ensure ~/.local/bin is in PATH for scripts and tools
typeset -U PATH
export PATH="$HOME/.local/bin:$PATH"
