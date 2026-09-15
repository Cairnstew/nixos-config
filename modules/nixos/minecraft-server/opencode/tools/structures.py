#!/usr/bin/env python3
"""Structures CLI — consistently list every worldgen structure and structure set
a packwiz modpack will generate.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the PINNED mod
jars (checksums.json — exactly what players get), the pack's own datapacks, and
the vanilla baseline for the pack's Minecraft version. Full-pack scans cache
downloaded jars by checksum so re-runs are instant.

Usage (manual):
  python3 structures.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                               [--json] [--list] [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla structures/sets baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the structure ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only game-added ones.
  --full-export [f] write every structure's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-structures-full.json.
                    Single-scan, single-pass — reuses the in-memory index.

Default human output mirrors packwiz-structures: per-source sections (vanilla
baseline, each mod jar, each datapack) then a cross-source summary. Everything
is sorted, and the jar cache means identical inputs produce byte-identical
output — that is the "consistent" guarantee.

Why "ALL": the scan covers every structure DEFINED IN JSON in the pack's
datapacks (each mod jar is a datapack when loaded; the pack's own Paxi/data)
PLUS the vanilla structures for the pack's MC version, so villages, strongholds,
mansions etc. are listed instead of being implied. Two real-world gaps are
reported, never hidden:
  - structures registered purely in Java (custom `type`, e.g. ae2:ae2mtrt) have
    no JSON definition; unless a JSON set references them they show up under
    "NOT in any set (code-driven?)" and are enumerated under custom_types.
  - a live-game registry can only be dumped from a running client/server; this
    tool is offline and deterministic by design.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/structures.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-structures opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.

The vanilla baseline is an embedded table for supported MC versions (currently
1.21.1: 34 structures / 20 sets, extracted from Mojang's client jar). To add a
version, fetch Mojang's client jar for it, unzip, and rebuild VANILLA_BY_MC
from data/minecraft/worldgen/structure/*.json and data/minecraft/worldgen/
structure_set/*.json (see the footer of this script for the exact recipe).
"""

import os
import re
import sys
import json
import shutil
import zipfile
import tempfile
import subprocess
import urllib.request

