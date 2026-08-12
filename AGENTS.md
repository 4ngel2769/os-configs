# AGENTS.md

Read `PLAN.md` for build order. This file is landmines and rules the code
won't tell you — read it once, don't relearn these by breaking them.

## Non-obvious rules

- **`DISTRO_ID` is display-only.** Install/package logic always branches
  on `DISTRO_FAMILY`. `DISTRO_ID` (e.g. `zorin`) exists only for the
  colored badge.
  - Bad: `if [[ $DISTRO_ID == "zorin" ]]; then install_apt_package ...`
  - Good: registry entry keyed on `"ubuntu"`, badge color keyed on `DISTRO_ID`.
- **Real package names live only in `data/registry.json`.** Presets,
  categories, and lib code reference apps by simple name (`brave`), never
  the resolved package (`brave-browser`/`brave-bin`). If you're typing a
  real package name outside `registry.json`, stop.
- **Dotfiles backup is not skippable, including in `--auto`.** Every other
  confirmation can be bypassed non-interactively; the pre-Stow backup to
  `~/.os-configs-backup/<timestamp>/` cannot.
- **This installer never touches disks or bootloaders**, and never assumes
  live media — it only ever runs post-install, on an already-booted system.
  That boundary is intentional, not an oversight to "complete."
- **Nothing about my specific machines (`blade`, hostnames, IPs, my
  dotfiles paths) belongs in `lib/*.sh`.** If a choice is machine-specific,
  it's a preset or profile file, not a conditional in shared code.
- **Don't invent registry or GPU-allowlist entries.** If you're not sure a
  package exists on a distro, or a CPU actually has a gaming iGPU, say so
  instead of guessing an entry in.

## Stack

`gum`/`bubbletea`/`lipgloss` for all TUI — not `dialog`, `whiptail`, or a
hand-rolled `select` loop. `bash` + `set -euo pipefail`. `JSON` + `jq` for
everything in `data/` — no YAML mixed in.

## Commands

- `shellcheck lib/*.sh install.sh`
- `shfmt -d .`
- `jq empty data/**/*.json`
- `./install.sh --dry-run --auto`
- `./test/run-in-container.sh <arch|debian|ubuntu|fedora>` — Phase-end
  checkpoints only, not for a small change.

Run the first four before calling anything done.

## Working style

- One phase's worth of work per pass.
- Design forks: give a recommendation + trade-off in 2-3 sentences, don't
  silently pick one.
- PLAN.md checkpoints are real stops — finish, run the checkpoint, wait.
- Never run destructive commands against a real machine while testing —
  container, VM, or scratch user only.
  