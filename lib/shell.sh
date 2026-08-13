#!/usr/bin/env bash
set -euo pipefail

_shell_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_shell_repo="${REPO_ROOT:-$(cd "${_shell_lib_dir}/.." && pwd)}"
_shell_config="${_shell_repo}/data/config.json"
_shells_file="${_shell_repo}/data/shells.json"
_shell_profiles_file="${_shell_repo}/data/shell-profiles.json"

SELECTED_SHELL=""
SELECTED_SHELL_PROFILE=""
SHELL_APPLY_DOTFILES="false"
SELECTED_SHELL_STOW=""

shell_label() {
    jq -r --arg id "$1" '.shells[] | select(.id == $id) | .label' "$_shells_file"
}

shell_profile_field() {
    local profile="$1"
    local field="$2"
    jq -r --arg id "$profile" --arg f "$field" '.profiles[$id][$f] // empty' "$_shell_profiles_file"
}

shell_profile_label() {
    shell_profile_field "$1" "label"
}

shell_list_profile_choices() {
    local shell_id="$1"
    jq -r --arg sh "$shell_id" '
        [.profiles | to_entries[]
         | select(.value.shell == $sh)
         | "\(.value.label) — \(.value.description) [\(.value.credit)]"
        ] | .[]
    ' "$_shell_profiles_file"
}

shell_profile_id_from_choice() {
    local shell_id="$1"
    local choice="$2"
    local label="${choice%% — *}"
    jq -r --arg sh "$shell_id" --arg lbl "$label" '
        .profiles | to_entries[]
        | select(.value.shell == $sh and .value.label == $lbl)
        | .key
    ' "$_shell_profiles_file" | head -1
}

shell_pick_interactive() {
    local items_json choice picked_label i
    local -a ids=()

    items_json="$(jq -c '[.shells[] | {id: .id, label: .label, subtitle: .tagline}]' "$_shells_file")"

    if choice="$(ui_picker_menu_list "Choose your shell" "Installed if needed and set as your default login shell" "$items_json")"; then
        SELECTED_SHELL="$choice"
        export SELECTED_SHELL
        return 0
    fi

    local -a options=() line
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        ids+=("$(jq -r '.id' <<<"$line")")
        options+=("$(jq -r '.label' <<<"$line") — $(jq -r '.tagline' <<<"$line")")
    done < <(jq -c '.shells[]' "$_shells_file")

    ui_style_header "Choose your shell"
    ui_style_subheader "This will be installed (if needed) and set as your default login shell"

    choice="$(gum choose "${options[@]}")"
    picked_label="${choice%% — *}"

    for i in "${!ids[@]}"; do
        if [[ "$(shell_label "${ids[$i]}")" == "$picked_label" ]]; then
            SELECTED_SHELL="${ids[$i]}"
            export SELECTED_SHELL
            return 0
        fi
    done

    echo "shell: could not resolve shell choice" >&2
    return 1
}