VANILLA_BY_MC = {"1.21.1":{"sets":{"ancient_cities":["minecraft:ancient_city"],"buried_treasures":["minecraft:buried_treasure"],"desert_pyramids":["minecraft:desert_pyramid"],"end_cities":["minecraft:end_city"],"igloos":["minecraft:igloo"],"jungle_temples":["minecraft:jungle_pyramid"],"mineshafts":["minecraft:mineshaft","minecraft:mineshaft_mesa"],"nether_complexes":["minecraft:fortress","minecraft:bastion_remnant"],"nether_fossils":["minecraft:nether_fossil"],"ocean_monuments":["minecraft:monument"],"ocean_ruins":["minecraft:ocean_ruin_cold","minecraft:ocean_ruin_warm"],"pillager_outposts":["minecraft:pillager_outpost"],"ruined_portals":["minecraft:ruined_portal","minecraft:ruined_portal_desert","minecraft:ruined_portal_jungle","minecraft:ruined_portal_swamp","minecraft:ruined_portal_mountain","minecraft:ruined_portal_ocean","minecraft:ruined_portal_nether"],"shipwrecks":["minecraft:shipwreck","minecraft:shipwreck_beached"],"strongholds":["minecraft:stronghold"],"swamp_huts":["minecraft:swamp_hut"],"trail_ruins":["minecraft:trail_ruins"],"trial_chambers":["minecraft:trial_chambers"],"villages":["minecraft:village_plains","minecraft:village_desert","minecraft:village_savanna","minecraft:village_snowy","minecraft:village_taiga"],"woodland_mansions":["minecraft:mansion"]},"structures":{"ancient_city":{"biomes":"#minecraft:has_structure/ancient_city","type":"minecraft:jigsaw"},"bastion_remnant":{"biomes":"#minecraft:has_structure/bastion_remnant","type":"minecraft:jigsaw"},"buried_treasure":{"biomes":"#minecraft:has_structure/buried_treasure","type":"minecraft:buried_treasure"},"desert_pyramid":{"biomes":"#minecraft:has_structure/desert_pyramid","type":"minecraft:desert_pyramid"},"end_city":{"biomes":"#minecraft:has_structure/end_city","type":"minecraft:end_city"},"fortress":{"biomes":"#minecraft:has_structure/nether_fortress","type":"minecraft:fortress"},"igloo":{"biomes":"#minecraft:has_structure/igloo","type":"minecraft:igloo"},"jungle_pyramid":{"biomes":"#minecraft:has_structure/jungle_temple","type":"minecraft:jungle_temple"},"mansion":{"biomes":"#minecraft:has_structure/woodland_mansion","type":"minecraft:woodland_mansion"},"mineshaft":{"biomes":"#minecraft:has_structure/mineshaft","type":"minecraft:mineshaft"},"mineshaft_mesa":{"biomes":"#minecraft:has_structure/mineshaft_mesa","type":"minecraft:mineshaft"},"monument":{"biomes":"#minecraft:has_structure/ocean_monument","type":"minecraft:ocean_monument"},"nether_fossil":{"biomes":"#minecraft:has_structure/nether_fossil","type":"minecraft:nether_fossil"},"ocean_ruin_cold":{"biomes":"#minecraft:has_structure/ocean_ruin_cold","type":"minecraft:ocean_ruin"},"ocean_ruin_warm":{"biomes":"#minecraft:has_structure/ocean_ruin_warm","type":"minecraft:ocean_ruin"},"pillager_outpost":{"biomes":"#minecraft:has_structure/pillager_outpost","type":"minecraft:jigsaw"},"ruined_portal":{"biomes":"#minecraft:has_structure/ruined_portal_standard","type":"minecraft:ruined_portal"},"ruined_portal_desert":{"biomes":"#minecraft:has_structure/ruined_portal_desert","type":"minecraft:ruined_portal"},"ruined_portal_jungle":{"biomes":"#minecraft:has_structure/ruined_portal_jungle","type":"minecraft:ruined_portal"},"ruined_portal_mountain":{"biomes":"#minecraft:has_structure/ruined_portal_mountain","type":"minecraft:ruined_portal"},"ruined_portal_nether":{"biomes":"#minecraft:has_structure/ruined_portal_nether","type":"minecraft:ruined_portal"},"ruined_portal_ocean":{"biomes":"#minecraft:has_structure/ruined_portal_ocean","type":"minecraft:ruined_portal"},"ruined_portal_swamp":{"biomes":"#minecraft:has_structure/ruined_portal_swamp","type":"minecraft:ruined_portal"},"shipwreck":{"biomes":"#minecraft:has_structure/shipwreck","type":"minecraft:shipwreck"},"shipwreck_beached":{"biomes":"#minecraft:has_structure/shipwreck_beached","type":"minecraft:shipwreck"},"stronghold":{"biomes":"#minecraft:has_structure/stronghold","type":"minecraft:stronghold"},"swamp_hut":{"biomes":"#minecraft:has_structure/swamp_hut","type":"minecraft:swamp_hut"},"trail_ruins":{"biomes":"#minecraft:has_structure/trail_ruins","type":"minecraft:jigsaw"},"trial_chambers":{"biomes":"#minecraft:has_structure/trial_chambers","type":"minecraft:jigsaw"},"village_desert":{"biomes":"#minecraft:has_structure/village_desert","type":"minecraft:jigsaw"},"village_plains":{"biomes":"#minecraft:has_structure/village_plains","type":"minecraft:jigsaw"},"village_savanna":{"biomes":"#minecraft:has_structure/village_savanna","type":"minecraft:jigsaw"},"village_snowy":{"biomes":"#minecraft:has_structure/village_snowy","type":"minecraft:jigsaw"},"village_taiga":{"biomes":"#minecraft:has_structure/village_taiga","type":"minecraft:jigsaw"}}}}

# Vanilla structure placement types (derived from the embedded table): code
# structures vs data-driven ones. Any structure whose `type` is NOT one of these
# is registered in Java (mod code) — its set may be registered in code too.
def _vanilla_types():
    types = set()
    for ver in VANILLA_BY_MC.values():
        for s in ver["structures"].values():
            types.add(s["type"])
    return types

VANILLA_TYPES = _vanilla_types()

# ── small packwiz helpers (kept local so this file is self-contained) ────────

def die(msg):
    sys.stderr.write(f"structures.py: {msg}\n")
    sys.exit(1)


def repo_root():
    """Git top-level from the cwd, else the script's own ancestor repo (so the
    tool works when invoked from anywhere, not just inside the repo)."""
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, cwd=os.getcwd())
    if out.returncode == 0:
        return out.stdout.strip()
    here = os.path.abspath(os.path.dirname(__file__))
    # tools/ -> opencode/ -> minecraft-server/ -> nixos/ -> modules/ -> repo
    for _ in range(5):
        here = os.path.dirname(here)
    if os.path.exists(os.path.join(here, "flake.nix")):
        return here
    return os.getcwd()


def mc_version(pack_dir):
    p = os.path.join(pack_dir, "pack.toml")
    if not os.path.exists(p):
        return None
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', open(p).read(), re.M)
    return m.group(1) if m else None


def _jar_cache():
    d = os.path.join(tempfile.gettempdir(), "mc-pack-jars")
    os.makedirs(d, exist_ok=True)
    return d


def cached_jar(entry):
    """Pinned jar to a local file (cached by sha256). Returns (path, downloaded)."""
    sha = entry.get("sha256")
    if sha:
        safe = re.sub(r"[^A-Za-z0-9_.-]", "_", sha)
        local = os.path.join(_jar_cache(), safe)
        if os.path.exists(local):
            return local, False
        tmp = local + ".tmp"
        urllib.request.urlretrieve(entry["url"], tmp)
        os.replace(tmp, local)
        return local, True
    tmp = tempfile.mkdtemp(prefix="mc-jar-")
    local = os.path.join(tmp, "mod.jar")
    urllib.request.urlretrieve(entry["url"], local)
    return local, True


