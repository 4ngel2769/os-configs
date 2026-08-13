# os-configs — bobthefish theme (requires: omf install bobthefish)
# Credit: bobthefish/bobthefish — https://github.com/bobthefish/bobthefish

if status is-interactive
    set -g theme_color_scheme dark
    fish_add_path "$HOME/.local/bin"
end

if test -f "$HOME/.config/fish/config.local.fish"
    source "$HOME/.config/fish/config.local.fish"
end
