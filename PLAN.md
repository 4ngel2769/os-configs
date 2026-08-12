# PLAN.md — os-configs → post-install installer

Goal: turn `os-configs` into a Calamares-style setup installer. Run one
command on a fresh Arch / Debian-family / Ubuntu-family / Fedora box. It
detects the system (server vs desktop vs laptop, GPU class), offers a
**preset or custom** choice, installs software + DE/WM + display manager,
migrates the right dotfiles, and finishes with a reboot and a one-time
post-login prompt for anything extra.

Read `AGENTS.md` first — it governs *how* you work through this. This file
governs *what*, in what order.

Each phase ends with a **checkpoint**: a concrete thing to run and show me.
Do not start the next phase until I've responded to the checkpoint. If a
phase is trivially small, say so and ask whether to fold it into the next
one rather than assuming.

---

## Shape of the finished thing (read before Phase 0)

```
install.sh                    # entrypoint: detect -> preset/custom -> confirm -> apply -> reboot prompt
lib/
  detect.sh                    # distro family, pkg manager, platform class, GPU class
  ui.sh                        # gum wrappers: menu, confirm, spin, style, colored distro labels
  registry.sh                  # simple-name -> real package lookup, per distro family
  install.sh                   # install_app() — the only thing that calls the pkg manager
  dotfiles.sh                  # backup existing configs, deploy the right Stow package(s)
  postlogin.sh                 # installs/removes the one-shot systemd --user service
  log.sh                       # run log + failure summary
data/
  registry.json                 # simple name -> {arch, debian, ubuntu, fedora} package spec
  presets/
    server-minimal.json
    server-clean.json
    server-everything.json
    desktop-minimal.json
    desktop-gaming.json
    desktop-workstation.json
    desktop-creator.json
    laptop-minimal.json
    laptop-gaming.json
    laptop-workstation.json
    laptop-creator.json
  categories.json               # custom-mode category -> app list (simple names)
  de-wm.json                    # available DE/WM options + their default DM + dotfile package name
dotfiles/                       # existing Stow packages, reorganized per-DE/WM (Phase 6)
test/
  run-in-container.sh
PLAN.md
AGENTS.md
README.md
```

Every preset, category list, and the package registry are **data**, not
bash. Bash reads `data/*.json` with `jq`. Adding an app to a preset later
means editing JSON, never touching a `.sh` file.

---

## Phase 0 — Repo shape + registry skeleton

1. Build the directory layout above (no logic yet).
2. Write `data/registry.json` with ~15 apps to prove the shape, covering
   at least one from each future category (e.g. `brave`, `discord`,
   `vscode`, `steam`, `vlc`, `btop`). Format:

```json
{
  "brave": {
    "arch": { "manager": "aur", "package": "brave-bin" },
    "debian": { "manager": "apt", "package": "brave-browser", "repo": "brave" },
    "ubuntu": { "manager": "apt", "package": "brave-browser", "repo": "brave" },
    "fedora": { "manager": "dnf", "package": "brave-browser", "repo": "brave" }
  }
}
```

`"repo"` is optional — only present when a third-party repo/key must be
added first. `lib/registry.sh` exposes `registry_lookup <simple-name>`,
returning manager + real package + repo-setup-needed, for the *currently
detected* distro family. If a simple name has no entry for the detected
family, that's a hard error surfaced to the user, not a silent skip.

3. Move existing Stow bootstrap logic into `dotfiles/` unchanged for now
   (real reorg happens in Phase 8 once DE/WM selection exists).

