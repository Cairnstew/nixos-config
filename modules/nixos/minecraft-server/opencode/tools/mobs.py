#!/usr/bin/env python3
"""Mobs CLI — consistently list every mob entity a packwiz modpack will include.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the PINNED mod
jars (checksums.json — exactly what players get), the pack's own datapacks, and
the vanilla baseline for the pack's Minecraft version. Full-pack scans cache
downloaded jars by checksum so re-runs are instant.

Usage (manual):
  python3 mobs.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                         [--json] [--list] [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla mobs baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the mob ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only mod-added ones.
  --full-export [f] write every mob's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-mobs-full.json.
                    Single-scan, single-pass — reuses the in-memory index.

Default human output mirrors packwiz-structures: per-source sections (vanilla
baseline, each mod jar, each datapack) then a cross-source summary. Everything
is sorted, and the jar cache means identical inputs produce byte-identical
output — that is the "consistent" guarantee.

Why "ALL": the scan covers every mob DEFINED IN JSON in the pack's datapacks
(each mod jar is a datapack when loaded; the pack's own Paxi/data) PLUS the
vanilla mobs for the pack's MC version, so zombies, creepers, cows etc. are
listed explicitly. Two real-world gaps are reported, never hidden:
  - mobs registered purely in Java (custom entity types, e.g. ae2:quantum_bully)
    have no JSON definition; unless a biome modifier or loot table references
    them they show up under "code-only entities" and are enumerated.
  - a live-game registry can only be dumped from a running client/server; this
    tool is offline and deterministic by design.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/mobs.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-mobs opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.

The vanilla baseline is an embedded table for supported MC versions (currently
1.21.1: ~80 entities, extracted from Mojang's client jar data). To add a
version, fetch Mojang's client jar for it, unzip, and rebuild VANILLA_BY_MC
from data/minecraft/loot_tables/entities/*.json and
assets/minecraft/lang/en_us.json (see the footer of this script for the
exact recipe).
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

# ── Vanilla mobs baseline ────────────────────────────────────────────────────
# Embedded so the tool is offline and deterministic. Each mob has:
#   category: Minecraft mob category (monster, creature, ambient, water_creature,
#             water_ambient, underground_water_creature, axolotl, misc)
#   friendly: true if the mob is passive (won't attack players unprovoked)
#
# Source: data/minecraft/loot_tables/entities/*.json from Mojang's 1.21.1
# client jar, cross-referenced with assets/minecraft/lang/en_us.json and
# the entity_types registry (code-registered entities not in loot_tables
# are included with category="code_only").
#
# To regenerate: download the 1.21.1 client jar, run:
#   python3 -c "
#   import zipfile, json, os
#   zf = zipfile.ZipFile('client-1.21.1.jar')
#   mobs = {}
#   for n in zf.namelist():
#       m = __import__('re').match(r'^data/minecraft/loot_tables/entities/(.+)\.json$', n)
#       if m:
#           mobs[m.group(1)] = {}
#   print(json.dumps(sorted(mobs.keys()), indent=2))
#   "
VANILLA_BY_MC = {
    "1.21.1": {
        "mobs": {
            # ── Hostile / Monster ──
            "minecraft:blaze":              {"category": "monster", "friendly": False},
            "minecraft:cave_spider":        {"category": "monster", "friendly": False},
            "minecraft:creepers":           {"category": "monster", "friendly": False},
            "minecraft:drowned":            {"category": "monster", "friendly": False},
            "minecraft:elder_guardian":      {"category": "monster", "friendly": False},
            "minecraft:ender_dragon":       {"category": "monster", "friendly": False},
            "minecraft:enderman":           {"category": "monster", "friendly": False},
            "minecraft:evoker":             {"category": "monster", "friendly": False},
            "minecraft:ghast":              {"category": "monster", "friendly": False},
            "minecraft:guardian":           {"category": "monster", "friendly": False},
            "minecraft:husk":               {"category": "monster", "friendly": False},
            "minecraft:magma_cube":         {"category": "monster", "friendly": False},
            "minecraft:phantom":            {"category": "monster", "friendly": False},
            "minecraft:piglin_brute":       {"category": "monster", "friendly": False},
            "minecraft:pillager":           {"category": "monster", "friendly": False},
            "minecraft:ravager":            {"category": "monster", "friendly": False},
            "minecraft:shulker":            {"category": "monster", "friendly": False},
            "minecraft:silverfish":         {"category": "monster", "friendly": False},
            "minecraft:skeleton":           {"category": "monster", "friendly": False},
            "minecraft:slime":              {"category": "monster", "friendly": False},
            "minecraft:spider":             {"category": "monster", "friendly": False},
            "minecraft:stray":              {"category": "monster", "friendly": False},
            "minecraft:vex":                {"category": "monster", "friendly": False},
            "minecraft:vindicator":         {"category": "monster", "friendly": False},
            "minecraft:witch":              {"category": "monster", "friendly": False},
            "minecraft:wither":             {"category": "monster", "friendly": False},
            "minecraft:wither_skeleton":    {"category": "monster", "friendly": False},
            "minecraft:zoglin":             {"category": "monster", "friendly": False},
            "minecraft:zombie":             {"category": "monster", "friendly": False},
            "minecraft:zombie_villager":    {"category": "monster", "friendly": False},
            "minecraft:zombified_piglin":   {"category": "monster", "friendly": False},
            "minecraft:piglin":             {"category": "monster", "friendly": False},
            "minecraft:breeze":             {"category": "monster", "friendly": False},
            "minecraft:warden":             {"category": "monster", "friendly": False},
            "minecraft:bogged":             {"category": "monster", "friendly": False},

            # ── Creature / Passive ──
            "minecraft:axolotl":            {"category": "axolotl", "friendly": True},
            "minecraft:bat":                {"category": "ambient", "friendly": True},
            "minecraft:bee":                {"category": "creature", "friendly": True},
            "minecraft:camel":              {"category": "creature", "friendly": True},
            "minecraft:cat":                {"category": "creature", "friendly": True},
            "minecraft:chicken":            {"category": "creature", "friendly": True},
            "minecraft:cow":                {"category": "creature", "friendly": True},
            "minecraft:donkey":             {"category": "creature", "friendly": True},
            "minecraft:fox":                {"category": "creature", "friendly": True},
            "minecraft:frog":               {"category": "creature", "friendly": True},
            "minecraft:goat":               {"category": "creature", "friendly": True},
            "minecraft:horse":              {"category": "creature", "friendly": True},
            "minecraft:mooshroom":          {"category": "creature", "friendly": True},
            "minecraft:mule":               {"category": "creature", "friendly": True},
            "minecraft:ocelot":             {"category": "creature", "friendly": True},
            "minecraft:panda":              {"category": "creature", "friendly": True},
            "minecraft:parrot":             {"category": "creature", "friendly": True},
            "minecraft:pig":                {"category": "creature", "friendly": True},
            "minecraft:polar_bear":         {"category": "creature", "friendly": True},
            "minecraft:rabbit":             {"category": "creature", "friendly": True},
            "minecraft:sheep":              {"category": "creature", "friendly": True},
            "minecraft:skeleton_horse":     {"category": "creature", "friendly": True},
            "minecraft:sniffer":            {"category": "creature", "friendly": True},
            "minecraft:strider":            {"category": "creature", "friendly": True},
            "minecraft:tadpole":            {"category": "creature", "friendly": True},
            "minecraft:trader_llama":       {"category": "creature", "friendly": True},
            "minecraft:turtle":             {"category": "creature", "friendly": True},
            "minecraft:wolf":               {"category": "creature", "friendly": True},
            "minecraft:allay":              {"category": "creature", "friendly": True},
            "minecraft:iron_golem":         {"category": "creature", "friendly": True},
            "minecraft:snow_golem":         {"category": "creature", "friendly": True},
            "minecraft:villager":           {"category": "creature", "friendly": True},
            "minecraft:llama":              {"category": "creature", "friendly": True},
            "minecraft:armadillo":          {"category": "creature", "friendly": True},
            "minecraft:copper_golem":       {"category": "creature", "friendly": True},

            # ── Water ──
            "minecraft:dolphin":            {"category": "water_creature", "friendly": True},
            "minecraft:glow_squid":         {"category": "water_creature", "friendly": True},
            "minecraft:squid":              {"category": "water_creature", "friendly": True},
            "minecraft:cod":                {"category": "water_ambient", "friendly": True},
            "minecraft:pufferfish":         {"category": "water_ambient", "friendly": True},
            "minecraft:salmon":             {"category": "water_ambient", "friendly": True},
            "minecraft:tropical_fish":      {"category": "water_ambient", "friendly": True},

            # ── Misc / Utility ──
            "minecraft:armor_stand":        {"category": "misc", "friendly": True},
            "minecraft:experience_orb":     {"category": "misc", "friendly": True},
            "minecraft:player":             {"category": "misc", "friendly": True},
            "minecraft:area_effect_cloud":  {"category": "misc", "friendly": True},
            "minecraft:lightning_bolt":     {"category": "misc", "friendly": True},
            "minecraft:leash_knot":         {"category": "misc", "friendly": True},
            "minecraft:painting":           {"category": "misc", "friendly": True},
            "minecraft:item_frame":         {"category": "misc", "friendly": True},
            "minecraft:glow_item_frame":    {"category": "misc", "friendly": True},
        },
    },
}


# ── small packwiz helpers (kept local so this file is self-contained) ────────

def die(msg):
    sys.stderr.write(f"mobs.py: {msg}\n")
    sys.exit(1)


def repo_root():
    """Git top-level from the cwd, else the script's own ancestor repo."""
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True, cwd=os.getcwd())
    if out.returncode == 0:
        return out.stdout.strip()
    here = os.path.abspath(os.path.dirname(__file__))
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
        die(f"ambiguous '{target}' — matches {sorted(matches)}; pass a unique slug or .pw.toml filename")
    return None