def find_mod_jars(pack_dir):
    """A dict of every alias -> {pw_toml, url?, sha256?} for the pack's mods."""
    mods_dir = os.path.join(pack_dir, "mods")
    out = {}
    cs = {}
    cs_path = os.path.join(pack_dir, "checksums.json")
    if os.path.exists(cs_path):
        with open(cs_path) as fh:
            cs = json.load(fh)
    if not os.path.isdir(mods_dir):
        return out
    for f in sorted(os.listdir(mods_dir)):
        if not f.endswith(".pw.toml"):
            continue
        txt = open(os.path.join(mods_dir, f)).read()
        slug = None
        m = re.search(r'^name\s*=\s*"([^"]+)"', txt, re.M)
        if m:
            slug = m.group(1).lower()
        url = None
        dm = re.search(r"^\[download\]\s*\n(.*?)(?=\n\[|\Z)", txt, re.S | re.M)
        if dm:
            um = re.search(r'^url\s*=\s*"([^"]+)"', dm.group(1), re.M)
            if um:
                url = um.group(1)
        entry = {"pw_toml": f}
        if url:
            entry["url"] = url
        if f in cs:
            entry["sha256"] = cs[f].get("sha256")
            if not url and cs[f].get("url"):
                entry["url"] = cs[f]["url"]
        fstem = f[:-8].lower()
        jarstem = None
        fm = re.search(r'^filename\s*=\s*"([^"]+)"', txt, re.M)
        if fm:
            jarstem = os.path.splitext(os.path.basename(fm.group(1)))[0].lower()
        out[slug or fstem] = entry
        if slug and slug != fstem:
            out.setdefault(fstem, entry)
        if jarstem:
            out.setdefault(jarstem, entry)
    return out


def resolve_mod(mods, target):
    tl = target.lower()
    if tl in mods:
        return tl
    matches = [k for k in mods if tl in k or k in tl]
    if len(matches) == 1:
        return matches[0]
    if len(matches) > 1:
        # Prefer a key that is exactly the target plus a version/qualifier suffix
        # (e.g. 'reliquified_artifacts-1.21.1-1.0.8' for 'reliquified_artifacts')
        # over a key the target merely contains ('artifacts' in 'reliquified_artifacts').
        prefixed = [k for k in matches if k.startswith(tl)]
        if len(prefixed) == 1:
            return prefixed[0]
        die(f"ambiguous '{target}' — matches {sorted(matches)}; pass a unique slug or .pw.toml filename")
    return None


