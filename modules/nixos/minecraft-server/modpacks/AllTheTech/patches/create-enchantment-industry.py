#!/usr/bin/env python3
"""Demote Create: Enchantment Industry's hard dep on create_dragons_plus.

Usage: create-enchantment-industry.py <META-INF/neoforge.mods.toml>

The mod declares create_dragons_plus as a REQUIRED dependency, but AllTheTech
removed Dragon Survival + its addons (Create Dragons Plus is a Create x Dragon
Survival cross-mod addon). The dragons-plus integration is optional recipe
compat (dyes, dragon breath, blaze upgrades); with the dep demoted to optional
the mod loads normally and just skips those recipes.

Fails loudly if the expected dependency block is missing, so an upstream
metadata change is caught instead of silently producing an unpatched jar.
"""
import re
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    text = f.read()

# The block looks like:
#     [[dependencies.create_enchantment_industry]]
#         modId="create_dragons_plus"
#         type="required"
#         versionRange="[1.11.3,)"
# Swap the explicit type="required" to "optional" inside that block.
pattern = re.compile(
    r'(^[ \t]*modId[ \t]*=[ \t]*"create_dragons_plus"[ \t]*\n'
    r'[ \t]*type[ \t]*=[ \t]*")required(")',
    re.M,
)
new, n = pattern.subn(r"\g<1>optional\g<2>", text)
if n == 0:
    # Fallback: block exists but has no type line yet — insert optional.
    fallback = re.compile(
        r'(^[ \t]*modId[ \t]*=[ \t]*"create_dragons_plus"[ \t]*\n)',
        re.M,
    )
    new2, n2 = fallback.subn(r"\g<1>    type=\"optional\"\n", text)
    if n2 != 1:
        sys.stderr.write(
            f"expected a create_dragons_plus dependency block, found {n}/{n2}; "
            "re-review upstream metadata (Create: Enchantment Industry)\n"
        )
        sys.exit(1)
    new = new2

with open(path, "w", encoding="utf-8") as f:
    f.write(new)