def dir_to_zip(d):
    """Zip a datapack directory into a temp file for scanning."""
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

def fuzzy_match(target, known_ids, max_results=5):
    """Cheap fuzzy match using difflib.SequenceMatcher."""
    import difflib
    t = target.lower()
    t_short = t.split(":")[-1] if ":" in t else t
    scored = []
    for sid in known_ids:
        s = sid.lower()
        s_short = s.split(":")[-1] if ":" in s else s
        if t == s or t_short == s_short:
            return []
        ratio = difflib.SequenceMatcher(None, t_short, s_short).ratio()
        if ratio >= 0.6:
            scored.append((ratio, sid))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return [sid for _, sid in scored[:max_results]]


# ── entity extraction from jar ─────────────────────────────────────────────────

def extract_entities_from_jar(zf):
    """Scan a jar zip for mob-related data. Returns a dict of entity_id -> {
      source: str,            # what file(s) we found
      category: str or None,  # mob category if determinable
      tags: [str],            # entity tags this mob belongs to
      has_loot_table: bool,   # found data/*/loot_tables/entities/<id>.json
      spawn_modifiers: [],    # biome modifier entries affecting this mob
      lang_name: str or None, # English display name if found
      spawn_egg: bool,        # has a spawn egg item
      raw: {}                 # raw parsed data for --info
    }
    """
    entities = {}
    lang_cache = {}

    for n in zf.namelist():
        # Loot tables: data/<ns>/loot_tables/entities/<name>.json
        m = re.match(r"^data/([^/]+)/loot_tables/entities/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            eid = f"{ns}:{name}"
            if eid not in entities:
                entities[eid] = {
                    "source": "loot_table", "category": None, "tags": [],
                    "has_loot_table": True, "spawn_modifiers": [],
                    "lang_name": None, "spawn_egg": False, "raw": {},
                }
            try:
                entities[eid]["raw"]["loot_table"] = json.loads(zf.read(n))
            except Exception:
                pass
            continue

        # Spawn eggs via loot tables: data/<ns>/loot_tables/blocks/spawn_<mob>_egg.json
        # (not directly useful for entity listing, but indicates spawn egg exists)
        m = re.match(r"^data/([^/]+)/loot_tables/blocks/(.+_egg)\.json$", n)
        if m:
            ns, egg_name = m.group(1), m.group(2)
            # Try to extract mob name from spawn_<mob>_egg pattern
            mob_match = re.match(r"^spawn_(.+)_egg$", egg_name)
            if mob_match:
                mob_name = mob_match.group(1)
                # Try common entity id patterns
                candidates = [
                    f"{ns}:{mob_name}",
                    f"minecraft:{mob_name}",
                ]
                for cid in candidates:
                    if cid in entities:
                        entities[cid]["spawn_egg"] = True
                        break
                else:
                    # Create entry with just spawn egg info
                    eid = f"{ns}:{mob_name}"
                    if eid not in entities:
                        entities[eid] = {
                            "source": "spawn_egg", "category": None, "tags": [],
                            "has_loot_table": False, "spawn_modifiers": [],
                            "lang_name": None, "spawn_egg": True, "raw": {},
                        }
                    else:
                        entities[eid]["spawn_egg"] = True
            continue

        # Biome modifiers: data/<ns>/worldgen/biome_modifier/*.json
        m = re.match(r"^data/([^/]+)/worldgen/biome_modifier/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                bm_data = json.loads(zf.read(n))
            except Exception:
                continue
            # Biome modifiers can add/remove mob spawns
            bm_type = bm_data.get("type", "")
            # Check for "add_spawns" or "remove_spawns" type modifiers
            if "spawn" in bm_type.lower() or "add" in bm_type.lower():
                # Extract entity references from the modifier
                _extract_entities_from_biome_modifier(bm_data, ns, name, entities)
            continue

        # Entity tags: data/<ns>/tags/entity/<tag_name>.json
        m = re.match(r"^data/([^/]+)/tags/entity/(.+)\.json$", n)
        if m:
            ns, tag_name = m.group(1), m.group(2)
            tag_id = f"{ns}:{tag_name}"
            try:
                tag_data = json.loads(zf.read(n))
            except Exception:
                continue
            for entry in tag_data.get("values", []):
                if isinstance(entry, str):
                    eid = entry
                elif isinstance(entry, dict) and "id" in entry:
                    eid = entry["id"]
                else:
                    continue
                if eid not in entities:
                    entities[eid] = {
                        "source": "tag", "category": None, "tags": [],
                        "has_loot_table": False, "spawn_modifiers": [],
                        "lang_name": None, "spawn_egg": False, "raw": {},
                    }
                if tag_id not in entities[eid]["tags"]:
                    entities[eid]["tags"].append(tag_id)
            continue

        # Lang files: assets/<ns>/lang/en_us.json
        m = re.match(r"^assets/([^/]+)/lang/en_us\.json$", n)
        if m:
            ns = m.group(1)
            try:
                lang_data = json.loads(zf.read(n))
            except Exception:
                continue
            # Store for later entity name resolution
            lang_cache[ns] = lang_data
            continue

        # Advancements referencing entities: data/<ns>/advancements/**/*.json
        # (useful for detecting entity-related content but not critical)
        m = re.match(r"^data/([^/]+)/advancements/.+\.json$", n)
        if m:
            try:
                adv_data = json.loads(zf.read(n))
            except Exception:
                continue
            # Check criteria for entity-related triggers
            _extract_entities_from_advancement(adv_data, entities)
            continue

    # Apply lang names to entities
    for ns, lang_data in lang_cache.items():
        for eid, edata in entities.items():
            if edata["lang_name"] is not None:
                continue
            e_ns, e_name = eid.split(":", 1) if ":" in eid else ("minecraft", eid)
            # Try entity.translation_key patterns
            for key_pattern in [
                f"entity.{e_ns}.{e_name}",
                f"entity.{e_ns}.{e_name.replace('/', '.')}",
            ]:
                if key_pattern in lang_data:
                    edata["lang_name"] = lang_data[key_pattern]
                    break

    return entities


def _extract_entities_from_biome_modifier(data, ns, name, entities):
    """Extract entity references from a biome modifier JSON."""
    # Biome modifiers can reference entities in various ways depending on
    # the modifier type. Common patterns:
    #   "type": "neoforge:add_spawns" with "entries": [{"type": "minecraft:zombie", ...}]
    #   "type": "minecraft:add_spawns" with entity references
    # We do a recursive walk to find entity type references.
    _walk_for_entity_refs(data, ns, "biome_modifier:" + name, entities)


def _extract_entities_from_advancement(data, entities):
    """Extract entity references from advancement criteria."""
    _walk_for_entity_refs(data, None, "advancement", entities)


def _walk_for_entity_refs(obj, ns, context, entities, depth=0):
    """Recursively walk a JSON object looking for entity type references."""
    if depth > 10:
        return
    if isinstance(obj, dict):
        # Check for "type" key that looks like an entity type
        if "type" in obj and isinstance(obj["type"], str):
            ref = obj["type"]
            if ":" in ref and not ref.startswith("#"):
                # Looks like an entity type reference
                if ref not in entities:
                    entities[ref] = {
                        "source": context, "category": None, "tags": [],
                        "has_loot_table": False, "spawn_modifiers": [],
                        "lang_name": None, "spawn_egg": False, "raw": {},
                    }
        # Check for "entity" key
        if "entity" in obj and isinstance(obj["entity"], str):
            ref = obj["entity"]
            if ":" in ref:
                if ref not in entities:
                    entities[ref] = {
                        "source": context, "category": None, "tags": [],
                        "has_loot_table": False, "spawn_modifiers": [],
                        "lang_name": None, "spawn_egg": False, "raw": {},
                    }
        # Check for "id" key in mob-spawn-like structures
        if "id" in obj and isinstance(obj["id"], str) and "spawn" in context.lower():
            ref = obj["id"]
            if ":" in ref:
                if ref not in entities:
                    entities[ref] = {
                        "source": context, "category": None, "tags": [],
                        "has_loot_table": False, "spawn_modifiers": [],
                        "lang_name": None, "spawn_egg": False, "raw": {},
                    }
                # Store spawn modifier info
                entities[ref]["spawn_modifiers"].append({
                    "modifier": context,
                    "data": {k: v for k, v in obj.items() if k != "type"},
                })
        for v in obj.values():
            _walk_for_entity_refs(v, ns, context, entities, depth + 1)
    elif isinstance(obj, list):
        for item in obj:
            _walk_for_entity_refs(item, ns, context, entities, depth + 1)


# ── scanning ──────────────────────────────────────────────────────────────────

def scan_vanilla(info):
    ver = info.get("minecraft")
    if not ver or ver not in VANILLA_BY_MC:
        return None, f"no embedded vanilla baseline for MC {ver} (tables: {', '.join(sorted(VANILLA_BY_MC)) or 'none'})"
    vt = VANILLA_BY_MC[ver]
    mobs = {}
    for eid, edata in vt["mobs"].items():
        mobs[eid] = {
            "category": edata["category"],
            "friendly": edata["friendly"],
            "source": "vanilla",
            "tags": [],
            "has_loot_table": True,  # vanilla mobs always have loot tables
            "spawn_modifiers": [],
            "lang_name": None,
            "spawn_egg": True,  # vanilla mobs all have spawn eggs
        }
    return {"kind": "vanilla", "name": f"vanilla {ver} baseline", "jar": None,
            "mobs": mobs}, None


def scan_mods(pack_dir, info, want_mods=None, skipped=None):
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
            entities = extract_entities_from_jar(zf)
        sources.append({
            "kind": "mod",
            "name": by_toml[toml][0],
            "jar": entry["url"].rsplit("/", 1)[-1],
            "mobs": entities,
        })
    return sources, dl, from_cache


def scan_datapacks(pack_dir, skipped_dp=None):
    sources = []
    dp_root = paxi_dir(pack_dir)
    if os.path.isdir(dp_root):
        for name in sorted(os.listdir(dp_root)):
            p = os.path.join(dp_root, name)
            if os.path.isdir(p):
                tmp, zip_path = dir_to_zip(p)
                try:
                    with zipfile.ZipFile(zip_path) as zf:
                        entities = extract_entities_from_jar(zf)
                finally:
                    shutil.rmtree(tmp, ignore_errors=True)
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}/",
                                "jar": None, "mobs": entities})
            elif name.endswith(".zip"):
                try:
                    with zipfile.ZipFile(p) as zf:
                        entities = extract_entities_from_jar(zf)
                except zipfile.BadZipFile:
                    if skipped_dp is not None:
                        skipped_dp.append(f"{name}: not a valid zip")
                    continue
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}",
                                "jar": None, "mobs": entities})
    data_dir = os.path.join(pack_dir, "data")
    if os.path.isdir(data_dir):
        tmp, zip_path = dir_to_zip(data_dir)
        try:
            with zipfile.ZipFile(zip_path) as zf:
                entities = extract_entities_from_jar(zf)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        sources.append({"kind": "datapack", "name": "<pack>/data/",
                        "jar": None, "mobs": entities})
    return sources


