#!/usr/bin/env bash
set -euo pipefail

# Build bundled picker binaries for linux amd64/arm64.
# Requires Go on the build machine — not needed on install targets.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${ROOT}/bin"
VERSION="${1:-dev}"

if ! command -v go &>/dev/null; then
    echo "build.sh: go is required (https://go.dev/dl/)" >&2
    exit 1
fi

mkdir -p "${OUT}/linux-amd64" "${OUT}/linux-arm64"

echo "[build] tidying modules..."
(cd "$ROOT" && go mod tidy)

build_one() {
    local goarch="$1"
    local dest="${OUT}/linux-${goarch}/os-configs-picker"

    echo "[build] linux/${goarch} → ${dest}"
    GOOS=linux GOARCH="$goarch" CGO_ENABLED=0 \
        go build -trimpath -ldflags "-s -w" -o "$dest" "$ROOT"
    chmod +x "$dest"
}

build_one amd64
build_one arm64

echo "[build] done (version=${VERSION})"
echo "[build] bump PICKER_VERSION in lib/deps.sh when shipping a new binary"
