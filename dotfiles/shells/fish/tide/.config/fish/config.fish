# os-configs — Tide prompt (requires: omf install IlanCosman/tide)
# Credit: IlanCosman/tide — https://github.com/IlanCosman/tide

if status is-interactive
    fish_add_path "$HOME/.local/bin"
    set -gx EDITOR (command -v nvim 2>/dev/null; or echo nano)
end

if test -f "$HOME/.config/fish/config.local.fish"
    source "$HOME/.config/fish/config.local.fish"
end
