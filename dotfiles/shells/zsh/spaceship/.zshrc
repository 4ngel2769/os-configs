# os-configs — Spaceship prompt
# Credit: spaceship-prompt/spaceship-prompt — https://github.com/spaceship-prompt/spaceship-prompt

export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="spaceship-prompt"

plugins=(
    git
    sudo
    zsh-autosuggestions
    zsh-syntax-highlighting
    history-substring-search
)

if [[ -d "$ZSH" ]]; then
    source "${ZSH}/oh-my-zsh.sh"
fi

export LANG="${LANG:-en_US.UTF-8}"
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
