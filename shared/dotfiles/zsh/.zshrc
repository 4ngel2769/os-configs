# ─────────────────────────────────────────────────────────────
# os-configs — shared base .zshrc
# https://github.com/4ngel2769/os-configs
#
# This file is managed by GNU Stow. Machine-specific overrides
# go in ~/.zshrc.local (which is sourced at the end).
# ─────────────────────────────────────────────────────────────

# ── Oh My Zsh ────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

plugins=(
    git
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    history-substring-search
    colored-man-pages
    command-not-found
)

# Only source OMZ if it's installed
if [[ -d "$ZSH" ]]; then
    source "$ZSH/oh-my-zsh.sh"
fi

# ── Environment ──────────────────────────────────────────────
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# Editor: prefer nvim, fall back to nano
if command -v nvim &>/dev/null; then
    export EDITOR="nvim"
    export VISUAL="nvim"
else
    export EDITOR="nano"
    export VISUAL="nano"
fi

# ── PATH ─────────────────────────────────────────────────────
# Local binaries
[[ -d "$HOME/.local/bin" ]] && export PATH="$HOME/.local/bin:$PATH"

# Homebrew (Linux)
if [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ── nvm ──────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
fi
if [[ -s "$NVM_DIR/bash_completion" ]]; then
    source "$NVM_DIR/bash_completion"
fi

# ── bun ──────────────────────────────────────────────────────
if [[ -d "$HOME/.bun" ]]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    # bun completions
    if [[ -s "$BUN_INSTALL/_bun" ]]; then
        source "$BUN_INSTALL/_bun"
    fi
fi

# ── Aliases ──────────────────────────────────────────────────
alias ll='ls -alFh'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias update='sudo dnf update -y'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -20'

# Safety nets
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# ── Machine-local overrides ──────────────────────────────────
# Create ~/.zshrc.local for machine-specific settings, secrets, tokens, etc.
if [[ -f "$HOME/.zshrc.local" ]]; then
    source "$HOME/.zshrc.local"
fi
