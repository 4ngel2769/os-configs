# os-configs — Bash-it loader
# Credit: Bash-it/bash-it — https://github.com/Bash-it/bash-it

if [[ -f "${HOME}/.bash_it/bash_it.sh" ]]; then
    source "${HOME}/.bash_it/bash_it.sh"
fi

[[ -d "${HOME}/.local/bin" ]] && export PATH="${HOME}/.local/bin:${PATH}"

alias ll='ls -alFh' gs='git status' ga='git add' gc='git commit'

[[ -f "${HOME}/.bashrc.local" ]] && source "${HOME}/.bashrc.local"
