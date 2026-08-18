#!/usr/bin/env python3
"""Verify a packwiz modpack before wiring it into the Nix server.

Usage: mc-pack-status.py <modpack-dir>

Checks, relative to the given modpack dir:
  - mod count (mods/*.pw.toml)
  - index.toml sync (every .pw.toml listed, and vice versa)
  - checksums.json coverage (one entry per mod, every entry has url + sha256)
  - CurseForge-mode mods (no download url) — these break the packwiz2nix build
  - duplicate jar filenames
  - internal files (config/, kubejs/, scripts/, datapacks/, defaultconfigs/)
    present on disk but MISSING from index.toml — they won't reach the server
  - datapacks under config/paxi/datapacks/ whose pack.mcmeta pack_format
    doesn't match the pack's Minecraft version
Prints a short report and a final READY / NEEDS WORK line.
"""
import os
import re
import sys
import json
import zipfile

PACK_FORMATS = {
    "1.20.5": 41, "1.20.6": 41,
    "1.21": 48, "1.21.1": 48,
    "1.21.2": 57, "1.21.3": 57,
    "1.21.4": 61,
    "1.21.5": 71, "1.21.6": 71,
}

INTERNAL_DIRS = ["config", "kubejs", "scripts", "datapacks", "defaultconfigs"]

pack_dir = sys.argv[1]
mods_dir = os.path.join(pack_dir, "mods")
report = []

if not os.path.isdir(mods_dir):
    report.append("mods on disk: 0")
    report.append("status: NEEDS WORK")
    print("\n".join(report))
    sys.exit(1)

mods = sorted(f for f in os.listdir(mods_dir) if f.endswith(".pw.toml"))
report.append(f"mods on disk: {len(mods)}")

indexed = set()
index_path = os.path.join(pack_dir, "index.toml")
if os.path.exists(index_path):
    import tomllib

    with open(index_path, "rb") as fh:
        indexed = {e["file"] for e in tomllib.load(fh).get("files", [])}
    # Only mods/*.pw.toml entries participate in the mod sync check; shaderpacks/
    # and resourcepacks/ metafiles plus pack-root internal files (e.g. options.txt
    # → game root) are legitimately indexed but are not mods.
    indexed_mods = {os.path.basename(f) for f in indexed if f.startswith("mods/") and f.endswith(".pw.toml")}
    sync = indexed_mods == set(mods)
    report.append(f"index.toml entries: {len(indexed)} ({'in sync' if sync else 'MISMATCH'})")
else:
    sync = False
    report.append("index.toml: MISSING")


def read_toml(p):
    with open(p) as fh:
        return fh.read()


curseforge = 0
with_url = 0
no_url = []
sides = {"client": [], "server": [], "both": []}
for f in mods:
    txt = read_toml(os.path.join(mods_dir, f))
    if "metadata:curseforge" in txt:
        curseforge += 1
    if re.search(r"^url\s*=\s*\"", txt, re.M):
        with_url += 1
    else:
        no_url.append(f)
    m = re.search(r'^side\s*=\s*"(\w+)"', txt, re.M)
    side = m.group(1) if m else "both"  # packwiz defaults to both when absent
    if side in sides:
        sides[side].append(f)
report.append(f"curseforge-mode mods (no download url): {curseforge}")
report.append(f"mods with direct download url: {with_url}")

# ── Server-side mod split ────────────────────────────────────────────────────
# The server links ONLY side = "both" / "server" mods (config.nix packwizSymlinks
# filters side = "client"). Report what the server will actually load, and flag
# side = "both" mods that are known to be client-only in practice (they load
# client classes on a dedicated server and crash it — mark them side = "client").
report.append(
    f"server-side mods (side = both/server, WILL load on server): {len(sides['both']) + len(sides['server'])}"
)
report.append(f"client-only mods (side = client, skipped by server): {len(sides['client'])}")

# Known client-only mods that upstream tags as both but crash a dedicated
# server with client-only class loads. If any are present, they will boot-loop
# the server until marked side = "client".
CLIENT_CRASH_RISK = {
    "connector": "Sinytra Connector (Fabric→NeoForge bridge)",
    "connector-extras": "Connector Extras",
    "preloading-tricks": "Preloading Tricks (connector bootstrap)",
    "ftb-quests-throughput-addon": "FTB Quests Throughput Addon",
    "wakes": "Wakes Reforged",
    "wakes-reforged": "Wakes Reforged",
    "sodium": "Sodium (render)",
    "iris": "Iris (shaders)",
    "reeses-sodium-options": "Reese's Sodium Options",
    "continuity": "Continuity (connected textures)",
    "entity-model-features": "Entity Model Features",
    "entitytexturefeatures": "Entity Texture Features",
    "immediatelyfast": "ImmediatelyFast (render)",
    "badoptimizations": "BadOptimizations (render)",
    "more-enchantment-info": "More Enchantment Info",
    "sound-physics-remastered": "Sound Physics Remastered (audio)",
    "particle-core": "Particle Core (client particles)",
}
risk_present = []
for f in mods:
    key = f.replace(".pw.toml", "")
    label = CLIENT_CRASH_RISK.get(key)
    if not label:
        continue
    if key in sides["both"]:
        risk_present.append(f"  {f} → side = both BUT client-only ({label}) — server will crash at boot; set side = \"client\"")
if risk_present:
    report.append("CLIENT-CRASH RISK (side = both, client-only in practice):")
    report.extend(risk_present)
