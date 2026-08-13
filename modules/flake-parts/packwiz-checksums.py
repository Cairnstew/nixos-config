#!/usr/bin/env python3
"""Generate a packwiz2nix checksums.json from a packwiz modpack's mods/ dir.

Usage: packwiz-checksums.py <mods-dir>

Reads every *.pw.toml, extracts its [download] url, downloads the mod jar and
writes the checksums.json JSON object (key = .pw.toml filename, value =
{url, sha256}) to stdout — the exact format packwiz2nix's mkPackwizPackages
expects.

Run as part of a Nix build derivation (build-time network) rather than at
evaluation time, because packwiz2nix's mkChecksums uses builtins.fetchurl,
which pure evaluation forbids without a pinned hash.
"""
import sys
import os
import re
import json
import hashlib
import urllib.request

mods_dir = sys.argv[1]
if not os.path.isdir(mods_dir):
    print("{ }")
    sys.exit(0)
result = {}
errors = []
for f in sorted(os.listdir(mods_dir)):
    if not f.endswith(".pw.toml"):
        continue
    txt = open(os.path.join(mods_dir, f)).read()
    url = None
    dm = re.search(r"^\[download\]\s*\n(.*?)(?=\n\[|\Z)", txt, re.S | re.M)
    if dm:
        um = re.search(r'^url\s*=\s*"([^"]+)"', dm.group(1), re.M)
        if um:
            url = um.group(1)
    if not url:
        errors.append(f)
        continue
    try:
        data = urllib.request.urlopen(url, timeout=180).read()
        result[f] = {"url": url, "sha256": "sha256-" + hashlib.sha256(data).hexdigest()}
    except Exception as e:  # noqa: BLE001
        errors.append(f"{f}: {e}")

if errors:
    sys.stderr.write("packwiz-checksums: FAILED to fetch:\n  " + "\n  ".join(errors) + "\n")
    sys.exit(1)

print(json.dumps(result, indent=1))
