#!/usr/bin/env python3
"""merge_ini.py — declaratively update a Project Zomboid <servername>.ini

PZ stores runtime/world-identity keys in the .ini (Seed, ResetID,
ServerPlayerID, Password, ...) that MUST be preserved across restarts — the
module only owns a known set of keys, so we update those in place and leave
every other line untouched. On a fresh file we just append our keys.

Usage: merge_ini.py <path> [Key=value ...]
"""
import os
import sys


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit("usage: merge_ini.py <path> [Key=value ...]")
    path = sys.argv[1]
    updates = {}
    for arg in sys.argv[2:]:
        if "=" not in arg:
            sys.exit(f"arg {arg!r} has no '='")
        k, v = arg.split("=", 1)
        updates[k] = v

    path = os.path.realpath(path)
    os.makedirs(os.path.dirname(path), exist_ok=True)

    existing = {}
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8", errors="replace") as f:
            raw = f.read()
        for line in raw.splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            existing[k.strip()] = v.strip()

    merged = {**existing, **updates}

    lines = [f"{k}={v}" for k, v in merged.items()]
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