else:
    report.append("client-crash risk mods (side = both): none")

fnames = []
for f in mods:
    m = re.search(r'^filename\s*=\s*"(.+)"', read_toml(os.path.join(mods_dir, f)), re.M)
    if m:
        fnames.append(m.group(1))
dups = sorted({x for x in fnames if fnames.count(x) > 1})
report.append(f"duplicate jar filenames: {dups if dups else 'none'}")

cs = {}
cs_path = os.path.join(pack_dir, "checksums.json")
if os.path.exists(cs_path):
    with open(cs_path) as fh:
        cs = json.load(fh)
    cs_ok = len(cs) == len(mods) and all(v.get("url") and v.get("sha256") for v in cs.values())
    report.append(f"checksums.json entries: {len(cs)} ({'matches' if cs_ok else 'MISMATCH'})")
else:
    cs_ok = False
    report.append("checksums.json: MISSING (run the packwiz-checksums tool)")

if not no_url:
    no_url_report = "none"
else:
    no_url_report = ", ".join(no_url[:8]) + (" …" if len(no_url) > 8 else "")
report.append(f"mods missing a download url: {no_url_report}")

# ── Internal files (configs / kubejs / scripts / datapacks / defaultconfigs) ──
# packwiz installers copy internal files from the pack dir into the game folder,
# but only when they're listed in index.toml. Files on disk that are NOT indexed
# silently never reach players. (The Nix server deploy does the same via the
# packwiz pack's content subdirs.) Skip `.pw.toml` metafiles and dotfiles.
index_text = ""
if os.path.exists(index_path):
    index_text = open(index_path).read()
indexed_files = set(re.findall(r'^file\s*=\s*"([^"]+)"', index_text, re.M)) if index_text else set()

internal_missing = []
internal_total = 0
for d in INTERNAL_DIRS:
    base = os.path.join(pack_dir, d)
    if not os.path.isdir(base):
        continue
    for root, _, files in os.walk(base):
        for f in sorted(files):
            if f.endswith(".pw.toml") or f.startswith("."):
                continue
            internal_total += 1
            rel = os.path.relpath(os.path.join(root, f), pack_dir).replace(os.sep, "/")
            if rel not in indexed_files:
                internal_missing.append(rel)
if internal_missing:
    report.append(f"internal files: {internal_total} on disk, {len(internal_missing)} NOT indexed")
    for rel in internal_missing[:8]:
        report.append(f"  NOT INDEXED: {rel}")
    if len(internal_missing) > 8:
        report.append(f"  … and {len(internal_missing) - 8} more")
else:
    report.append(f"internal files: {internal_total} on disk, all indexed")

# ── Datapack pack_format validation ───────────────────────────────────────────
datapack_issues = []
paxi_dir = os.path.join(pack_dir, "config", "paxi", "datapacks")
mc_ver = None
m = re.search(r'^minecraft\s*=\s*"([^"]+)"', read_toml(os.path.join(pack_dir, "pack.toml")), re.M)
if m:
    mc_ver = m.group(1)
want_fmt = PACK_FORMATS.get(mc_ver)
if os.path.isdir(paxi_dir):
    import tomllib  # noqa: F811 (re-import fine)

    for entry in sorted(os.listdir(paxi_dir)):
        p = os.path.join(paxi_dir, entry)
        meta_path = None
        if os.path.isdir(p):
            meta_path = os.path.join(p, "pack.mcmeta")
            if not os.path.exists(meta_path):
                datapack_issues.append(f"{entry}: no pack.mcmeta in dir datapack")
                continue
        elif entry.endswith(".zip"):
            try:
                with zipfile.ZipFile(p) as zf:
                    cand = next((n for n in zf.namelist() if n.endswith("pack.mcmeta")), None)
                    if cand is None:
                        datapack_issues.append(f"{entry}: no pack.mcmeta in zip")
                        continue
                    data = json.loads(zf.read(cand))
                    got = data.get("pack", {}).get("pack_format")
            except Exception as e:  # noqa: BLE001
                datapack_issues.append(f"{entry}: unreadable zip ({e})")
                continue
        else:
            continue
        if not meta_path:
            got = data.get("pack", {}).get("pack_format")
        else:
            got = None
            try:
                with open(meta_path) as fh:
                    got = json.load(fh).get("pack", {}).get("pack_format")
            except Exception as e:  # noqa: BLE001
                datapack_issues.append(f"{entry}: unreadable pack.mcmeta ({e})")
                continue
        if want_fmt is not None and got != want_fmt:
            datapack_issues.append(f"{entry}: pack_format {got} != {want_fmt} (MC {mc_ver})")
    report.append(f"datapack pack_format checks: {len(datapack_issues)} problem(s)" if datapack_issues
                  else f"datapacks (config/paxi/datapacks/): ok (pack_format {want_fmt} for MC {mc_ver})")
    for issue in datapack_issues[:8]:
        report.append(f"  {issue}")
elif want_fmt is not None:
    report.append(f"datapacks (config/paxi/datapacks/): none")
else:
    report.append(f"datapacks: could not determine expected pack_format for MC {mc_ver or '?'}")

ready = (
    sync and cs_ok and curseforge == 0 and not dups and not no_url
    and not internal_missing and not datapack_issues and not risk_present
)
report.append(f"status: {'READY for Nix build' if ready else 'NEEDS WORK'}")
print("\n".join(report))
sys.exit(0 if ready else 1)