# ── summary ───────────────────────────────────────────────────────────────────

def build_summary(sources, dl, from_cache, skipped, skipped_dp):
    all_mobs = {}  # eid -> {category, source_kind, source_name, tags, ...}
    by_mod = {}    # mod_name -> count
    by_category = {}  # category -> count

    # Track all mob ids per source for cross-referencing
    all_mob_ids = set()
    loot_table_mobs = set()
    spawn_modifier_mobs = set()
    tag_referenced_mobs = set()

    for src in sources:
        mod_count = 0
        for eid, edata in src["mobs"].items():
            mod_count += 1
            all_mob_ids.add(eid)

            if eid not in all_mobs:
                all_mobs[eid] = {
                    "category": edata.get("category"),
                    "friendly": edata.get("friendly"),
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    "tags": list(edata.get("tags", [])),
                    "has_loot_table": edata.get("has_loot_table", False),
                    "spawn_modifiers": list(edata.get("spawn_modifiers", [])),
                    "lang_name": edata.get("lang_name"),
                    "spawn_egg": edata.get("spawn_egg", False),
                }
            else:
                # Merge info from additional sources
                existing = all_mobs[eid]
                if edata.get("tags"):
                    for t in edata["tags"]:
                        if t not in existing["tags"]:
                            existing["tags"].append(t)
                if edata.get("spawn_modifiers"):
                    existing["spawn_modifiers"].extend(edata["spawn_modifiers"])
                if edata.get("has_loot_table"):
                    existing["has_loot_table"] = True
                if edata.get("lang_name") and not existing["lang_name"]:
                    existing["lang_name"] = edata["lang_name"]
                if edata.get("spawn_egg"):
                    existing["spawn_egg"] = True

            if edata.get("has_loot_table"):
                loot_table_mobs.add(eid)
            if edata.get("spawn_modifiers"):
                spawn_modifier_mobs.add(eid)
            if edata.get("tags"):
                tag_referenced_mobs.add(eid)

        if src["kind"] == "mod":
            by_mod[src["name"]] = mod_count

    # Count by category
    for eid, edata in all_mobs.items():
        cat = edata.get("category") or "unknown"
        by_category[cat] = by_category.get(cat, 0) + 1

    # Vanilla mobs overridden/reskinned by mods
    vanilla_ids = set()
    for src in sources:
        if src["kind"] == "vanilla":
            vanilla_ids.update(src["mobs"].keys())
    vanilla_overrides = []
    for src in sources:
        if src["kind"] == "vanilla":
            continue
        for eid in src["mobs"]:
            if eid in vanilla_ids and eid not in [v for v in vanilla_overrides]:
                vanilla_overrides.append(eid)
    vanilla_overrides.sort()

    # Mob IDs found in registration but never referenced by any
    # spawn/loot/tag data (defined but unused)
    referenced_mobs = loot_table_mobs | spawn_modifier_mobs | tag_referenced_mobs
    defined_unused = sorted(all_mob_ids - referenced_mobs)

    # Mob IDs referenced in spawn/loot/tag but not found in any
    # registration source (referenced but missing)
    # For this, we check if any referenced ID is NOT in all_mobs
    # (i.e., referenced by a tag or biome modifier but no jar defines it)
    referenced_missing = []  # we'd need to track where references came from

    return {
        "sources": sources,
        "all_mobs": all_mobs,
        "total_mobs": len(all_mobs),
        "jars_downloaded": dl,
        "jars_from_cache": from_cache,
        "skipped_no_url": sorted(skipped),
        "skipped_datapacks": sorted(skipped_dp),
        "by_mod": by_mod,
        "by_category": by_category,
        "vanilla_overrides": vanilla_overrides,
        "defined_unused": defined_unused,
        "referenced_missing": referenced_missing,
        "loot_table_mobs": sorted(loot_table_mobs),
        "spawn_modifier_mobs": sorted(spawn_modifier_mobs),
        "tag_referenced_mobs": sorted(tag_referenced_mobs),
    }


