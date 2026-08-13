# os-configs — Oh My Fish base config
# Credit: oh-my-fish/oh-my-fish — https://github.com/oh-my-fish/oh-my-fish

if status is-interactive
    # Path and editor
    fish_add_path "$HOME/.local/bin"
    set -gx EDITOR (command -v nvim 2>/dev/null; or echo nano)

    # Common aliases
    alias ll 'ls -alFh'
    alias gs 'git status'
    alias ga 'git add'
    alias gc 'git commit'
end

if test -f "$HOME/.config/fish/config.local.fish"
    source "$HOME/.config/fish/config.local.fish"
end