def scan_worldgen(zf, raw=False):
    """Scan a jar/datapack zip. Returns (structures, sets) dicts keyed by full
    "<ns>:<name>" ids. mirror of mc-pack.py so outputs match historical runs.
    When raw=True, each structure dict includes a "raw" key with the full
    parsed JSON (for --info lookups)."""
    structures, sets = {}, {}
    for n in zf.namelist():
        m = re.match(r"^data/([^/]+)/worldgen/structure/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:
                data = {}
            biomes = data.get("biomes", "")
            if isinstance(biomes, list):
                biomes = ",".join(biomes)
            entry = {
                "type": data.get("type", "?"),
                "biomes": biomes or "",
            }
            if raw:
                entry["raw"] = data
            structures[f"{ns}:{name}"] = entry
            continue
        m = re.match(r"^data/([^/]+)/worldgen/structure_set/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:
                data = {}
            sets[f"{ns}:{name}"] = [s.get("structure", "?") for s in data.get("structures", [])]
            continue
    return structures, sets


def dir_to_zip(d):
    """Zip a datapack directory into a temp file so dir and zip datapacks scan
    identically. Caller removes the temp dir."""
    tmp = tempfile.mkdtemp(prefix="mc-dp-")
    zip_path = os.path.join(tmp, "dp.zip")
    with zipfile.ZipFile(zip_path, "w") as zf:
        for root, _, files in os.walk(d):
            for f in files:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, d)
                zf.write(full, rel)
    return tmp, zip_path


def paxi_dir(pack_dir):
    return os.path.join(pack_dir, "config", "paxi", "datapacks")


# ── pack resolution ───────────────────────────────────────────────────────────

def resolve_pack_dir(pack_arg):
    if os.path.isdir(pack_arg):
        return os.path.abspath(pack_arg)
    base = os.path.abspath(pack_arg)
    if os.path.isdir(base):
        return base
    cands = [
        os.path.join(repo_root(), "modules", "nixos", "minecraft-server", "modpacks", pack_arg),
        os.path.join(os.getcwd(), pack_arg),
    ]
    for c in cands:
        if os.path.isdir(c):
            return c
    d = os.path.join(repo_root(), "modules", "nixos", "minecraft-server", "modpacks")
    if os.path.isdir(d):
        for name in sorted(os.listdir(d)):
            if name.lower() == pack_arg.lower() and os.path.isdir(os.path.join(d, name)):
                return os.path.join(d, name)
    die(f"can't find packwiz pack '{pack_arg}' (tried paths and the repo's modpacks/)")
    return None


def read_pack_info(pack_dir):
    info = {"name": os.path.basename(pack_dir.rstrip("/")), "dir": pack_dir,
            "minecraft": None, "loader": None, "loader_version": None}
    p = os.path.join(pack_dir, "pack.toml")
    if not os.path.exists(p):
        die(f"{pack_dir} is not a packwiz pack (no pack.toml)")
    txt = open(p).read()
    m = re.search(r'^minecraft\s*=\s*"([^"]+)"', txt, re.M)
    if m:
        info["minecraft"] = m.group(1)
    for loader in ("neoforge", "forge", "fabric", "quilt"):
        m = re.search(rf"^{loader}\s*=\s*\"([^\"]+)\"", txt, re.M)
        if m:
            info["loader"], info["loader_version"] = loader, m.group(1)
            break
    return info


# ── info helpers ───────────────────────────────────────────────────────────────

def jigsaw_pools(raw_json):
    """Extract template pool references from a jigsaw structure JSON.
    Returns a sorted list of pool IDs (e.g. minecraft:villages/common/...)."""
    if not raw_json:
        return []
    pools = []
    sp = raw_json.get("start_pool")
    if isinstance(sp, str):
        pools.append(sp)
    elif isinstance(sp, list):
        pools.extend(sp)
    for step in raw_json.get("step_pools") or []:
        if isinstance(step, str):
            pools.append(step)
        elif isinstance(step, list):
            pools.extend(step)
    return sorted(set(pools))


def raw_json_from_source(source, struct_id):
    """Pull the raw structure JSON from a source (jar zip or dir datapack).
    Returns parsed dict or None."""
    data = source["structures"].get(struct_id)
    if not data or not data.get("raw"):
        return None
    return data["raw"]


def fuzzy_match(target, known_ids, max_results=5):
    """Cheap fuzzy match using difflib.SequenceMatcher (handles transpositions).
    Returns a list of close matches sorted by relevance."""
    import difflib
    t = target.lower()
    t_short = t.split(":")[-1] if ":" in t else t
    scored = []
    for sid in known_ids:
        s = sid.lower()
        s_short = s.split(":")[-1] if ":" in s else s
        # Exact match on full id or short name — caller should check first
        if t == s or t_short == s_short:
            return []
        # SequenceMatcher ratio on the short names (transposition-aware)
        ratio = difflib.SequenceMatcher(None, t_short, s_short).ratio()
        if ratio >= 0.6:
            scored.append((ratio, sid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [sid for _, sid in scored[:max_results]]


# ── scanning ──────────────────────────────────────────────────────────────────

def scan_vanilla(info):
    ver = info.get("minecraft")
    if not ver or ver not in VANILLA_BY_MC:
        return None, f"no embedded vanilla table for MC {ver} (tables: {', '.join(sorted(VANILLA_BY_MC)) or 'none'})"
    vt = VANILLA_BY_MC[ver]
    structures = {f"minecraft:{k}": {"type": v["type"], "biomes": v["biomes"],
                                     "minecraft": True} for k, v in vt["structures"].items()}
    sets = {f"minecraft:{k}": [s if ":" in s else f"minecraft:{s}" for s in v]
            for k, v in vt["sets"].items()}
    return {"kind": "vanilla", "name": f"vanilla {ver} baseline", "jar": None,
            "structures": structures, "sets": sets}, None


def scan_mods(pack_dir, info, want_mods=None, skipped=None, raw=False):
    mods = find_mod_jars(pack_dir)
    by_toml = {}
    for k, e in mods.items():
        by_toml.setdefault(e["pw_toml"], []).append(k)
    selected = []
    if want_mods:
        for t in want_mods:
            k = resolve_mod(mods, t)
            if k is None:
                die(f"no mod '{t}' in pack (unique mod ids: {', '.join(sorted(by_toml))[:400]})")
            toml = mods[k]["pw_toml"]
            if toml not in selected:
                selected.append(toml)
    else:
        selected = sorted(set(e["pw_toml"] for e in mods.values()))

    sources = []
    dl = from_cache = 0
    for toml in selected:
        entry = mods[by_toml[toml][0]]
        if not entry.get("url"):
            skipped.append(toml)
            continue
        local, was_dl = cached_jar(entry)
        if was_dl:
            dl += 1
        else:
            from_cache += 1
        with zipfile.ZipFile(local) as zf:
            structures, sets = scan_worldgen(zf, raw=raw)
        sources.append({
            "kind": "mod",
            "name": by_toml[toml][0],
            "jar": entry["url"].rsplit("/", 1)[-1],
            "structures": structures,
            "sets": sets,
        })
    return sources, dl, from_cache


def scan_datapacks(pack_dir, skipped_dp=None, raw=False):
    sources = []
    dp_root = paxi_dir(pack_dir)
    if os.path.isdir(dp_root):
        for name in sorted(os.listdir(dp_root)):
            p = os.path.join(dp_root, name)
            if os.path.isdir(p):
                tmp, zip_path = dir_to_zip(p)
                try:
                    with zipfile.ZipFile(zip_path) as zf:
                        structures, sets = scan_worldgen(zf, raw=raw)
                finally:
                    shutil.rmtree(tmp, ignore_errors=True)
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}/",
                                "jar": None, "structures": structures, "sets": sets})
            elif name.endswith(".zip"):
                try:
                    with zipfile.ZipFile(p) as zf:
                        structures, sets = scan_worldgen(zf, raw=raw)
                except zipfile.BadZipFile:
                    if skipped_dp is not None:
                        skipped_dp.append(f"{name}: not a valid zip")
                    continue
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}",
                                "jar": None, "structures": structures, "sets": sets})
    data_dir = os.path.join(pack_dir, "data")
    if os.path.isdir(data_dir):
        tmp, zip_path = dir_to_zip(data_dir)
        try:
            with zipfile.ZipFile(zip_path) as zf:
                structures, sets = scan_worldgen(zf, raw=raw)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        sources.append({"kind": "datapack", "name": "<pack>/data/",
                        "jar": None, "structures": structures, "sets": sets})
    return sources


