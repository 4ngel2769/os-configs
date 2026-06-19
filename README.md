# os-configs

System Restore & Dotfile Manager for my personal machines.

This repository holds automated bootstrap scripts, dotfiles, and system configurations for various Linux environments. It provides a single entry point to provision a fresh machine.

## Quick Start

You can bootstrap a fresh system directly from GitHub using `curl`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/4ngel2769/os-configs/main/setup.sh)
```

The script automatically detects the host operating system and routes to the corresponding profile's bootstrap script. Add `--auto` for non-interactive mode.

## Profiles

Current system profiles managed in this repository (see `index.yaml` for details):

* **Fedora Workstation** (`fedora-workstation`)
  * **Role**: Daily driver
  * **Environment**: GNOME, Ghostty terminal, full development stack
  * **Status**: Complete

* **Ubuntu Server** (`ubuntu-server`)
  * **Role**: Headless home server
  * **Environment**: Docker/Portainer stack with external storage
  * **Status**: In-Progress

* **Debian Desktop** / **Arch Desktop**
  * *Stubs for future environments*

## Structure

* `setup.sh`: Top-level dispatcher. Detects OS and calls the correct bootstrap.
* `fedora-workstation/`: Fedora-specific scripts, configurations, and dotfiles.
* `ubuntu-server/`: Ubuntu server-specific setup.
* `shared/`: Common configs and scripts shared across environments.
* `index.yaml`: Machine catalog and profile metadata.

## Maintenance

Maintained by [4ngel2769](https://github.com/4ngel2769/os-configs).