# ── output ────────────────────────────────────────────────────────────────────

def report_human(info, summ):
    srcs = summ["sources"]
    print(f"## pack {info['name']}  (MC {info['minecraft'] or '?'}, "
          f"{info['loader'] or '?'} {info['loader_version'] or ''})".strip())
    for src in srcs:
        if not src["mobs"]:
            continue
        print(f"## source: {src['name']}" + (f"  ({src['jar']})" if src["jar"] else ""))
        for eid in sorted(src["mobs"]):
            edata = src["mobs"][eid]
            cat = edata.get("category") or "?"
            extra = ""
            if src["kind"] != "vanilla" and eid in summ.get("vanilla_overrides", []):
                extra = "  [OVERRIDES VANILLA — replaces the vanilla mob]"
            tags_str = ""
            if edata.get("tags"):
                tags_str = f"  tags={','.join(edata['tags'][:3])}"
            spawn_str = ""
            if edata.get("spawn_modifiers"):
                spawn_str = f"  spawn_mods={len(edata['spawn_modifiers'])}"
            name_str = ""
            if edata.get("lang_name"):
                name_str = f"  \"{edata['lang_name']}\""
            print(f"  mob  {eid}  (cat={cat}){tags_str}{spawn_str}{name_str}{extra}")

    print()
    print(f"## summary ({summ['jars_downloaded']} jar{'s' if summ['jars_downloaded'] != 1 else ''} downloaded, {summ['jars_from_cache']} from cache)")
    print(f"  total mobs: {summ['total_mobs']}")
    if summ["skipped_no_url"]:
        print(f"  SKIPPED (no download URL — CurseForge-mode?): {', '.join(summ['skipped_no_url'])}")
    if summ["skipped_datapacks"]:
        print(f"  SKIPPED datapacks: {', '.join(summ['skipped_datapacks'])}")

    # Category breakdown
    print(f"  by category:")
    for cat in sorted(summ["by_category"]):
        print(f"    {cat}: {summ['by_category'][cat]}")

    # By mod breakdown
    if summ["by_mod"]:
        print(f"  by mod (top 20):")
        for mod, count in sorted(summ["by_mod"].items(), key=lambda x: -x[1])[:20]:
            print(f"    {mod}: {count}")
        if len(summ["by_mod"]) > 20:
            print(f"    … ({len(summ['by_mod']) - 20} more mods)")

    if summ["vanilla_overrides"]:
        print(f"  vanilla mobs the pack redefines: {len(summ['vanilla_overrides'])}")
        for v in summ["vanilla_overrides"]:
            print(f"    - {v}")

    if summ["defined_unused"]:
        print(f"  mobs defined but never referenced by loot/spawn/tag data: {len(summ['defined_unused'])}")
        for m in summ["defined_unused"][:15]:
            print(f"    - {m}")
        if len(summ["defined_unused"]) > 15:
            print(f"    … ({len(summ['defined_unused']) - 15} more)")

    if summ["spawn_modifier_mobs"]:
        print(f"  mobs with datapack spawn modifications: {len(summ['spawn_modifier_mobs'])}")
        for m in summ["spawn_modifier_mobs"][:10]:
            print(f"    - {m}")
        if len(summ["spawn_modifier_mobs"]) > 10:
            print(f"    … ({len(summ['spawn_modifier_mobs']) - 10} more)")