# ── summary ───────────────────────────────────────────────────────────────────

def build_summary(sources, dl, from_cache, skipped, skipped_dp):
    all_structs, all_sets = {}, {}
    for src in sources:
        all_structs.update(src["structures"])
        all_sets.update(src["sets"])
    refd = {m for members in all_sets.values() for m in members}
    unreferenced = sorted(k for k in all_structs if k not in refd)
    referenced_missing = sorted(k for k in refd if k not in all_structs)

    vanilla_structs = {}
    for src in sources:
        if src["kind"] != "vanilla":
            continue
        vanilla_structs.update(src["structures"])
    vanilla_set_names = set()
    for src in sources:
        if src["kind"] != "vanilla":
            continue
        vanilla_set_names.update(src["sets"])

    # minecraft:-namespace structures the pack (mods/datapacks) redefine vs add.
    vanilla_overrides = []
    vanilla_namespace_additions = []
    for src in sources:
        if src["kind"] == "vanilla":
            continue
        for sid in src["structures"]:
            if not sid.startswith("minecraft:"):
                continue
            if sid in vanilla_structs:
                if sid not in vanilla_overrides:
                    vanilla_overrides.append(sid)
            elif sid not in vanilla_namespace_additions:
                vanilla_namespace_additions.append(sid)
    vanilla_overrides.sort()
    vanilla_namespace_additions.sort()
    vanilla_set_overrides = sorted(
        sid for sid in all_sets if sid.startswith("minecraft:") and sid in vanilla_set_names
        and any(src["kind"] != "vanilla" and sid in src["sets"] for src in sources)
    )

    # Structures with a non-vanilla placement type -> registered in Java; the
    # JSON only declares biomes/type, and the set may be registered in code.
    custom = {}
    for src in sources:
        if src["kind"] == "vanilla":
            continue
        for sid, s in src["structures"].items():
            if s["type"] not in VANILLA_TYPES and not s["type"].startswith("minecraft:"):
                custom.setdefault(s["type"], []).append(sid)
    custom = {t: sorted(v) for t, v in sorted(custom.items())}

    return {
        "sources": sources,
        "all_structures": all_structs,
        "all_sets": all_sets,
        "total_structures": len(all_structs),
        "total_sets": len(all_sets),
        "jars_downloaded": dl,
        "jars_from_cache": from_cache,
        "skipped_no_url": sorted(skipped),
        "skipped_datapacks": sorted(skipped_dp),
        "unreferenced": unreferenced,
        "referenced_missing": referenced_missing,
        "vanilla_overrides": vanilla_overrides,
        "vanilla_namespace_additions": vanilla_namespace_additions,
        "vanilla_set_overrides": vanilla_set_overrides,
        "custom_types": custom,
    }


# ── output ────────────────────────────────────────────────────────────────────

def fmt_biomes(b):
    return b or "?"


