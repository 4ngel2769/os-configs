# os-configs — minimal Bash rc

export LANG="${LANG:-en_US.UTF-8}"
[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

if command -v nvim &>/dev/null; then
    export EDITOR="nvim" VISUAL="nvim"
else
    export EDITOR="nano" VISUAL="nano"
fi

alias ll='ls -alFh' la='ls -A' l='ls -CF'
alias gs='git status' ga='git add' gc='git commit' gp='git push'
alias rm='rm -i' cp='cp -i' mv='mv -i'

[[ -f "${HOME}/.bashrc.local" ]] && source "${HOME}/.bashrc.local"
