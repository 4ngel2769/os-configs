# os-configs

Post-install setup for Linux. Run one command on a booted system — pick a preset or choose your own apps, DE/WM, display manager, and dotfiles. Calamares-style flow, without touching disks or bootloaders.

**Arch · Debian · Ubuntu · Fedora** (and common derivatives) · server / desktop / laptop

---

## Quick start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh)
```

Or clone the repo and run `./install.sh`. Use a normal user with `sudo` — not root. Over SSH, use **`ssh -t`** for the full interactive UI.

Bootstrap clones to `~/.os-configs`, checks missing dependencies, shows what it will install, then starts the installer.

---

## Options

| Flag | Effect |
|------|--------|
| `--dry-run` | Full flow, no system changes |
| `--auto` | Non-interactive; first preset for detected platform |
| `--ask-de-wm` | Always prompt for DE/WM and display manager |
| `--skip-dotfiles` | Skip dotfile backup and deploy |
| `--skip-postlogin` | Skip one-shot post-login service |
| `--skip-reboot` | Skip reboot prompt |

```bash
wget -qO- .../bootstrap.sh | bash -s -- --dry-run
```

| Variable | Purpose |
|----------|---------|
| `OS_CONFIGS_DIR` | Clone path (default `~/.os-configs`) |
| `OS_CONFIGS_REF` | Branch or tag (default `main`) |
| `OS_CONFIGS_ASK_DE_WM=1` | Same as `--ask-de-wm` |
| `OS_CONFIGS_FORCE_PLATFORM` | Override detection: `server`, `desktop`, `laptop` |

---

## Flow

1. **Detect** — distro, laptop/desktop/server, GPU class  
2. **Preset or custom** — curated bundles or pick from 600+ apps by category  
3. **Session** — DE/WM + display manager (preset defaults or your choice in custom mode)  
4. **Shell** — zsh, bash, or fish as default; optional themed config (Oh My Zsh, Powerlevel10k, Tide, Bash-it, …)  
5. **Confirm** — full package list with resolved names before install  
6. **Install** — pacman, apt, dnf, AUR, Flatpak, GitHub releases, third-party repos  
7. **Dotfiles** — backup conflicts to `~/.os-configs-backup/<timestamp>/`, then Stow  
8. **Finish** — optional reboot + one-time post-login “install more?” prompt  

**Presets:** server (minimal, clean, everything) · desktop/laptop (minimal, workstation, creator, gaming when GPU qualifies) · **custom** always available.

---

## Customization

Add apps or override packages: **[ADD-APPS.md](ADD-APPS.md)** · per-machine overlays in `data/user/` · validate with `./install.sh --validate-user`

---

## Out of scope

Post-install only — the OS must already be installed and bootable.

- Disk partitioning, encryption layout, mount planning  
- Bootloader install or repair  
- Live USB, installer ISO, or initramfs environments  
- Replacing Calamares, Anaconda, Ubiquity, archinstall, etc.  
- OEM / fleet imaging (`--auto` re-runs one profile; it does not image machines)  
- Dual-boot / Windows boot entry management  

A future custom ISO that runs a normal distro installer and launches os-configs on first boot may build on this — but ISO composition and live-session integration are separate work and not included today.

---

[4ngel2769](https://github.com/4ngel2769/os-configs)
