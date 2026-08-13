# os-configs

**Post-install setup for Linux** — one guided flow to install software, configure your desktop session, and deploy dotfiles on a machine that is already installed and booted.

Think Calamares-style choices, but for day two: you finished the distro installer, logged in, and want a curated profile (or your own pick list) without hand-installing dozens of packages.

---

## Overview

os-configs detects your system, walks you through preset or custom software selection, applies DE/WM and display-manager defaults (or lets you choose), shows a full install plan, then executes it — including dotfile backup, Stow deploy, and an optional reboot with a one-time post-login prompt for extras.

| | |
|---|---|
| **Runs on** | Arch, Debian, Ubuntu, and Fedora (and common derivatives) |
| **Platform profiles** | Server, desktop, laptop |
| **Install methods** | Native packages, AUR, third-party repos, Flatpak, GitHub releases |
| **Interface** | Terminal UI (gum + Bubble Tea) — preset cards, custom software picker, confirmations |
| **Data-driven** | Presets, categories, and package names live in JSON — not hard-coded in shell |

---

## Requirements

- A **normal user account** with `sudo` (do not run the script as root).
- An **already-installed, booted** Linux system with network access.
- A terminal with reasonable size; use **`ssh -t`** for the full interactive pickers over SSH.
- Supported **`DISTRO_FAMILY`**: `arch`, `debian`, `ubuntu`, or `fedora`.

On first run, the installer audits missing tools (jq, gum, picker, curl, stow, etc.), shows what it will install, and asks for confirmation before fetching or using sudo.

---

## Quick start

### One-liner (recommended)

```bash
# curl
bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh)

# wget
wget -qO- https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh | bash
```

`bootstrap.sh` validates sudo, installs `git` if needed, clones or updates the repo to **`~/.os-configs`**, and runs `install.sh`.

### From a git clone

```bash
git clone https://github.com/4ngel2769/os-configs.git
cd os-configs
./install.sh
```

### Useful flags

```bash
# Walk the full UI but make no system changes
./install.sh --dry-run

# Non-interactive: keep detected platform, first matching preset
./install.sh --auto

# Always prompt for DE/WM and display manager
./install.sh --ask-de-wm

# Skip dotfiles, post-login service, or reboot prompt
./install.sh --skip-dotfiles --skip-postlogin --skip-reboot
```

Pass flags through bootstrap:

```bash
wget -qO- .../bootstrap.sh | bash -s -- --dry-run
```

### Environment

| Variable | Default | Purpose |
|----------|---------|---------|
| `OS_CONFIGS_DIR` | `~/.os-configs` | Where bootstrap clones the repo |
| `OS_CONFIGS_REF` | `main` | Git branch or tag to checkout |
| `OS_CONFIGS_REPO` | this repository | Override clone URL |
| `OS_CONFIGS_ASK_DE_WM` | — | Set to `1` to always prompt for session stack |
| `OS_CONFIGS_FORCE_PLATFORM` | — | Override detection: `server`, `desktop`, or `laptop` |

---

## What you get

### 1. Detection

Distro family and display name, laptop vs desktop vs server, GPU class (for gaming presets), and optional platform override.

### 2. Preset or custom

**Presets** are curated bundles per platform — minimal, workstation, creator, gaming (when GPU qualifies), and server variants.

**Custom** opens a category sidebar and app grid: pick exactly what you want from the merged catalog (600+ apps across base registry and extras).

### 3. Session stack

For desktop and laptop profiles: DE or WM plus display manager. Presets ship defaults; custom mode prompts you to choose. Override anytime with `--ask-de-wm`.

### 4. Confirmation

A summary lists distro, platform, GPU, mode, session stack, and every package with its **resolved** install target (e.g. `brave → apt:brave-browser`) before anything is installed.

### 5. Install and dotfiles

Packages install through a single registry-driven path. Dotfiles are **never** deployed without backing up conflicting files first to `~/.os-configs-backup/<timestamp>/`.

### 6. Finish

Optional reboot prompt and a one-shot post-login service that offers to install additional software once — then removes itself.

---

## Presets

| Platform | Available presets |
|----------|-------------------|
| **Server** | Minimal, Clean, Everything |
| **Desktop** | Minimal, Workstation, Creator, Gaming* |
| **Laptop** | Minimal, Workstation, Creator, Gaming* |

\*Gaming presets appear only when a qualifying GPU is detected.

**Custom** is always available alongside presets.

---

## Supported distributions

Install logic keys off **`DISTRO_FAMILY`**, not marketing names. Zorin, Linux Mint, Pop!\_OS, EndeavourOS, and similar derivatives map to their upstream family automatically. Colored distro badges in the UI are display-only.

| Family | Package manager |
|--------|-----------------|
| `arch` | pacman (+ AUR helper if present) |
| `debian` | apt |
| `ubuntu` | apt |
| `fedora` | dnf |

---

## Customizing the catalog

To add apps, extend presets, or override package names for your machines, see **[ADD-APPS.md](ADD-APPS.md)**.

Per-machine overlays belong in `data/user/` (gitignored by default). Validate with:

```bash
./install.sh --validate-user
```

---

## Out of scope

os-configs is a **post-install** tool. It assumes the OS is installed, partitioned, and bootable. The following are intentionally **not** handled today:

| Area | Notes |
|------|--------|
| **Disk partitioning** | No layout, resize, LUKS, or mount-point planning |
| **Bootloaders** | No GRUB/systemd-boot/refind install or repair |
| **Live / ISO environments** | Not designed to run from live USB, installer ISO, or initramfs |
| **OEM / fleet imaging** | No unattended mass deployment or golden-image tooling (`--auto` re-runs a known profile on one machine — it does not image fleets) |
| **Replacing distro installers** | Does not substitute Calamares, Anaconda, Ubiquity, or archinstall during initial OS setup |
| **Dual-boot configuration** | No Windows/macOS boot entry management |

**Future direction:** a custom ISO that runs a normal distro installer and then launches os-configs on first boot would build on this project — but that pipeline (ISO composition, live session, preseed/kickstart integration) is separate work and remains out of scope until explicitly added.

---

## Repository layout

```
bootstrap.sh              # curl/wget entrypoint
install.sh                # main installer
lib/                      # detection, UI, registry, install, dotfiles, flow
tools/picker/             # Bubble Tea pickers (presets + custom software)
data/
  registry.json           # app name → per-family package spec
  catalog/                # merged catalog (base + extras)
  presets/                # preset definitions
  categories.json         # custom-mode categories
  de-wm.json              # DE/WM options, default DM, dotfiles package
dotfiles/                 # GNU Stow packages (shared + per profile)
```

---

## For developers

```bash
# Syntax and formatting
shellcheck lib/*.sh install.sh
shfmt -d .
jq empty data/**/*.json

# Smoke the flow without changes
./install.sh --dry-run --auto

# Registry / preset validation
bash test/run-in-container.sh all
```

Rebuild the bundled picker after Go changes: `tools/picker/build.sh` (bump `PICKER_VERSION` in `lib/deps.sh`).

---

Maintained by [4ngel2769](https://github.com/4ngel2769/os-configs).
