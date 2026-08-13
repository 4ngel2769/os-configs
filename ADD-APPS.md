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

Add the simple-name to **`data/user/categories.json`**:

```json
{
  "utilities": {
    "apps": ["my-app", "eza"]
  },
  "community": {
    "label": "Community / GitHub",
    "apps": ["eza", "ripgrep-brew", "my-bun-cli"]
  }
}
```

Apps in presets use simple-names too — user registry entries work there automatically after merge.