**Checkpoint:** show the tree, show `registry_lookup brave` resolving
correctly when you fake `DISTRO_FAMILY=fedora` and `DISTRO_FAMILY=arch`
by hand (no full detection yet — that's Phase 1).

---

## Phase 1 — Detection (`lib/detect.sh`)

Detect and export once, before any menu renders:

- `DISTRO_FAMILY` — `arch` / `debian` / `ubuntu` / `fedora`, via
  `/etc/os-release` `ID` + `ID_LIKE` fallback (derivatives map to base
  family, no per-derivative case list)
- `DISTRO_ID` — the exact `ID` (e.g. `zorin`, `parrot`) kept separately,
  for display purposes only (see Phase 2 colored labels) — never branched
  on for package logic, only `DISTRO_FAMILY` is
- `PKG_MANAGER` — `pacman` / `apt` / `dnf`; AUR helper detection for Arch
  (`paru` then `yay`; if neither present, ask the user once, don't guess
  which to install)
- `PLATFORM_CLASS` — `server` / `desktop` / `laptop`:
  - `laptop` if `/sys/class/power_supply/BAT*` exists
  - else `server` if no DE/WM detected AND no GPU beyond a basic framebuffer
    driver (see GPU_CLASS below) AND target-run flag wasn't forced desktop
  - else `desktop`
  - this is a heuristic — always show the detected class to the user and
    let them override it before anything installs (see Phase 3)
- `GPU_CLASS` — `none` / `igpu-basic` / `igpu-gaming` / `dgpu`:
  - `lspci` for a discrete GPU (NVIDIA/AMD/Intel Arc PCI class `03xx` not
    integrated into the CPU package) → `dgpu`
  - else check CPU model against the allowlist in `data/gaming-igpus.json`
    (780M, 890M, 8060S, Intel Arc-class iGPUs, etc.) → `igpu-gaming`
  - else if `glxinfo`/`vulkaninfo` available, probe for a real Vulkan
    device as fallback confirmation → `igpu-gaming` if it passes
  - else `igpu-basic`
  - `data/gaming-igpus.json` is a flat list of CPU model substrings —
    editable without touching bash, same pattern as the app registry
- `DE_WM` — best-effort existing session via `$XDG_CURRENT_DESKTOP` (fresh
  installs usually have none — that's expected and fine)
- `COMPOSITOR` — Wayland vs X11 via `$XDG_SESSION_TYPE`, if applicable
- `INIT_SYSTEM` — systemd vs other (needed for Phase 9's postlogin service)

**Checkpoint:** run `lib/detect.sh` standalone here on the Lenovo laptop,
show me every exported value including `GPU_CLASS`. We'll verify the
`igpu-gaming` allowlist path and the server heuristic against containers
in Phase 10, not now.

---

## Phase 2 — Core UI + colored distro labels (`lib/ui.sh`)

Gum wrappers, plus the preset-list rendering since that's the first thing
the user sees:

- `ui_menu` — `gum choose` wrapper, single or multi-select
- `ui_confirm` — `gum confirm`
- `ui_spin` — `gum spin` around a package-manager call
- `ui_style` — headers/dividers
- `ui_distro_badge` — prints the distro name in its brand color via
  `gum style --foreground`: Fedora blue, Debian's pinkish-red, Ubuntu
  orange, Arch cyan, and derivative names (Zorin, Kali, Mint, Pop!_OS,
  etc.) in their own distro's real brand color, not their base family's —
  confirm the hex/ANSI approximations with me before wiring this in,
  don't eyeball them

**Checkpoint:** a static demo screen — no real logic — showing the preset
list layout with 3 fake server presets and their distro badges, so we
agree on the look before Phase 3 wires it to real detection.

---

## Phase 3 — Preset vs Custom entry point

`install.sh` flow after detection:

1. Show `PLATFORM_CLASS` (and `GPU_CLASS` if desktop/laptop) with an
   explicit "this is what we detected, override?" step before the preset
   list renders — the heuristic in Phase 1 will occasionally be wrong
   (e.g. a headless desktop box) and the user needs an escape hatch here,
   not three menus deep.
2. Render presets filtered by platform class:
   - `server` → **Server Minimal**, **Server Clean**, **Server Everything**,
     each row showing the detected distro's badge from Phase 2
   - `desktop` → **Desktop Minimal (Pick your Desktop)**, **Desktop
     Workstation**, **Desktop Creator**, plus **Desktop Gaming (Pick your
     Desktop)** only if `GPU_CLASS` is `igpu-gaming` or `dgpu`
   - `laptop` → **Laptop Minimal (Light)**, **Laptop Workstation**,
     **Laptop Creator**, plus **Laptop Gaming** only if `GPU_CLASS` is
     `igpu-gaming` or `dgpu`
   - a **Custom** option always appears last regardless of class
3. Picking a preset loads `data/presets/<name>.json` (Phase 4 defines the
   shape) and skips to the confirmation summary (Phase 7).
4. Picking Custom enters the category flow (Phase 5).

**Checkpoint:** live run on this laptop — confirm it detects `laptop` +
`igpu-gaming` (Radeon 780M) correctly and shows Laptop Gaming as an option,
then walk the override path and force `desktop` to confirm the escape
hatch works.

---

## Phase 4 — Preset definitions

Each `data/presets/*.json` lists categories/apps by simple name, plus an
optional DE/WM + DM default (server presets omit these entirely):

```json
{
  "name": "Laptop Gaming",
  "platform_class": "laptop",
  "categories": {
    "developer": ["vscode", "git"],
    "gaming": ["steam", "proton-ge", "lutris"],
    "utilities": ["btop", "fzf", "ncdu"]
  },
  "de_wm_default": "gnome",
  "dm_default": "gdm",
  "laptop_tuning": true
}
```

`"laptop_tuning": true` is a flag `lib/dotfiles.sh` / a future
`modules`-equivalent reads later to pull in battery/power-profile configs
that desktop presets never request — keep this as a flag apps and configs
key off, not a separate copy of every laptop preset's app list.

Write all eleven presets (three server, four desktop, four laptop) plus
`server-everything` as the one preset allowed to be genuinely large — the
rest should stay closer to "sane default," not "everything available."

**Checkpoint:** show all eleven preset JSON files. We review app choices
per preset together before any of this installs anything — this is the
part most worth getting right before code depends on it.

---

## Phase 5 — Custom mode: category selection

`data/categories.json` defines the custom-mode menu:

```json
{
  "communication": { "label": "Communication", "apps": ["discord", "signal", "telegram"] },
  "browser": { "label": "Browser", "apps": ["brave", "firefox", "zen"] },
  "developer": { "label": "Developer", "apps": ["vscode", "opencode", "github-desktop", "git"] },
  "creator": { "label": "Creator", "apps": ["obs", "losslesscut", "openshot", "kdenlive"] },
  "gaming": { "label": "Gaming", "apps": ["steam", "proton-ge", "chess", "minecraft-launcher"] },
  "office": { "label": "Office", "apps": ["libreoffice", "onlyoffice"] },
  "media": { "label": "Media", "apps": ["vlc", "mpv", "gimp"] },
  "utilities": { "label": "Utilities", "apps": ["btop", "fzf", "rsync", "ncdu"] }
}
```

Custom flow: user walks each category as a `gum choose --no-limit`
multi-select screen (space to toggle, enter to move to the next category —
see AGENTS.md controls section), accumulating a selection list in the same
shape a preset's `"categories"` block would produce. Skipping a category
entirely is valid — don't force at least one pick per category.

**Checkpoint:** live run through all eight categories, show the
accumulated selection JSON matches what was picked.

---

## Phase 6 — DE/WM and Display Manager selection

Only runs for `desktop`/`laptop` (never `server`), and only if the chosen
preset/custom path didn't already fix a `de_wm_default`.

1. `data/de-wm.json` lists available options with metadata:

```json
{
  "gnome": { "label": "GNOME", "type": "de", "default_dm": "gdm", "dotfiles_pkg": "gnome" },
  "kde": { "label": "KDE Plasma", "type": "de", "default_dm": "sddm", "dotfiles_pkg": "kde" },
  "hyprland": { "label": "Hyprland", "type": "wm", "default_dm": "sddm", "dotfiles_pkg": "hyprland" },
  "i3": { "label": "i3", "type": "wm", "default_dm": "lightdm", "dotfiles_pkg": "i3" }
}
```

2. Menu splits DEs and WMs into two labeled groups (per your note: more
   proficient users reaching for i3-like WMs should find them without
   digging) — single-select, not multi.
3. After DE/WM choice, display manager menu defaults to that DE/WM's
   `default_dm` pre-highlighted, but every DM is still selectable — user
   can pair KDE with lightdm if they want, don't hard-lock the pairing.
4. Selection feeds Phase 7 (confirmation) and Phase 8 (dotfiles deploy).

**Checkpoint:** live run — pick Hyprland, confirm SDDM is pre-highlighted
but GDM/LightDM are still choosable, confirm the final selection is captured.

---

## Phase 7 — Confirmation summary + install

Before anything touches the system: render one summary screen — platform
class, distro, DE/WM, DM, and the full flattened app list resolved through
the registry (real package names, not simple names, so the user sees
exactly what installs) — then a single `ui_confirm`.

On confirm, `lib/install.sh` walks the flattened list, calling
`registry_lookup` per app and dispatching to the right manager. Same
guarantees as before: idempotent, one failure doesn't kill the run, failures
collected into a summary shown at the end alongside successes.

**Checkpoint:** dry-run (`--dry-run`) full walkthrough, preset path and
custom path both, showing the confirmation screen and the resulting
install plan without executing it.

---

## Phase 8 — Dotfiles: backup + deploy

`lib/dotfiles.sh`, run after package install, before the reboot prompt:

1. For the chosen `dotfiles_pkg` (from DE/WM selection), check for existing
   configs that Stow would overwrite (`~/.config/<relevant dirs>`, shell
   rc files, etc.).
2. If anything exists, back it up to `~/.os-configs-backup/<timestamp>/`
   preserving structure, *before* Stow runs — this is the safety net for
   "restore in case of failure" from your spec. Never silently overwrite.
3. Deploy via Stow as today.
4. If Stow itself fails partway, print the backup path prominently in the
   final summary so recovery is a `cp -r` away, not a mystery.

Reorganize `dotfiles/` into per-DE/WM Stow packages here if the current
layout doesn't already match `data/de-wm.json`'s `dotfiles_pkg` names —
this is the deferred piece from Phase 0.

**Checkpoint:** live run on this laptop against your real GNOME dotfiles —
confirm a backup directory gets created with the pre-existing configs
before Stow touches anything, and that a restore from that backup actually
works.

---

## Phase 9 — Reboot + post-login one-shot service

1. End-of-run screen: summary of what installed/failed, then `ui_confirm`
   for "reboot now?" — default yes, but allow deferring.
2. `lib/postlogin.sh` installs a `systemd --user` service triggered by
   `graphical-session.target` that on first login after reboot:
   - opens a `gum`-styled prompt: "Install additional software?"
   - if yes, re-enters the Phase 5 custom-category flow (reuse it, don't
     duplicate it)
   - either way, disables and removes itself after running once — confirm
     self-removal actually works before calling this phase done, a service
     that fires every login is a real regression, not a minor bug

**Checkpoint:** live end-to-end — reboot this machine, confirm the prompt
fires exactly once on next graphical login, confirm it's gone on the
login after that.

---

## Phase 10 — Cross-distro verification

Run the container matrix last, once the full flow is stable on this
laptop: `./test/run-in-container.sh <arch|debian|ubuntu|fedora>`,
`--dry-run --auto`, covering at least one server preset and one
desktop/laptop preset per family, confirming registry lookups resolve
for every app referenced by every preset — a preset shipping an app with
no registry entry for some distro family is the failure mode to catch
here specifically.

**Checkpoint:** matrix results, pass/fail per distro per preset. Real
go/no-go before calling the rewrite done.

---

## Explicitly out of scope (don't build unless I ask)

- Disk partitioning, bootloader config, anything that assumes live media
- A GUI (this is a TUI installer, not a Calamares clone in Qt)
- Auto-updating itself
- Telemetry of any kind
- Multi-user / unattended fleet provisioning (this is single-machine,
  interactive-first, `--auto` is for re-running a known profile, not for
  imaging fleets)
