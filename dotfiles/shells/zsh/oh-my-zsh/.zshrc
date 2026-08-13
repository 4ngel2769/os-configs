# os-configs — Oh My Zsh (robbyrussell)
# Credit: ohmyzsh/ohmyzsh — https://github.com/ohmyzsh/ohmyzsh

export ZSH="${HOME}/.oh-my-zsh"
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

if [[ -d "$ZSH" ]]; then
    source "${ZSH}/oh-my-zsh.sh"
fi

export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

if command -v nvim &>/dev/null; then
    export EDITOR="nvim" VISUAL="nvim"
else
    export EDITOR="nano" VISUAL="nano"
fi

[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

alias ll='ls -alFh' la='ls -A' l='ls -CF'
alias gs='git status' ga='git add' gc='git commit' gp='git push'

[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
