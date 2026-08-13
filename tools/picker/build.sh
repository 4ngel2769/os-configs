#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

mkdir -p bin/linux-amd64 bin/linux-arm64

for pair in amd64:linux-amd64 arm64:linux-arm64; do
    arch="${pair%%:*}"
    outdir="${pair##*:}"
    GOOS=linux GOARCH="$arch" go build -trimpath -ldflags "-s -w" -o "${outdir}/os-configs-picker" .
done
