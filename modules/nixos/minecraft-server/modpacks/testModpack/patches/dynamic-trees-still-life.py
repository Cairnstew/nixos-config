#!/usr/bin/env python3
"""Fix Dynamic Trees - Still Life's embedded dependency range.

Usage: dynamic-trees-still-life.py <META-INF/neoforge.mods.toml>

The addon author pinned mr_still_life to "[1,)" anticipating Still Life 1.0,
which does not exist for MC 1.21.1 — the real 1.21.1 release is 0.1.1. Widen
the range to "[0.1,)" so 0.1.1 (and any future 1.x) is accepted.

Fails loudly if the expected line is missing, so an upstream metadata change
is caught instead of silently producing an unpatched jar.
"""
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

new, n = re.subn(r'(versionRange\s*=\s*")\[1,\)(")', r"\g<1>[0.1,)\g<2>", text)
if n != 1:
    sys.stderr.write(
        f"expected exactly one versionRange=\"[1,)\" line, found {n}; "
        "re-review upstream metadata (Dynamic Trees - Still Life)\n"
    )
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write(new)