def report_human(info, summ):
    srcs = summ["sources"]
    print(f"## pack {info['name']}  (MC {info['minecraft'] or '?'}, "
          f"{info['loader'] or '?'} {info['loader_version'] or ''})".strip())
    for src in srcs:
        if not src["structures"] and not src["sets"]:
            continue
        print(f"## source: {src['name']}" + (f"  ({src['jar']})" if src["jar"] else ""))
        for sid in sorted(src["structures"]):
            s = src["structures"][sid]
            extra = ""
            if src["kind"] != "vanilla" and sid in summ["vanilla_overrides"]:
                extra = "  [OVERRIDES VANILLA — replaces the vanilla structure]"
            elif src["kind"] != "vanilla" and sid in summ["vanilla_namespace_additions"]:
                extra = "  [new in minecraft: namespace — not a vanilla structure]"
            print(f"  structure  {sid}  (type={s['type']}, biomes={fmt_biomes(s['biomes'])}){extra}")
        for sid in sorted(src["sets"]):
            members = src["sets"][sid]
            extra = ""
            if src["kind"] != "vanilla" and sid in summ["vanilla_set_overrides"]:
                extra = "  [VANILLA SET NAME — this replaces/overrides the vanilla placement]"
            print(f"  set        {sid}  ->  {', '.join(members) or '(empty)'}{extra}")

    print()
    print(f"## summary ({summ['jars_downloaded']} jar{'s' if summ['jars_downloaded'] != 1 else ''} downloaded, {summ['jars_from_cache']} from cache)")
    print(f"  total structures:     {summ['total_structures']}")
    print(f"  total structure sets: {summ['total_sets']}")
    if summ["skipped_no_url"]:
        print(f"  SKIPPED (no download URL — CurseForge-mode?): {', '.join(summ['skipped_no_url'])}")
    if summ["skipped_datapacks"]:
        print(f"  SKIPPED datapacks: {', '.join(summ['skipped_datapacks'])}")
    if summ["unreferenced"]:
        print(f"  structures NOT in any set (never spawn via sets — likely fine, "
              f"set-driven via code): {len(summ['unreferenced'])}")
        for s in summ["unreferenced"][:15]:
            print(f"    - {s}")
        if len(summ["unreferenced"]) > 15:
            print(f"    … ({len(summ['unreferenced']) - 15} more)")
    if summ["referenced_missing"]:
        print(f"  sets reference MISSING structures (not defined by vanilla/mods/datapacks): "
              f"{', '.join(summ['referenced_missing'])}")
    if summ["vanilla_overrides"]:
        print(f"  vanilla structures the pack redefines: {len(summ['vanilla_overrides'])}")
        for v in summ["vanilla_overrides"]:
            print(f"    - {v}")
    if summ["vanilla_namespace_additions"]:
        print(f"  NEW minecraft:-namespace structures (pack adds, vanilla has none): "
              f"{', '.join(summ['vanilla_namespace_additions'])}")
    if summ["vanilla_set_overrides"]:
        print(f"  vanilla SET names redefined (pack overrides placement): "
              f"{', '.join(summ['vanilla_set_overrides'])}")
    if summ["custom_types"]:
        n_custom = sum(len(v) for v in summ["custom_types"].values())
        print(f"  code-registered structure types ({n_custom} structures): "
              f"{', '.join(summ['custom_types'])}")


def report_json(info, summ):
    out = {
        "tool": "structures.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s["jar"],
             "structures": {k: {"type": v["type"], "biomes": v["biomes"]}
                            for k, v in sorted(s["structures"].items())},
             "sets": {k: v for k, v in sorted(s["sets"].items())}}
            for s in summ["sources"]
        ],
        "summary": {
            "total_structures": summ["total_structures"],
            "total_sets": summ["total_sets"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "unreferenced": summ["unreferenced"],
            "referenced_missing": summ["referenced_missing"],
            "vanilla_overrides": summ["vanilla_overrides"],
            "vanilla_namespace_additions": summ["vanilla_namespace_additions"],
            "vanilla_set_overrides": summ["vanilla_set_overrides"],
            "custom_types": summ["custom_types"],
        },
    }
    json.dump(out, sys.stdout, indent=2, sort_keys=True)
    print()


