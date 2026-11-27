#!/usr/bin/env python3
"""Delete Steam's pre-compiled shader cache for one app in every library.

Usage: steam-clear-shader-cache <appid>

A corrupt or truncated ``steamapps/shadercache/<appid>`` makes Steam's
Fossilize replay stall on every launch (the "Processing Vulkan shaders"
dialog never finishes). Steam must be closed so it does not rewrite the cache.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

STEAM_DIR = Path(os.path.expanduser("~/.steam/steam"))


def steam_running() -> bool:
    for name in ("steam", "steamwebhelper"):
        result = subprocess.run(
            ["pgrep", "-u", str(os.getuid()), "-x", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return True
    return False


def libraries() -> list[Path]:
    """Steam root plus every library listed in libraryfolders.vdf."""
    found = [STEAM_DIR]
    folders = STEAM_DIR / "steamapps" / "libraryfolders.vdf"
    if folders.is_file():
        text = folders.read_text(encoding="utf-8", errors="replace")
        for match in re.finditer(r'"path"\s+"([^"]+)"', text):
            lib = Path(match.group(1))
            if lib not in found:
                found.append(lib)
    return found


def main() -> int:
    if len(sys.argv) != 2 or not sys.argv[1].isdigit():
        print("usage: steam-clear-shader-cache <appid>", file=sys.stderr)
        return 2
    appid = sys.argv[1]

    if steam_running():
        print("Steam is running - quit it first.", file=sys.stderr)
        return 1

    removed = 0
    for library in libraries():
        cache = library / "steamapps" / "shadercache" / appid
        if not cache.is_dir():
            continue
        size = sum(p.stat().st_size for p in cache.rglob("*") if p.is_file())
        shutil.rmtree(cache)
        print(f"removed {cache} ({size / 1e6:.0f} MB)")
        removed += 1

    if not removed:
        print(f"no shader cache found for app {appid}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
