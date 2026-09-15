#!/usr/bin/env python3
"""Widen Reliquified Artifacts' Artifacts dependency pin.

Usage: reliquified-artifacts.py <META-INF/neoforge.mods.toml>

Reliquified Artifacts 1.0.8 pins its Artifacts dependency to the exact
version "[13.2.3]" (the release it was tested against), but the pack ships
Artifacts 13.2.5 (a bugfix release that fixes a Quark crash and Lootr mimic
textures). NeoForge treats "[13.2.3]" as an exact-match Maven range, so the
mod refuses to load with 13.2.5 ("requires artifacts 13.2.3"). Widening to
"[13.2.3,)" keeps the tested floor and accepts the newer fix release.

Fails loudly if the expected line is missing, so an upstream metadata change
is caught instead of silently producing an unpatched jar.
"""
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

new, n = re.subn(
    r'(modId\s*=\s*"artifacts"[\s\S]*?versionRange\s*=\s*")\[13\.2\.3\](")',
    r"\g<1>[13.2.3,)\g<2>",
    text,
)
if n != 1:
    sys.stderr.write(
        f"expected exactly one artifacts versionRange=\"[13.2.3]\" block, found {n}; "
        "re-review upstream metadata (Reliquified Artifacts)\n"
    )
    sys.exit(1)

with open(path, "w", encoding="utf-8") as f:
    f.write(new)