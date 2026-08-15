#!/usr/bin/env python3
"""Sync built modpack client content into a Prism Launcher instance dir.

Shared implementation between:
  - the home module's `minecraft-instance-<name>` service/activation
    (modules/home/minecraft/instances.nix), and
  - the manual CLI apps `nix run .#modpack-build-<name>` / `.#modpack-update-<name>`
    (modules/flake-parts/packwiz.nix) — so a fix to instance layout is never
    applied to only one caller.

Usage: packwiz-instance-sync.py <instance-dir> <meta.json> <built-content> [server]

- writes instance.cfg + mmc-pack.json (at the INSTANCE ROOT — Prism reads the
  components file via instanceRoot()/mmc-pack.json, NOT .minecraft/),
- refreshes .minecraft/mods/ wholesale (pack owns mods/), dereferencing the
  store symlinks so the instance is self-contained,
- seeds .minecraft/{config,kubejs,scripts,datapacks,defaultconfigs} only when
  absent (player edits win).
"""
import json
import os
import subprocess
import sys

inst, meta_path, src, server = (
    sys.argv[1],
    sys.argv[2],
    sys.argv[3],
    (sys.argv[4] if len(sys.argv) > 4 else ""),
)

meta = json.load(open(meta_path))
os.makedirs(os.path.join(inst, ".minecraft"), exist_ok=True)

# If no server arg given, preserve an existing [JoinServerOnLaunch] address
# from a previous instance.cfg (e.g. the home module's declarative `server`),
# so a manual `modpack-build` never silently drops it.
if not server:
    try:
        with open(os.path.join(inst, "instance.cfg")) as f:
            for line in f:
                if line.startswith("address="):
                    server = line.rstrip("\n").split("=", 1)[1]
                    break
    except OSError:
        pass

lines = ["InstanceType=OneSix", "name=" + (meta.get("packName") or meta["name"]), "[Java]"]
if server:
    lines += ["[JoinServerOnLaunch]", "address=" + server]
lines += [
    "[OneSix]",
    "MinecraftVersion=" + meta["mc"],
    "Components=" + meta["loaderUid"] + ":" + meta["loaderVersion"],
]
with open(os.path.join(inst, "instance.cfg"), "w") as f:
    f.write("\n".join(lines) + "\n")

mmc = {
    "components": [
        {"uid": "net.minecraft", "version": meta["mc"]},
        {"uid": meta["loaderUid"], "version": meta["loaderVersion"], "important": True},
    ],
    "formatVersion": 1,
}
with open(os.path.join(inst, "mmc-pack.json"), "w") as f:
    json.dump(mmc, f, indent=2)


def run(cmd):
    subprocess.check_call(cmd)


mods_src = os.path.join(src, "mods")
if os.path.isdir(mods_src):
    mods_dst = os.path.join(inst, ".minecraft", "mods")
    os.makedirs(mods_dst, exist_ok=True)
    run(["rsync", "-a", "-L", "--chmod=F644", mods_src + "/", mods_dst + "/"])
    run(["chmod", "-R", "u+w", mods_dst])
    run(["rsync", "-a", "--delete", "-L", mods_src + "/", mods_dst + "/"])
    run(["chmod", "-R", "a-w,u+w", mods_dst])

for d in ["config", "kubejs", "scripts", "datapacks", "defaultconfigs"]:
    d_src = os.path.join(src, d)
    if os.path.isdir(d_src):
        d_dst = os.path.join(inst, ".minecraft", d)
        os.makedirs(d_dst, exist_ok=True)
        run(["rsync", "-a", "-L", "--ignore-existing", d_src + "/", d_dst + "/"])

# Game-root files (e.g. a shipped default options.txt) are seeded only when
# absent, matching the internal-dir policy: players' edits win.
opt_src = os.path.join(src, "options.txt")
if os.path.isfile(opt_src):
    opt_dst = os.path.join(inst, ".minecraft", "options.txt")
    if not os.path.exists(opt_dst):
        run(["cp", "-L", opt_src, opt_dst])
