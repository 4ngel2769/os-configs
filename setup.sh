#!/usr/bin/env bash
set -euo pipefail

# os-configs — compatibility alias for old links and curl snippets.
# The only supported entrypoint is bootstrap.sh; delegating keeps one code path.

_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_bootstrap_url="${OS_CONFIGS_BOOTSTRAP_URL:-https://raw.githubusercontent.com/4ngel2769/os-configs/main/bootstrap.sh}"

if [[ -f "${_here}/bootstrap.sh" ]]; then
    exec bash "${_here}/bootstrap.sh" "$@"
fi

if command -v curl &>/dev/null; then
    curl -fsSL "$_bootstrap_url" | bash -s -- "$@"
elif command -v wget &>/dev/null; then
    wget -qO- "$_bootstrap_url" | bash -s -- "$@"
else
    echo "setup: curl or wget is required to fetch bootstrap.sh" >&2
    exit 1
fi
