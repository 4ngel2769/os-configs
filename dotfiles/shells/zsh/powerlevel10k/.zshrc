# os-configs — Powerlevel10k
# Credit: romkatv/powerlevel10k — https://github.com/romkatv/powerlevel10k

export ZSH="${HOME}/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

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

[[ -f "${HOME}/.p10k.zsh" ]] && source "${HOME}/.p10k.zsh"

export LANG="${LANG:-en_US.UTF-8}"
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

[[ -f "${HOME}/.zshrc.local" ]] && source "${HOME}/.zshrc.local"