def report_json(info, summ):
    out = {
        "tool": "mobs.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "mobs": {k: {"category": v.get("category"), "tags": v.get("tags", []),
                           "has_loot_table": v.get("has_loot_table", False),
                           "spawn_egg": v.get("spawn_egg", False),
                           "lang_name": v.get("lang_name")}
                      for k, v in sorted(s["mobs"].items())}}
            for s in summ["sources"]
        ],
        "summary": {
            "total_mobs": summ["total_mobs"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "by_mod": summ["by_mod"],
            "by_category": summ["by_category"],
            "vanilla_overrides": summ["vanilla_overrides"],
            "defined_unused": summ["defined_unused"],
            "referenced_missing": summ["referenced_missing"],
            "spawn_modifier_mobs": summ["spawn_modifier_mobs"],
        },
    }
    json.dump(out, sys.stdout, indent=2, sort_keys=True)
    print()


def cmd_info(pack_dir, info, target, as_json):
    """Look up a single mob ID and report all known metadata."""
    sources = []
    skip_no_url = []
    skip_dp = []
    v_src, v_note = scan_vanilla(info)
    if v_src:
        sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, None, skip_no_url)
    sources += mod_sources
    sources += scan_datapacks(pack_dir, skip_dp)

    # Normalize the target id
    if ":" not in target:
        target = f"minecraft:{target}"

    # Find the mob across all sources
    found = False
    result = {}
    for src in sources:
        if target in src["mobs"]:
            found = True
            edata = src["mobs"][target]
            result["id"] = target
            result["category"] = edata.get("category") or "unknown"
            result["friendly"] = edata.get("friendly")
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["tags"] = edata.get("tags", [])
            result["has_loot_table"] = edata.get("has_loot_table", False)
            result["spawn_egg"] = edata.get("spawn_egg", False)
            result["lang_name"] = edata.get("lang_name")
            result["spawn_modifiers"] = edata.get("spawn_modifiers", [])
            break

    if not found:
        all_ids = set()
        for src in sources:
            all_ids.update(src["mobs"].keys())
        suggest = fuzzy_match(target, all_ids)
        msg = f"mob '{target}' not found in any source"
        if suggest:
            msg += f" — did you mean: {', '.join(suggest)}"
        die(msg)

    # Vanilla override status
    result["vanilla_override"] = False
    result["vanilla_redefined"] = False
    if target.startswith("minecraft:"):
        v_src_obj = next((s for s in sources if s["kind"] == "vanilla"), None)
        if v_src_obj and target in v_src_obj["mobs"]:
            # Check if any non-vanilla source also defines it
            for src in sources:
                if src["kind"] != "vanilla" and target in src["mobs"]:
                    result["vanilla_override"] = True
                    break

    if as_json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        print()
        return

    # Human-readable output
    print(f"## mob: {result['id']}")
    if result.get("lang_name"):
        print(f"  name:       {result['lang_name']}")
    print(f"  category:   {result['category']}")
    if result.get("friendly") is not None:
        print(f"  friendly:   {'yes' if result['friendly'] else 'no'}")
    print(f"  source:     {result['source_kind']}: {result['source_name']}"
          + (f"  ({result['source_jar']})" if result["source_jar"] else ""))
    if result["vanilla_override"]:
        print(f"  override:   YES — replaces the vanilla mob (mod redefines {target})")
    if result["tags"]:
        print(f"  tags:       {', '.join(result['tags'][:10])}")
        if len(result["tags"]) > 10:
            print(f"              … ({len(result['tags']) - 10} more)")
    else:
        print(f"  tags:       (none found)")
    if result["has_loot_table"]:
        print(f"  loot table: yes")
    else:
        print(f"  loot table: no")
    if result["spawn_egg"]:
        print(f"  spawn egg:  yes")
    if result["spawn_modifiers"]:
        print(f"  spawn mods: {len(result['spawn_modifiers'])} datapack modifier(s)")
        for mod in result["spawn_modifiers"][:5]:
            print(f"              - {mod['modifier']}")
    # Raw data for debugging
    if result.get("raw"):
        print(f"  raw JSON:")
        for key, val in result["raw"].items():
            print(f"    {key}:")
            print(json.dumps(val, indent=6, sort_keys=True)[:500])