shell_pick_profile_interactive() {
    local shell_id="$1"
    local items_json choice profile credit credit_url desc body

    items_json="$(jq -c --arg sh "$shell_id" '
        [.profiles | to_entries[]
         | select(.value.shell == $sh)
         | {id: .key, label: .value.label, subtitle: .value.description}
        ]' "$_shell_profiles_file")"

    if choice="$(ui_picker_menu_list "Shell configuration" "Themes, plugins, and rc files" "$items_json")"; then
        profile="$choice"
    else
        local -a options=()
        local picked
        mapfile -t options < <(shell_list_profile_choices "$shell_id")
        if [[ ${#options[@]} -eq 0 ]]; then
            echo "shell: no profiles for ${shell_id}" >&2
            return 1
        fi

        ui_style_header "Shell configuration"
        ui_style_subheader "Themes, plugins, and rc files — credits shown in each option"
        picked="$(gum choose "${options[@]}")"
        profile="$(shell_profile_id_from_choice "$shell_id" "$picked")"
    fi

    if [[ -z "$profile" ]]; then
        echo "shell: could not resolve profile" >&2
        return 1
    fi

    SELECTED_SHELL_PROFILE="$profile"
    credit="$(shell_profile_field "$profile" "credit")"
    credit_url="$(shell_profile_field "$profile" "credit_url")"
    desc="$(shell_profile_field "$profile" "description")"
    body="${desc}"$'\n\n'"Credit: ${credit}"$'\n'"${credit_url}"

    if ! ui_picker_menu_info "Configuration credit" "$body"; then
        ui_panel "Configuration credit" "$body"
    fi

    export SELECTED_SHELL_PROFILE
}

shell_apply_selection() {
    local shell_id="$1"
    local profile="$2"
    local apply_dotfiles="$3"

    SELECTED_SHELL="$shell_id"
    SELECTED_SHELL_PROFILE="$profile"
    SHELL_APPLY_DOTFILES="$apply_dotfiles"
    SELECTED_SHELL_STOW=""

    if [[ "$apply_dotfiles" == "true" && -n "$profile" ]]; then
        SELECTED_SHELL_STOW="$(shell_profile_field "$profile" "stow")"
    fi

    export SELECTED_SHELL SELECTED_SHELL_PROFILE SHELL_APPLY_DOTFILES SELECTED_SHELL_STOW
}

shell_apply_defaults() {
    local shell_id profile apply

    shell_id="$(jq -r '.shell_defaults.shell // "zsh"' "$_shell_config")"
    profile="$(jq -r '.shell_defaults.profile // empty' "$_shell_config")"
    apply="$(jq -r '.shell_defaults.apply_dotfiles // true' "$_shell_config")"

    shell_apply_selection "$shell_id" "$profile" "$apply"
}

shell_resolve() {
    local auto="${1:-false}"

    SELECTED_SHELL=""
    SELECTED_SHELL_PROFILE=""
    SHELL_APPLY_DOTFILES="false"
    SELECTED_SHELL_STOW=""
    export SELECTED_SHELL SELECTED_SHELL_PROFILE SHELL_APPLY_DOTFILES SELECTED_SHELL_STOW

    if [[ "$auto" == "true" ]]; then
        shell_apply_defaults
        ui_style_subheader "(auto) shell: $(shell_label "$SELECTED_SHELL")$( [[ "$SHELL_APPLY_DOTFILES" == "true" ]] && printf ', %s' "$(shell_profile_label "$SELECTED_SHELL_PROFILE")" )"
        return 0
    fi

    shell_pick_interactive
    if ui_picker_menu_confirm \
        "$(tui_str shell_confirm_message "Apply a custom shell configuration (themes, plugins, rc file)?")" \
        true \
        "$(tui_str shell_confirm_title "Shell configuration")"; then
        shell_pick_profile_interactive "$SELECTED_SHELL"
        shell_apply_selection "$SELECTED_SHELL" "$SELECTED_SHELL_PROFILE" "true"
    else
        shell_apply_selection "$SELECTED_SHELL" "" "false"
        ui_style_subheader "Shell config skipped — only install and set default"
    fi
}

shell_show_summary() {
    [[ -n "$SELECTED_SHELL" ]] || return 0
    ui_style_centered "Shell:      $(shell_label "$SELECTED_SHELL") (default)"
    if [[ "$SHELL_APPLY_DOTFILES" == "true" && -n "$SELECTED_SHELL_PROFILE" ]]; then
        ui_style_centered "Shell cfg:  $(shell_profile_label "$SELECTED_SHELL_PROFILE")"
        ui_style_centered "            $(shell_profile_field "$SELECTED_SHELL_PROFILE" "credit")"
    fi
}

shell_registry_app() {
    jq -r --arg id "$1" '.shells[] | select(.id == $id) | .registry_app // empty' "$_shells_file"
}

shell_set_default() {
    local shell_id="$1"
    local dry_run="${2:-false}"
    bin="$(command -v "$shell_id" 2>/dev/null || true)"

    if [[ "$dry_run" == "true" ]]; then
        [[ -n "$bin" ]] || bin="/usr/bin/${shell_id}"
        echo "[dry-run] would run: chsh -s ${bin}"
        return 0
    fi

    if [[ -z "$bin" ]]; then
        echo "shell: ${shell_id} not in PATH after install" >&2
        return 1
    fi

    current="$(getent passwd "$(whoami)" | cut -d: -f7)"
    if [[ "$current" == "$bin" ]]; then
        return 0
    fi

    if ! grep -Fxq "$bin" /etc/shells 2>/dev/null; then
        if command -v sudo &>/dev/null; then
            if ! echo "$bin" | sudo tee -a /etc/shells >/dev/null; then
                echo "shell: could not add ${bin} to /etc/shells" >&2
                return 1
            fi
        else
            echo "shell: ${bin} not in /etc/shells — add it manually, then: chsh -s ${bin}" >&2
            return 1
        fi
    fi

    if chsh -s "$bin" 2>/dev/null; then
        return 0
    fi

    if command -v sudo &>/dev/null; then
        if sudo usermod -s "$bin" "$USER" 2>/dev/null || sudo chsh -s "$bin" "$USER" 2>/dev/null; then
            return 0
        fi
    fi

    echo "shell: chsh failed — run manually: chsh -s ${bin}" >&2
    return 1
}

shell_setup_oh_my_zsh() {
    local dry_run="${1:-false}"
    local zsh_dir="${HOME}/.oh-my-zsh"
    local custom="${ZSH_CUSTOM:-${zsh_dir}/custom}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would install Oh My Zsh to ${zsh_dir}"
        return 0
    fi

    if [[ ! -d "$zsh_dir" ]]; then
        RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    _shell_clone_plugin() {
        local name="$1" url="$2" dest="${custom}/plugins/${1}"
        [[ -d "$dest" ]] || git clone --depth=1 "$url" "$dest"
    }

    _shell_clone_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
    _shell_clone_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"
    _shell_clone_plugin "zsh-history-substring-search" "https://github.com/zsh-users/zsh-history-substring-search.git"
}

shell_setup_zsh_extra() {
    local extra="$1"
    local dry_run="${2:-false}"
    local custom="${ZSH_CUSTOM:-${HOME}/.oh-my-zsh/custom}"

    case "$extra" in
        powerlevel10k)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] would clone powerlevel10k to ${custom}/themes/powerlevel10k"
                return 0
            fi
            [[ -d "${custom}/themes/powerlevel10k" ]] || \
                git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${custom}/themes/powerlevel10k"
            ;;
        spaceship)
            if [[ "$dry_run" == "true" ]]; then
                echo "[dry-run] would clone spaceship-prompt to ${custom}/themes/spaceship-prompt"
                return 0
            fi
            [[ -d "${custom}/themes/spaceship-prompt" ]] || \
                git clone --depth=1 https://github.com/spaceship-prompt/spaceship-prompt.git "${custom}/themes/spaceship-prompt"
            ;;
    esac
}

