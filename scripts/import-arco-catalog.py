#!/usr/bin/env python3
"""Import arco-resolver package lists into os-configs registry + categories."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ARCO = ROOT / "arco-resolver"
OUT = ROOT / "data" / "catalog"

EXCLUDE_PAGES = {
    "kernel",
    "drivers",
    "nvidia",
    "login",
    "desktop",
    "desktop-wayland",
    "arcolinux",
    "arcolinuxdev",
}

# Arco page › group → installer category id + label
CAT_MAP: dict[tuple[str, str], tuple[str, str]] = {
    ("internet", "Browsers"): ("browsers", "Browsers"),
    ("internet", "Downloaders"): ("internet-downloaders", "Downloaders"),
    ("internet", "Cloud Software"): ("internet-cloud", "Cloud"),
    ("internet", "Mail Clients"): ("internet-mail", "Mail"),
    ("internet", "Vpn Software"): ("internet-vpn", "VPN"),
    ("communication", "Communication"): ("communication", "Communication"),
    ("communication", "Connect Remotely"): ("communication-remote", "Remote desktop"),
    ("development", "Development"): ("developer", "Development"),
    ("office", "Libre Office Fresh"): ("office", "Office"),
    ("office", "Libre Office Still"): ("office", "Office"),
    ("office", "Abiword"): ("office", "Office"),
    ("office", "Calligra"): ("office", "Office"),
    ("office", "Epub"): ("office", "Office"),
    ("office", "Freeoffice"): ("office", "Office"),
    ("office", "Focuswriter"): ("office", "Office"),
    ("office", "Ghostwriter"): ("office", "Office"),
    ("office", "Gnumeric"): ("office", "Office"),
    ("office", "Ms Office Online"): ("office", "Office"),
    ("office", "Moneydance"): ("office", "Office"),
    ("office", "Onlyoffice"): ("office", "Office"),
    ("office", "Openoffice"): ("office", "Office"),
    ("office", "PDF applications"): ("office", "Office"),
    ("office", "Scribus"): ("office", "Office"),
    ("office", "WPS Office"): ("office", "Office"),
    ("multimedia", "Audio Software"): ("media-audio", "Audio"),
    ("multimedia", "Video Software"): ("media-video", "Video"),
    ("graphics", "Graphics"): ("creator", "Creator & graphics"),
    ("gaming", "Games"): ("gaming", "Games"),
    ("gaming", "Game utilities"): ("gaming-tools", "Gaming tools"),
    ("utilities", "Utilities"): ("utilities", "Utilities"),
    ("utilities", "Utilities for hardware discovery"): ("utilities", "Utilities"),
    ("utilities", "Utilities for Android"): ("utilities", "Utilities"),
    ("utilities", "Utilities for IOS"): ("utilities", "Utilities"),
    ("utilities", "Utilities for benchmarking"): ("utilities", "Utilities"),
    ("utilities", "Application installers or launchers"): ("utilities", "Utilities"),
    ("utilities", "Power Management"): ("utilities", "Utilities"),
    ("utilities", "Backlight"): ("utilities", "Utilities"),
    ("utilities", "Utilities Kernels"): ("utilities", "Utilities"),
    ("utilities", "Utilities for Timeshift and Btrfs"): ("utilities", "Utilities"),
    ("utilities", "Utilities for Snapper and Btrfs"): ("utilities", "Utilities"),
    ("applications", "Accessories"): ("accessories", "Accessories"),
    ("applications", "Conky"): ("accessories", "Accessories"),
    ("applications", "Git"): ("developer", "Development"),
    ("applications", "Password Manager"): ("accessories", "Accessories"),
    ("applications", "Privacy"): ("accessories", "Accessories"),
    ("applications", "Virtualbox for Linux kernel"): ("accessories", "Accessories"),
    ("applications", "Virtualbox for Linux-lts kernel"): ("accessories", "Accessories"),
    ("applications", "Vmware"): ("accessories", "Accessories"),
    ("applications", "Qemu software"): ("accessories", "Accessories"),
    ("terminals", "Terminals"): ("terminals", "Terminals"),
    ("terminals", "Terminal Fun"): ("terminals", "Terminals"),
    ("terminals", "Terminal Tools To Search"): ("terminals", "Terminals"),
    ("terminals", "Zsh"): ("terminals", "Terminals"),
    ("filemanagers", "Filemanagers"): ("filemanagers", "File managers"),
    ("fonts", "Fonts"): ("fonts", "Fonts"),
    ("theming", "Themes"): ("theming", "Themes"),
    ("theming", "Icons"): ("theming", "Themes"),
    ("theming", "Cursors"): ("theming", "Themes"),
    ("theming", "Changing the look"): ("theming", "Themes"),
    ("usb", "Usb/Disk Utilities"): ("utilities", "Utilities"),
    ("usb", "Printing Utilities"): ("utilities", "Utilities"),
    ("usb", "Accessibility Utilities"): ("utilities", "Utilities"),
}

GAMING_GPU_GROUPS = {"Game utilities"}
GUI_CATEGORIES = {
    "browsers",
    "communication",
    "communication-remote",
    "creator",
    "media-audio",
    "media-video",
    "gaming",
    "gaming-tools",
    "office",
    "accessories",
    "fonts",
    "theming",
    "filemanagers",
}

AUR_SUFFIXES = ("-bin", "-git", "-appimage")
AUR_HINTS = (
    "nativefier",
    "visual-studio-code-bin",
    "chrome-gnome-shell",
    "proton-ge",
    "protonup",
    "heroic-games-launcher",
)


def simple_name(arch_pkg: str) -> str:
    base = arch_pkg.lower()
    for suffix in ("-bin", "-git", "-appimage"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break
    base = re.sub(r"[^a-z0-9]+", "-", base).strip("-")
    return base or arch_pkg.lower()


def display_label(arch_pkg: str) -> str:
    name = simple_name(arch_pkg)
    return " ".join(w.capitalize() for w in name.split("-"))


def is_aur_package(arch_pkg: str) -> bool:
    lower = arch_pkg.lower()
    if any(lower.endswith(s) for s in AUR_SUFFIXES):
        return True
    return any(h in lower for h in AUR_HINTS)


def arch_family_entry(arch_pkg: str, arch_map: dict) -> dict | None:
    mapped = arch_map.get(arch_pkg)
    if mapped is None:
        return None
    if isinstance(mapped, str) and mapped.endswith("(group)"):
        return None
    pkg = mapped if isinstance(mapped, str) and mapped else arch_pkg
    manager = "aur" if is_aur_package(arch_pkg) else "pacman"
    return {"manager": manager, "package": pkg}


def family_entries(resolved: dict, arch_pkg: str, arch_map: dict) -> dict:
    row = resolved.get(arch_pkg, {})
    out: dict = {}

    arch = arch_family_entry(arch_pkg, arch_map)
    if arch:
        out["arch"] = arch

    apt = row.get("apt")
    if apt:
        out["debian"] = {"manager": "apt", "package": apt}

    ubu = row.get("ubu")
    if ubu:
        out["ubuntu"] = {"manager": "apt", "package": ubu}

    dnf = row.get("dnf")
    if dnf:
        out["fedora"] = {"manager": "dnf", "package": dnf}

    return out


def platforms_for(cat_id: str, group: str) -> list[str]:
    if cat_id in GUI_CATEGORIES:
        return ["desktop", "laptop"]
    if cat_id in {"developer", "terminals", "utilities", "internet-downloaders"}:
        return ["desktop", "laptop", "server"]
    return ["desktop", "laptop", "server"]


def requires_gpu(cat_id: str, group: str) -> str | None:
    if cat_id == "gaming-tools" or group in GAMING_GPU_GROUPS:
        return "gaming"
    return None


def parse_category(entry: str) -> tuple[str, str] | None:
    if "›" in entry:
        page, group = entry.split("›", 1)
    else:
        page, group = entry, "Other"
    page = page.strip()
    group = group.strip()
    if page in EXCLUDE_PAGES:
        return None
    mapped = CAT_MAP.get((page, group))
    if mapped:
        return mapped
    if page in EXCLUDE_PAGES:
        return None
    # fallback: page as category id
    cat_id = re.sub(r"[^a-z0-9]+", "-", page.lower()).strip("-")
    label = page.replace("-", " ").title()
    return cat_id, label


def load_base_registry() -> set[str]:
    base_path = ROOT / "data" / "registry.json"
    if not base_path.exists():
        return set()
    data = json.loads(base_path.read_text(encoding="utf-8"))
    return set(data.keys())


def main() -> int:
    resolved = json.loads((ARCO / "resolved.json").read_text(encoding="utf-8"))
    arch_map = json.loads((ARCO / "arch-map.json").read_text(encoding="utf-8"))
    pkg_cat = json.loads((ARCO / "pkg-cat.json").read_text(encoding="utf-8"))
    base_names = load_base_registry()

    registry: dict = {}
    categories: dict[str, dict] = {}

    for arch_pkg, cat_entries in pkg_cat.items():
        families = family_entries(resolved, arch_pkg, arch_map)
        if not families:
            continue

        sid = simple_name(arch_pkg)
        if sid in base_names:
            continue
        if sid in registry:
            # merge family entries into existing simple name
            for fam, entry in families.items():
                registry[sid].setdefault(fam, entry)
            continue

        meta: dict = {
            "label": display_label(arch_pkg),
        }

        app_cats: set[str] = set()
        gpu_req = None
        plat: set[str] = set()

        for raw in cat_entries:
            parsed = parse_category(raw)
            if not parsed:
                continue
            cat_id, cat_label = parsed
            app_cats.add(cat_id)
            categories.setdefault(cat_id, {"label": cat_label, "apps": []})
            plat.update(platforms_for(cat_id, raw.split("›", 1)[-1].strip() if "›" in raw else ""))
            g = requires_gpu(cat_id, raw.split("›", 1)[-1].strip() if "›" in raw else "")
            if g:
                gpu_req = g

        if not app_cats:
            continue

        meta["platforms"] = sorted(plat) if plat else ["desktop", "laptop", "server"]
        if gpu_req:
            meta["requires_gpu"] = gpu_req

        registry[sid] = {**meta, **families}

        for cat_id in app_cats:
            apps = categories[cat_id]["apps"]
            if sid not in apps:
                apps.append(sid)

    for cat in categories.values():
        cat["apps"] = sorted(set(cat["apps"]))

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "registry-arco.json").write_text(
        json.dumps(registry, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    (OUT / "categories-arco.json").write_text(
        json.dumps(categories, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(f"registry entries: {len(registry)}")
    print(f"categories: {len(categories)}")
    print(f"wrote {OUT / 'registry-arco.json'}")
    print(f"wrote {OUT / 'categories-arco.json'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
