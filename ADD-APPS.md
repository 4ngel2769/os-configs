# Adding apps

Edit **`data/user/registry.json`** (copy from `registry.example.json`) and optionally **`data/user/categories.json`**.

Validate: `./install.sh --validate-user`

---

## 1. Package managers

Use a **simple-name** (your label). Map it to the real package name per distro family.

```json
"my-app": {
  "ubuntu": { "manager": "apt", "package": "real-package-name" },
  "debian": { "manager": "apt", "package": "real-package-name" },
  "fedora": { "manager": "dnf", "package": "real-package-name" },
  "arch":   { "manager": "pacman", "package": "real-package-name" }
}
```

AUR on Arch: `"manager": "aur", "package": "package-name"`

Third-party repos: add `"source": "brave"` or `"component": "multiverse"` when needed (same as base registry).

**Flatpak** (Flathub):

```json
"my-flatpak-app": {
  "debian": { "manager": "flatpak", "package": "com.example.App" },
  "ubuntu": { "manager": "flatpak", "package": "com.example.App" },
  "fedora": { "manager": "flatpak", "package": "com.example.App" }
}
```

`package` is the Flathub app ID. Flathub is added automatically if missing.

---

## 2. GitHub apps

Use `"*"` when the install is the same on every distro.

**Release binary**
```json
"eza": {
  "*": {
    "manager": "github",
    "repo": "eza-community/eza",
    "method": "release",
    "asset_pattern": "eza_.*_linux.tar.gz",
    "bin": "eza",
    "install_dir": "~/.local/bin"
  }
}
```

**Install script from repo**
```json
"fastfetch": {
  "*": {
    "manager": "github",
    "repo": "fastfetch-cli/fastfetch",
    "method": "script",
    "script_path": "install.sh",
    "ref": "main"
  }
}
```

**Build from source**
```json
"my-tool": {
  "*": {
    "manager": "github",
    "repo": "owner/my-tool",
    "method": "build",
    "ref": "main",
    "clone_dir": "~/.cache/os-configs/build/my-tool",
    "build_cmd": "make && make install PREFIX=$HOME/.local",
    "build_packages": ["git", "build-essential"]
  }
}
```

`build_packages` = native package names for your distro’s package manager (not simple-names).

---

## 3. Homebrew (optional)

Only runs if `brew` is on PATH — unless you set `"ensure_tool": true` to install Homebrew first.

```json
"ripgrep-brew": {
  "*": {
    "manager": "brew",
    "package": "ripgrep",
    "optional": true
  }
}
```

| Field | Meaning |
|-------|---------|
| `"optional": true` | Skip quietly if `brew` is missing |
| `"ensure_tool": true` | Install Homebrew, then install the formula |

---

## 4. Bun / Bunx

**Global Bun package** (`bun install -g`):
```json
"my-bun-cli": {
  "*": {
    "manager": "bun",
    "package": "some-npm-package",
    "optional": true,
    "ensure_tool": true
  }
}
```

**Run via Bunx** (one-shot; good for installers):
```json
"my-bunx-tool": {
  "*": {
    "manager": "bunx",
    "package": "some-cli-package",
    "optional": true
  }
}
```

Same `optional` / `ensure_tool` rules as Homebrew.

---

## 5. Show in Custom menu

Add the simple-name to **`data/user/categories.json`** under the right native category (`browsers`, `communication`, `creator`, …), or run **`scripts/import-arco-catalog.py`** after updating `arco-resolver/` to regenerate the Arco catalog.

Arco-derived apps live in **`data/catalog/`** (merged automatically). Cross-distro extras (Chrome, Signal, CAD, …) are in **`data/catalog/extras.json`** and are merged into the same native categories via **`data/catalog/categories-extras.json`**.

Put **GitHub / AppImage / script-only** apps in the **`custom-installers`** category (or your own user category). Everything with a normal package manager entry belongs in the matching native category.

Apps only appear in the picker when they have a registry entry **for your distro** and match your **platform** (server / desktop / laptop). Gaming-only tools also require a gaming-capable GPU.
