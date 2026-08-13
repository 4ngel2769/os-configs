# os-configs

Post-install setup for Linux — pick a preset or choose your own software, DE/WM, display manager, and dotfiles. One command on an already-booted system (not live media, not disk partitioning).

## Quick start

```bash
# wget
wget -qO- https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh | bash

# curl
bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh)
```

`bootstrap.sh` installs `git` if needed, clones or updates **`~/.os-configs`**, then runs `install.sh`.

### Options

```bash
# preview everything, change nothing
wget -qO- .../bootstrap.sh | bash -s -- --dry-run

# non-interactive (first preset for detected platform)
wget -qO- .../bootstrap.sh | bash -s -- --auto

# pick DE/WM and display manager interactively
wget -qO- .../bootstrap.sh | bash -s -- --ask-de-wm
```

Use **`ssh -t`** for the full Custom software picker (Bubble Tea sidebar + grid).

### Environment

| Variable | Purpose |
|----------|---------|
| `OS_CONFIGS_DIR` | Checkout path (default `~/.os-configs`) |
| `OS_CONFIGS_REF` | Git branch or tag (default `main`) |
| `OS_CONFIGS_ASK_DE_WM=1` | Same as `--ask-de-wm` |

## What it does

1. **Detect** — distro family (Arch / Debian / Ubuntu / Fedora), laptop vs desktop vs server, GPU class
2. **Preset or Custom** — curated bundles or pick apps by category (600+ in catalog)
3. **DE / WM / DM** — defaults from preset, or choose GNOME, KDE, Hyprland, i3, etc.
4. **Confirm** — shows real package names before installing
5. **Install** — native packages, AUR, third-party repos, Flatpak, GitHub releases
6. **Dotfiles** — backs up existing configs to `~/.os-configs-backup/<timestamp>/`, then Stow deploy
7. **Finish** — reboot prompt + one-shot post-login “install more?” (runs once, then removes itself)

## Presets

| Platform | Presets |
|----------|---------|
| **Server** | Minimal, Clean, Everything |
| **Desktop** | Minimal, Workstation, Creator, Gaming (if GPU qualifies) |
| **Laptop** | Minimal, Workstation, Creator, Gaming (if GPU qualifies) |

**Custom** is always available — walk categories or use the visual picker.

## Supported distros

Logic branches on **`DISTRO_FAMILY`**: `arch`, `debian`, `ubuntu`, `fedora`. Derivatives (Zorin, Mint, EndeavourOS, etc.) map to their base family automatically.

## Adding apps

See [ADD-APPS.md](ADD-APPS.md). User overlays go in `data/user/` (gitignored).

## Repo layout

```
bootstrap.sh          # wget/curl entry
install.sh            # main installer
lib/                  # detect, UI, registry, install, dotfiles, post-login
data/
  registry.json       # base app → package map
  catalog/            # Arco catalog + extras (merged automatically)
  presets/            # preset definitions
  categories.json     # custom-mode categories
  de-wm.json          # DE/WM + default DM + dotfiles package
dotfiles/             # Stow packages (shared + per-DE/WM)
test/                 # checkpoint scripts
```

## Checkpoints

```bash
./install.sh --dry-run --auto
bash test/phase4-checkpoint.sh    # preset registry coverage
bash test/extras-checkpoint.sh    # extras package map
bash test/live-checkpoint.sh      # dotfiles backup + post-login once-only
bash test/run-in-container.sh all # cross-distro registry validation
```

## Out of scope

- Disk partitioning, bootloaders, live ISO
- Fleet / unattended imaging (use `--auto` to re-run a known profile, not to image machines)

Maintained by [4ngel2769](https://github.com/4ngel2769/os-configs).
