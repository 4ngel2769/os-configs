#!/usr/bin/env bash
set -euo pipefail

# Require a normal user with sudo — never run the installer as root.
os_configs_require_sudo() {
    local uid

    uid="${EUID:-$(id -u)}"
    if [[ "$uid" -eq 0 ]]; then
        echo "os-configs: do not run as root." >&2
        echo "os-configs: run as your normal user; you will be prompted for sudo when needed." >&2
        exit 1
    fi

    if ! command -v sudo &>/dev/null; then
        echo "os-configs: sudo is required for package installation but was not found." >&2
        exit 1
    fi

    echo "os-configs: sudo is required to install packages. Enter your password when prompted." >&2
    if ! sudo -v; then
        echo "os-configs: sudo authentication failed." >&2
        exit 1
    fi
}