def cmd_info(pack_dir, info, target, as_json):
    """Look up a single structure ID and report all known metadata."""
    sources = []
    skip_no_url = []
    skip_dp = []
    v_src, v_note = scan_vanilla(info)
    if v_src:
        sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, None, skip_no_url, raw=True)
    sources += mod_sources
    sources += scan_datapacks(pack_dir, skip_dp, raw=True)

    # Also build a vanilla scan_worldgen for raw JSON extraction
    v_raw = None
    if v_src:
        ver = info.get("minecraft")
        vt = VANILLA_BY_MC.get(ver, {})
        # Reconstruct as a zip-like structure for raw extraction
        v_structures = {}
        for k, v in vt.get("structures", {}).items():
            v_structures[f"minecraft:{k}"] = {"type": v["type"], "biomes": v["biomes"]}
        # Build raw JSON from the vanilla table entry
        for sid in list(v_structures.keys()):
            bare = sid.split(":", 1)[1]
            raw_entry = vt.get("structures", {}).get(bare, {})
            v_structures[sid]["raw"] = raw_entry

    # Normalize the target id
    if ":" not in target:
        target = f"minecraft:{target}"

    # Find the structure across all sources
    found = False
    result = {}
    for src in sources:
        if target in src["structures"]:
            found = True
            s = src["structures"][target]
            result["id"] = target
            result["type"] = s["type"]
            result["biomes"] = s.get("biomes", "")
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            # Pull raw JSON from the zip if available
            if s.get("raw"):
                result["raw"] = s["raw"]
            break

    if not found:
        # Collect all known IDs for fuzzy matching
        all_ids = set()
        for src in sources:
            all_ids.update(src["structures"].keys())
        suggest = fuzzy_match(target, all_ids)
        msg = f"structure '{target}' not found in any source"
        if suggest:
            msg += f" — did you mean: {', '.join(suggest)}"
        die(msg)

    # Determine sets that reference this structure
    result["sets"] = []
    for src in sources:
        for set_id, members in src.get("sets", {}).items():
            if target in members:
                result["sets"].append({"set_id": set_id, "source": src["name"]})

    # Vanilla override / redefinition status
    result["vanilla_override"] = False
    result["vanilla_redefined"] = False
    result["vanilla_namespace_addition"] = False
    if target.startswith("minecraft:"):
        v_structs = v_raw if v_raw else {}
        if v_src and target in v_src["structures"]:
            # Check if any non-vanilla source also defines it (overrides vanilla)
            for src in sources:
                if src["kind"] != "vanilla" and target in src["structures"]:
                    result["vanilla_override"] = True
                    break
        elif v_src and target not in v_src["structures"]:
            # minecraft: namespace but not in vanilla — new addition
            result["vanilla_namespace_addition"] = True

    # Code-registered type?
    result["code_registered"] = result["type"] not in VANILLA_TYPES and not result["type"].startswith("minecraft:")

    # Jigsaw pools
    result["jigsaw_pools"] = jigsaw_pools(result.get("raw")) if result["type"] == "minecraft:jigsaw" else []

    if as_json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        print()
        return

    # Human-readable output
    print(f"## structure: {result['id']}")
    print(f"  type:       {result['type']}")
    if result["code_registered"]:
        print(f"              (code-registered — placement rules in mod Java, not datapacks)")
    print(f"  biomes:     {result['biomes'] or '?'}")
    print(f"  source:     {result['source_kind']}: {result['source_name']}"
          + (f"  ({result['source_jar']})" if result["source_jar"] else ""))
    if result["vanilla_override"]:
        print(f"  override:   YES — replaces the vanilla structure (mod redefines minecraft:{target.split(':',1)[1]})")
    if result["vanilla_namespace_addition"]:
        print(f"  new in minecraft: namespace — not a vanilla structure (pack adds it)")
    if result["sets"]:
        print(f"  sets:       {len(result['sets'])} referencing set(s)")
        for entry in result["sets"]:
            print(f"              - {entry['set_id']}  (from {entry['source']})")
    else:
        print(f"  sets:       NOT IN ANY SET (unreferenced — set may be registered in code)")
    if result["jigsaw_pools"]:
        print(f"  jigsaw pools:")
        for pool in result["jigsaw_pools"]:
            print(f"    - {pool}")
    if result.get("raw"):
        print(f"  raw JSON:")
        print(json.dumps(result["raw"], indent=4, sort_keys=True))


def _format_structure_detail(target_id, sources, v_src, v_raw):
    """Build the detail dict for a single structure across all sources."""
    result = {}
    for src in sources:
        if target_id in src["structures"]:
            s = src["structures"][target_id]
            result["id"] = target_id
            result["type"] = s["type"]
            result["biomes"] = s.get("biomes", "")
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            if s.get("raw"):
                result["raw"] = s["raw"]
            break
    # Sets that reference this structure
    result["sets"] = []
    for src in sources:
        for set_id, members in src.get("sets", {}).items():
            if target_id in members:
                result["sets"].append({"set_id": set_id, "source": src["name"]})
    # Vanilla override / redefinition status
    result["vanilla_override"] = False
    result["vanilla_redefined"] = False
    result["vanilla_namespace_addition"] = False
    if target_id.startswith("minecraft:"):
        if v_src and target_id in v_src["structures"]:
            for src in sources:
                if src["kind"] != "vanilla" and target_id in src["structures"]:
                    result["vanilla_override"] = True
                    break
        elif v_src and target_id not in v_src["structures"]:
            result["vanilla_namespace_addition"] = True
    result["code_registered"] = result.get("type", "") not in VANILLA_TYPES and not result.get("type", "").startswith("minecraft:")
    result["jigsaw_pools"] = jigsaw_pools(result.get("raw")) if result.get("type") == "minecraft:jigsaw" else []
    return result


def cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_):
    """Export every structure's full metadata to a single JSON file."""
    import time
    t0 = time.monotonic()

    sources = []
    skip_no_url = []
    skip_dp = []
    v_src = None
    if scan_vanilla_:
        v_src, _ = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, want_mods, skip_no_url, raw=True)
    sources += mod_sources
    if scan_dp:
        sources += scan_datapacks(pack_dir, skip_dp, raw=True)

    # Build vanilla raw for jigsaw pool extraction
    v_raw = None
    if v_src:
        ver = info.get("minecraft")
        vt = VANILLA_BY_MC.get(ver, {})
        v_structures = {}
        for k, v in vt.get("structures", {}).items():
            v_structures[f"minecraft:{k}"] = {"type": v["type"], "biomes": v["biomes"]}
        for sid in list(v_structures.keys()):
            bare = sid.split(":", 1)[1]
            raw_entry = vt.get("structures", {}).get(bare, {})
            v_structures[sid]["raw"] = raw_entry
        v_raw = v_structures

    all_ids = set()
    for src in sources:
        all_ids.update(src["structures"].keys())

    t_scan = time.monotonic()

    entries = {}
    for sid in sorted(all_ids):
        entries[sid] = _format_structure_detail(sid, sources, v_src, v_raw)

    t_detail = time.monotonic()

    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    out = {
        "tool": "structures.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "structure_count": len(s["structures"]),
             "set_count": len(s.get("sets", {}))}
            for s in summ["sources"]
        ],
        "summary": {
            "total_structures": summ["total_structures"],
            "total_sets": summ["total_sets"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
        },
        "entries": entries,
    }

    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")

    t_write = time.monotonic()
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {len(entries)} structures → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
    print(f"  scan: {t_scan-t0:.1f}s  detail: {t_detail-t_scan:.1f}s  write: {t_write-t_detail:.1f}s  total: {t_write-t0:.1f}s", file=sys.stderr)


def main():
    args = sys.argv[1:]
    if not args or args[0] in ("-h", "--help"):
        print(__doc__)
        return
    pack_arg = args[0]
    rest = args[1:]
    want_mods = None
    scan_dp = True
    scan_vanilla_ = True
    as_json = False
    as_list = False
    info_id = None
    full_export = None
    i = 0
    while i < len(rest):
        a = rest[i]
        if a == "--mods" and i + 1 < len(rest):
            want_mods = [s.strip().lower() for s in rest[i + 1].split(",") if s.strip()]
            i += 2
        elif a == "--no-datapacks":
            scan_dp = False; i += 1
        elif a == "--no-vanilla":
            scan_vanilla_ = False; i += 1
        elif a == "--json":
            as_json = True; i += 1
        elif a == "--list":
            as_list = True; i += 1
        elif a == "--info" and i + 1 < len(rest):
            info_id = rest[i + 1]; i += 2
        elif a == "--full-export":
            if i + 1 < len(rest) and not rest[i + 1].startswith("-"):
                full_export = rest[i + 1]; i += 2
            else:
                full_export = True; i += 1
        else:
            die(f"unknown arg {a} (see --help)")

    pack_dir = resolve_pack_dir(pack_arg)
    info = read_pack_info(pack_dir)
    if not os.path.isfile(os.path.join(pack_dir, "checksums.json")):
        die(f"{pack_dir} has no checksums.json — run packwiz-checksums first")

    if info_id:
        cmd_info(pack_dir, info, info_id, as_json)
        return

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-structures-full.json"
        cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_)
        return

    sources = []
    skip_no_url = []
    skip_dp = []
    v_src, v_note = None, None
    if scan_vanilla_:
        v_src, v_note = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
        elif not as_json and not as_list:
            print(f"## note: {v_note}", file=sys.stderr)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, want_mods, skip_no_url)
    sources += mod_sources
    if scan_dp:
        sources += scan_datapacks(pack_dir, skip_dp)

    if as_json:
        summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
        report_json(info, summ)
        return
    if as_list:
        summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
        for sid in sorted(summ["all_structures"]):
            print(sid)
        return
    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    report_human(info, summ)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        # Output piped to head/jq/etc. closed early (e.g. `| head`) — not an
        # error for the caller. Suppress Python's own broken-pipe noise.
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(0)


# ── Vanilla baseline regen recipe ─────────────────────────────────────────────
# VANILLA_BY_MC is embedded so the tool is offline and deterministic. To add a
# Minecraft version (e.g. 1.21.4), download Mojang's client jar for that version
# (under "downloads" -> "client" in https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
# -> the version entry), then:
#
#   python3 - << 'EOF'
#   import zipfile, json, re
#   zf = zipfile.ZipFile("client-<ver>.jar")
#   structs, sets = {}, {}
#   for n in zf.namelist():
#       m = re.match(r"^data/minecraft/worldgen/structure/(.+)\.json$", n)
#       if m:
#           d = json.loads(zf.read(n))
#           structs[m.group(1)] = {"type": d.get("type","?"), "biomes": d.get("biomes","")}
#           continue
#       m = re.match(r"^data/minecraft/worldgen/structure_set/(.+)\.json$", n)
#       if m:
#           sets[m.group(1)] = [s.get("structure","?") for s in json.loads(zf.read(n)).get("structures",[])]
#   print(json.dumps({"structures": structs, "sets": sets}, sort_keys=True))
#   EOF
#
# and paste the output into VANILLA_BY_MC under the new version key.

# ## RUN LOG
# ### 2026-09-06
# Created as the standalone, complete structures enumerator. Fixes the old
# mc-pack.py `structures` gap: vanilla structures/sets were never inventoried
# (only pack redefinitions flagged), minecraft: set refs were skipped instead of
# validated against a baseline, and there was no machine-readable output. Adds
# --json (stable schema for skill/agent wrapping) and --list, plus the embedded
# 1.21.1 vanilla table so "all structures" really means all.
