#!/usr/bin/env python3
"""Apply declarative Steam shader pre-caching settings.

Settings are read from the environment so the Nix module can render them:

    SHADER_PRECACHE_STATE    "on" | "off"
    SHADER_PRECACHE_THREADS  worker threads (default: CPU count)

Writes ``ShaderPreCache`` / ``AllowBackgroundProcessingOfVulkanShaders`` in
``config.vdf`` and every user's ``localconfig.vdf``, plus
``EnableShaderBackgroundProcessing`` in the ``ShaderCacheManager`` block and
``unShaderBackgroundProcessingThreads`` in ``steam_dev.cfg``.

Steam must be closed: it holds these files in memory and rewrites them on
exit, silently discarding anything written while it runs.

The VDF files are edited line-by-line rather than parsed and re-serialised.
A Keyvalues round-trip is lossy here - it escapes embedded newlines in values
and drops duplicate keys - so only the target lines are touched.
"""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

STEAM_DIR = Path(os.path.expanduser("~/.steam/steam"))

# InstallConfigStore/Software/Valve/Steam in config.vdf and the matching
# UserLocalConfigStore path in localconfig.vdf.
GLOBAL_KEYS = ("ShaderPreCache", "AllowBackgroundProcessingOfVulkanShaders")
# InstallConfigStore/Software/Valve/Steam/ShaderCacheManager in config.vdf.
BACKGROUND_KEY = "EnableShaderBackgroundProcessing"
THREADS_KEY = "unShaderBackgroundProcessingThreads"


def steam_running() -> bool:
    """True if any Steam client process is alive for this user."""
    for name in ("steam", "steamwebhelper"):
        result = subprocess.run(
            ["pgrep", "-u", str(os.getuid()), "-x", name],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if result.returncode == 0:
            return True
    return False


def find_block(lines: list[str], keypath: list[str]) -> tuple[int, int] | None:
    """Return the (open, close) line indexes of the block at ``keypath``."""
    stack: list[tuple[str, int]] = []
    pending: str | None = None
    for i, line in enumerate(lines):
        stripped = line.strip()
        if not stripped or stripped.startswith("//"):
            continue
        name = re.fullmatch(r'"([^"]*)"', stripped)
        if name:
            pending = name.group(1)
            continue
        if stripped == "}":
            if stack:
                stack.pop()
            pending = None
            continue
        if stripped == "{":
            if pending is None:
                continue
            stack.append((pending, i))
            if [n for n, _ in stack] == keypath:
                depth = 0
                for j in range(i, len(lines)):
                    token = lines[j].strip()
                    if token == "{":
                        depth += 1
                    elif token == "}":
                        depth -= 1
                        if depth == 0:
                            return i, j
                return None
            pending = None
            continue
        pending = None
    return None


def set_keys(
    lines: list[str], keypath: list[str], pairs: list[tuple[str, str]]
) -> bool:
    """Set ``pairs`` inside the block at ``keypath``; insert missing keys."""
    location = find_block(lines, keypath)
    if location is None:
        print(f"warning: {'/'.join(keypath)} not found, skipping", file=sys.stderr)
        return False
    open_i, close_i = location
    indent = re.match(r"[ \t]*", lines[open_i]).group(0) + "\t"

    for key, value in pairs:
        pattern = re.compile(rf'^[ \t]*"{re.escape(key)}"[ \t]+"[^"]*"[ \t]*$')
        for i in range(open_i + 1, close_i):
            if pattern.match(lines[i].rstrip("\n")):
                lines[i] = f'{indent}"{key}"\t\t"{value}"\n'
                break
        else:
            lines.insert(close_i, f'{indent}"{key}"\t\t"{value}"\n')
            close_i += 1
    return True


def update_vdf(path: Path, sections: list[tuple[list[str], list[tuple[str, str]]]]) -> bool:
    """Apply ``sections`` to ``path``; return True if it changed."""
    if not path.is_file():
        print(f"skipping missing {path}")
        return False
    original = path.read_text(encoding="utf-8", errors="surrogateescape")
    lines = original.splitlines(keepends=True)
    for keypath, pairs in sections:
        set_keys(lines, keypath, pairs)
    updated = "".join(lines)
    if updated == original:
        return False
    mode = path.stat().st_mode
    tmp = path.with_name(path.name + ".tmp")
    tmp.write_text(updated, encoding="utf-8", errors="surrogateescape")
    os.chmod(tmp, mode)
    os.replace(tmp, path)
    return True


def write_threads(threads: int) -> bool:
    """Set the Vulkan shader worker thread count in steam_dev.cfg."""
    path = STEAM_DIR / "steam_dev.cfg"
    kept: list[str] = []
    if path.is_file():
        kept = [
            line
            for line in path.read_text(encoding="utf-8").splitlines(keepends=True)
            if not line.strip().startswith(THREADS_KEY)
        ]
        if kept and not kept[-1].endswith("\n"):
            kept[-1] += "\n"
    updated = "".join(kept) + f"{THREADS_KEY} {threads}\n"
    if path.is_file() and path.read_text(encoding="utf-8") == updated:
        return False
    path.write_text(updated, encoding="utf-8")
    return True


def main() -> int:
    state = os.environ.get("SHADER_PRECACHE_STATE", "on").strip().lower()
    if state not in {"on", "off"}:
        print(f"invalid SHADER_PRECACHE_STATE: {state!r}", file=sys.stderr)
        return 2
    value = "1" if state == "on" else "0"

    raw_threads = os.environ.get("SHADER_PRECACHE_THREADS", "").strip()
    try:
        threads = int(raw_threads) if raw_threads else (os.cpu_count() or 1)
    except ValueError:
        print(f"invalid SHADER_PRECACHE_THREADS: {raw_threads!r}", file=sys.stderr)
        return 2

    if steam_running():
        print(
            "Steam is running - quit it first, it rewrites these files on exit.",
            file=sys.stderr,
        )
        return 1

    changed: list[str] = []
    config = STEAM_DIR / "config" / "config.vdf"
    if update_vdf(
        config,
        [
            (
                ["InstallConfigStore", "Software", "Valve", "Steam"],
                [(key, value) for key in GLOBAL_KEYS],
            ),
            (
                ["InstallConfigStore", "Software", "Valve", "Steam", "ShaderCacheManager"],
                [(BACKGROUND_KEY, value)],
            ),
        ],
    ):
        changed.append(str(config))

    userdata = STEAM_DIR / "userdata"
    if userdata.is_dir():
        for user_dir in sorted(userdata.iterdir()):
            if user_dir.is_dir() and user_dir.name.isdigit():
                local = user_dir / "config" / "localconfig.vdf"
                if update_vdf(
                    local,
                    [
                        (
                            ["UserLocalConfigStore", "Software", "Valve", "Steam"],
                            [(key, value) for key in GLOBAL_KEYS],
                        )
                    ],
                ):
                    changed.append(str(local))

    if write_threads(threads):
        changed.append(str(STEAM_DIR / "steam_dev.cfg"))

    if changed:
        for path in changed:
            print(f"updated {path}")
    else:
        print(f"shader pre-caching already {state} ({threads} threads)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