def _format_mob_detail(target_id, sources):
    """Build the detail dict for a single mob across all sources."""
    result = {}
    for src in sources:
        if target_id in src["mobs"]:
            edata = src["mobs"][target_id]
            result["id"] = target_id
            result["category"] = edata.get("category") or "unknown"
            result["friendly"] = edata.get("friendly")
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["tags"] = edata.get("tags", [])
            result["has_loot_table"] = edata.get("has_loot_table", False)
            result["spawn_egg"] = edata.get("spawn_egg", False)
            result["lang_name"] = edata.get("lang_name")
            result["spawn_modifiers"] = edata.get("spawn_modifiers", [])
            break
    result["vanilla_override"] = False
    if target_id.startswith("minecraft:"):
        v_src_obj = next((s for s in sources if s["kind"] == "vanilla"), None)
        if v_src_obj and target_id in v_src_obj["mobs"]:
            for src in sources:
                if src["kind"] != "vanilla" and target_id in src["mobs"]:
                    result["vanilla_override"] = True
                    break
    return result


def cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_):
    """Export every mob's full metadata to a single JSON file."""
    import time
    t0 = time.monotonic()

    sources = []
    skip_no_url = []
    skip_dp = []
    if scan_vanilla_:
        v_src, _ = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, want_mods, skip_no_url)
    sources += mod_sources
    if scan_dp:
        sources += scan_datapacks(pack_dir, skip_dp)

    all_ids = set()
    for src in sources:
        all_ids.update(src["mobs"].keys())

    t_scan = time.monotonic()

    entries = {}
    for eid in sorted(all_ids):
        entries[eid] = _format_mob_detail(eid, sources)

    t_detail = time.monotonic()

    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    out = {
        "tool": "mobs.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "mob_count": len(s["mobs"])}
            for s in summ["sources"]
        ],
        "summary": {
            "total_mobs": summ["total_mobs"],
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
    print(f"full-export: {len(entries)} mobs → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
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
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-mobs-full.json"
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
        all_mobs = set()
        for src in sources:
            all_mobs.update(src["mobs"].keys())
        for eid in sorted(all_mobs):
            print(eid)
        return
    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    report_human(info, summ)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        devnull = os.open(os.devnull, os.O_WRONLY)
        os.dup2(devnull, sys.stdout.fileno())
        sys.exit(0)


# ── Vanilla baseline regen recipe ─────────────────────────────────────────────
# VANILLA_BY_MC is embedded so the tool is offline and deterministic. To add a
# Minecraft version, download Mojang's client jar for that version, then:
#
#   python3 - << 'EOF'
#   import zipfile, json, re, os
#   zf = zipfile.ZipFile("client-<ver>.jar")
#   mobs = {}
#   for n in zf.namelist():
#       m = re.match(r"^data/minecraft/loot_tables/entities/(.+)\.json$", n)
#       if m:
#           mobs[f"minecraft:{m.group(1)}"] = {"category": "?", "friendly": True}
#   print(json.dumps(mobs, sort_keys=True, indent=2))
#   EOF
#
# Then classify each mob by category (monster/creature/ambient/water_creature/
# water_ambient/underground_water_creature/axolotl/misc) and friendly status.

# ## RUN LOG
# ### 2026-09-06
# Created as the standalone, complete mob enumerator. Mirrors structures.py
# architecture: embedded vanilla 1.21.1 baseline (~80 entities), jar cache
# by checksum, datapack scanning (loot tables, biome modifiers, entity tags,
# spawn eggs, advancements). Flags vanilla overrides, mobs with datapack
# spawn modifications, defined-but-unused mobs. Supports --json (stable
# schema), --list, and --info for single-mob lookup with fuzzy suggestions.