shell_setup_oh_my_fish() {
    local dry_run="${1:-false}"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would install Oh My Fish"
        return 0
    fi

    if [[ ! -d "${HOME}/.local/share/omf" ]]; then
        fish -c 'curl -fsSL https://raw.githubusercontent.com/oh-my-fish/oh-my-fish/master/bin/install | source'
    fi
}

shell_setup_omf_theme() {
    local theme="$1"
    local dry_run="${2:-false}"
    local url=""

    case "$theme" in
        tide) url="https://github.com/IlanCosman/tide" ;;
        bobthefish) url="https://github.com/bobthefish/bobthefish" ;;
        *) url="$theme" ;;
    esac

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would install OMF theme: ${url}"
        return 0
    fi

    fish -c "omf install ${url}" 2>/dev/null || fish -c "omf install ${theme}" 2>/dev/null || true
}

shell_setup_bash_it() {
    local dry_run="${1:-false}"
    local dir="${HOME}/.bash_it"

    if [[ "$dry_run" == "true" ]]; then
        echo "[dry-run] would install Bash-it to ${dir}"
        return 0
    fi

    if [[ ! -d "$dir" ]]; then
        git clone --depth=1 https://github.com/Bash-it/bash-it.git "$dir"
        "$dir/install.sh" --no-modify-config --append-to-config-file >/dev/null 2>&1 || true
    fi
}

shell_run_profile_setup() {
    local profile="$1"
    local dry_run="${2:-false}"
    local setup extra

    [[ -n "$profile" ]] || return 0
    setup="$(shell_profile_field "$profile" "setup")"
    extra="$(shell_profile_field "$profile" "setup_extra")"

    case "$setup" in
        oh-my-zsh)
            ui_spin "Setting up Oh My Zsh..." shell_setup_oh_my_zsh "$dry_run"
            [[ -n "$extra" ]] && ui_spin "Installing ${extra}..." shell_setup_zsh_extra "$extra" "$dry_run"
            ;;
        oh-my-fish)
            ui_spin "Setting up Oh My Fish..." shell_setup_oh_my_fish "$dry_run"
            if [[ -n "$extra" ]]; then
                case "$extra" in
                    tide) ui_spin "Installing Tide..." shell_setup_omf_theme "tide" "$dry_run" ;;
                    bobthefish) ui_spin "Installing bobthefish..." shell_setup_omf_theme "bobthefish" "$dry_run" ;;
                esac
            fi
            ;;
        bash-it)
            ui_spin "Setting up Bash-it..." shell_setup_bash_it "$dry_run"
            ;;
        none | "") ;;
        *)
            echo "shell: unknown setup hook: ${setup}" >&2
            ;;
    esac
}

shell_apply() {
    local dry_run="${1:-false}"
    local auto="${2:-false}"
    local app

    [[ -n "$SELECTED_SHELL" ]] || return 0

    app="$(shell_registry_app "$SELECTED_SHELL")"
    if [[ -n "$app" ]]; then
        install_app "$app" "$dry_run" || true
    fi

    if jq -e --arg id "$SELECTED_SHELL" '.shells[] | select(.id == $id) | .set_default' "$_shells_file" | grep -q true; then
        shell_set_default "$SELECTED_SHELL" "$dry_run" || true
    fi

    if [[ "$SHELL_APPLY_DOTFILES" == "true" && -n "$SELECTED_SHELL_PROFILE" ]]; then
        shell_run_profile_setup "$SELECTED_SHELL_PROFILE" "$dry_run"
    fi
}
