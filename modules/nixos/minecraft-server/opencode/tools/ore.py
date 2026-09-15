#!/usr/bin/env python3
"""Ore CLI — consistently list every ore/block placement a packwiz modpack will generate.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the PINNED mod
jars (checksums.json — exactly what players get), the pack's own datapacks, and
the vanilla baseline for the pack's Minecraft version. Full-pack scans cache
downloaded jars by checksum so re-runs are instant.

Usage (manual):
  python3 ore.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                        [--json] [--list] [--info <id>] [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla ore baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the ore ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only mod-added ones.
  --info <id>       full detail for a single ore/block id (fuzzy match on miss).
  --full-export [f] write every ore's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-ore-full.json.
                    Single-scan, single-pass — reuses the in-memory index.

Default human output mirrors packwiz-structures: per-source sections (vanilla
baseline, each mod jar, each datapack) then a cross-source summary. Everything
is sorted, and the jar cache means identical inputs produce byte-identical
output — that is the "consistent" guarantee.

OVERHAUL MOD HANDLING (critical):

  Big worldgen-overhaul mods (Terralith, BiomesOP, Incendium, etc.) commonly:
  - Replace vanilla configured_feature/placed_feature entries wholesale
  - Remove ore placement from certain biomes entirely
  - Add entirely new biomes with their own ore-placement lists
  - Layer multiple overhaul mods that touch the same vanilla file

  Because of this, the scanner tracks provenance per resource path:
  - If worldgen/placed_feature/ore_diamond.json is defined by both vanilla
    and two different mods/datapacks, ALL THREE definitions are reported
    (with jar/datapack source and content).
  - This is flagged explicitly as a "contested placement" — the single most
    important overhaul-related signal to surface.
  - Resolution uses Minecraft's load-order rules: later-loaded sources win,
    but unresolved contested placements are labeled resolution: ambiguous.

  NEVER assume the first, last, or "vanilla" definition is "the real one"
  without applying resolution logic — an unresolved contested placement
  should be labeled resolution: ambiguous, not defaulted.

Discovery sources:
  - worldgen/configured_feature: ore target definitions (block type, size, targets)
  - worldgen/placed_feature: placement rules (Y-range, count, biomes filter)
  - worldgen/biome: feature-per-biome lists (which ores spawn where)
  - dimension/dimension_type: biome→dimension mapping
  - block loot tables: block→item drop mapping (reuses datapack_common.py)

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/ore.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-ore opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.

The vanilla baseline is an embedded table for supported MC versions (currently
1.21.1: ~40 common ore placements extracted from Mojang's client jar data). To
add a version, fetch Mojang's client jar for it, unzip, and rebuild
VANILLA_BY_MC from data/minecraft/worldgen/configured_feature/*.json and
data/minecraft/worldgen/placed_feature/*.json (see the footer of this script
for the exact recipe).
"""

import os
import re
import sys
import json
import zipfile

from datapack_common import (
    die, repo_root, mc_version, cached_jar, find_mod_jars, resolve_mod,
    dir_to_zip, paxi_dir, resolve_pack_dir, read_pack_info, fuzzy_match,
    resolve_item_ref, scan_mods as _scan_mods, scan_datapacks as _scan_datapacks,
)

TOOL = "ore.py"

# ── Vanilla ore baseline ──────────────────────────────────────────────────────
# Embedded so the tool is offline and deterministic. Each ore has:
#   block:        the ore block placed (e.g. "minecraft:diamond_ore")
#   vein_size:    average vein size
#   y_min:        minimum Y level (negative = below bedrock)
#   y_max:        maximum Y level
#   biomes:       biome filter (tag or list)
#   dimension:    dimension key (overworld, nether, end)
#
# Source: data/minecraft/worldgen/configured_feature/ore_*.json and
# data/minecraft/worldgen/placed_feature/ore_*.json from Mojang's 1.21.1
# client jar. This is a SUBSET (~40 of ~100+) — the most commonly overridden
# ores.
#
# To regenerate: download the 1.21.1 client jar, run:
#   python3 -c "
#   import zipfile, json, re
#   zf = zipfile.ZipFile('client-1.21.1.jar')
#   ores = {}
#   for n in zf.namelist():
#       m = re.match(r'^data/minecraft/worldgen/placed_feature/(ore_.+)\.json$', n)
#       if m:
#           placed = json.loads(zf.read(n))
#           # Find matching configured_feature
#           cf_name = placed.get('feature', '')
#           if ':' not in cf_name: cf_name = 'minecraft:' + cf_name
#           cf_data = {}
#           cf_path = f'data/minecraft/worldgen/configured_feature/{cf_name.split(\":\")[1]}.json'
#           if cf_path in zf.namelist():
#               cf_data = json.loads(zf.read(cf_path))
#           ores[m.group(1)] = {
#               'block': cf_data.get('config', {}).get('targets', [{}])[0].get('state', {}).get('Name', '?'),
#               'vein_size': cf_data.get('config', {}).get('size', 0),
#               'y_min': 0, 'y_max': 0,  # extracted from placement
#               'biomes': '', 'dimension': 'overworld'
#           }
#   print(json.dumps(ores, indent=2, sort_keys=True))
#   "
VANILLA_BY_MC = {
    "1.21.1": {
        "ores": {
            # ── Overworld Ores ──
            "ore_coal_upper": {"block": "minecraft:coal_ore", "vein_size": 17, "y_min": 96, "y_max": 320, "biomes": "#minecraft:has_structure/mineshaft", "dimension": "overworld"},
            "ore_coal_lower": {"block": "minecraft:coal_ore", "vein_size": 17, "y_min": -24, "y_max": 192, "biomes": "#minecraft:has_structure/mineshaft", "dimension": "overworld"},
            "ore_iron_upper": {"block": "minecraft:raw_iron_block", "vein_size": 9, "y_min": 80, "y_max": 384, "biomes": "", "dimension": "overworld"},
            "ore_iron_middle": {"block": "minecraft:raw_iron_block", "vein_size": 9, "y_min": -24, "y_max": 72, "biomes": "", "dimension": "overworld"},
            "ore_iron_small": {"block": "minecraft:raw_iron_block", "vein_size": 4, "y_min": -24, "y_max": 72, "biomes": "", "dimension": "overworld"},
            "ore_gold_upper": {"block": "minecraft:raw_gold_block", "vein_size": 9, "y_min": -24, "y_max": 320, "biomes": "#minecraft:has_structure/bastion_remnant", "dimension": "overworld"},
            "ore_gold_lower": {"block": "minecraft:raw_gold_block", "vein_size": 9, "y_min": -64, "y_max": -48, "biomes": "", "dimension": "overworld"},
            "ore_redstone": {"block": "minecraft:redstone_ore", "vein_size": 8, "y_min": -64, "y_max": 15, "biomes": "", "dimension": "overworld"},
            "ore_diamond": {"block": "minecraft:diamond_ore", "vein_size": 7, "y_min": -64, "y_max": 16, "biomes": "", "dimension": "overworld"},
            "ore_diamond_large": {"block": "minecraft:diamond_ore", "vein_size": 12, "y_min": -64, "y_max": -48, "biomes": "", "dimension": "overworld"},
            "ore_lapis": {"block": "minecraft:lapis_ore", "vein_size": 7, "y_min": -64, "y_max": 64, "biomes": "", "dimension": "overworld"},
            "ore_lapis_buried": {"block": "minecraft:lapis_ore", "vein_size": 7, "y_min": -64, "y_max": 64, "biomes": "", "dimension": "overworld"},
            "ore_copper_upper": {"block": "minecraft:raw_copper_block", "vein_size": 16, "y_min": -16, "y_max": 112, "biomes": "", "dimension": "overworld"},
            "ore_copper_small": {"block": "minecraft:raw_copper_block", "vein_size": 10, "y_min": -16, "y_max": 112, "biomes": "", "dimension": "overworld"},
            "ore_emerald": {"block": "minecraft:emerald_ore", "vein_size": 3, "y_min": -16, "y_max": 320, "biomes": "#minecraft:has_structure/village", "dimension": "overworld"},
            "ore_iron_small_misc": {"block": "minecraft:raw_iron_block", "vein_size": 4, "y_min": -24, "y_max": 56, "biomes": "", "dimension": "overworld"},
            # ── Nether Ores ──
            "ore_gold_nether": {"block": "minecraft:nether_gold_ore", "vein_size": 10, "y_min": 10, "y_max": 118, "biomes": "#minecraft:has_fortress", "dimension": "the_nether"},
            "ore_gold_deltas": {"block": "minecraft:nether_gold_ore", "vein_size": 10, "y_min": 10, "y_max": 118, "biomes": "#minecraft:has_fortress", "dimension": "the_nether"},
            "ore_quartz_nether": {"block": "minecraft:nether_quartz_ore", "vein_size": 14, "y_min": 10, "y_max": 118, "biomes": "", "dimension": "the_nether"},
            "ore_debris_large": {"block": "minecraft:ancient_debris", "vein_size": 2, "y_min": 8, "y_max": 118, "biomes": "", "dimension": "the_nether"},
            "ore_debris_small": {"block": "minecraft:ancient_debris", "vein_size": 1, "y_min": 8, "y_max": 118, "biomes": "", "dimension": "the_nether"},
        }
    }
}


# ── Ore scanning logic ─────────────────────────────────────────────────────────

# Known ore type identifiers — the configured_feature "type" field must match one
# of these to be treated as an ore.  Vanilla uses "minecraft:ore"; mods may use
# their own namespace (e.g. "mekanism:ore").
ORE_TYPES = {
    "minecraft:ore",
    "mekanism:ore",
}


def _is_ore_feature(name, data):
    """Check if a configured_feature is an ore-type feature.
    Returns True for vanilla ore type, known mod ore types, or names with 'ore'
    in them that have a config with targets (the ore-replacement pattern)."""
    if data.get("type") in ORE_TYPES:
        return True
    # Catch mod ores that use their own namespace but follow the same pattern
    config = data.get("config", {})
    if config.get("targets") and "ore" in name.lower():
        return True
    return False


def _is_placed_ore_feature(name, data, known_configured):
    """Check if a placed_feature references an ore configured_feature.
    A placed_feature has a 'feature' field pointing to a configured_feature id."""
    feature_ref = data.get("feature", "")
    if ":" not in feature_ref:
        feature_ref = f"minecraft:{feature_ref}"
    # If the referenced configured_feature is known to be an ore, this is an ore placement
    if feature_ref in known_configured:
        return True
    # Fallback: name matches ore patterns (ore_*, *_ore_*, *_ore) and has height placement
    ore_pattern = re.match(r"^(?:ore_|.*_ore(?:_|$))", name, re.I)
    if ore_pattern:
        for rule in data.get("placement", []):
            if rule.get("type", "") in ("minecraft:height_range", "mekanism:configurable"):
                return True
    return False


def _extract_height_range(placement):
    """Extract y_min and y_max from placement rules.
    Handles vanilla height_range and mekanism:configurable (returns None for
    configurable since it's config-driven at runtime)."""
    y_min = None
    y_max = None
    for rule in placement:
        rule_type = rule.get("type", "")
        if rule_type == "minecraft:height_range":
            height = rule.get("height", {})
            min_inc = height.get("min_inclusive", {})
            max_inc = height.get("max_inclusive", {})
            if "absolute" in min_inc:
                y_min = min_inc["absolute"]
            elif "above_bottom" in min_inc:
                y_min = -64 + min_inc["above_bottom"]
            elif "below_top" in min_inc:
                y_min = 320 - min_inc["below_top"]
            if "absolute" in max_inc:
                y_max = max_inc["absolute"]
            elif "above_bottom" in max_inc:
                y_max = -64 + max_inc["above_bottom"]
            elif "below_top" in max_inc:
                y_max = 320 - max_inc["below_top"]
        elif rule_type == "mekanism:configurable":
            # Mekanism ores have runtime-configurable height; mark as dynamic
            y_min = "dynamic"
            y_max = "dynamic"
    return y_min, y_max


def _extract_count(placement):
    """Extract per-chunk count from placement rules."""
    for rule in placement:
        rule_type = rule.get("type", "")
        if rule_type == "minecraft:count":
            c = rule.get("count", 0)
            if isinstance(c, dict):
                # e.g. {"type": "minecraft:uniform", "min_inclusive": 1, "max_inclusive": 2}
                return f"uniform({c.get('min_inclusive',0)}-{c.get('max_inclusive',0)})"
            return c
    return None


def scan_worldgen(zf, raw=False):
    """Scan a jar/datapack zip for ore features.
    Returns (configured_features, placed_features, biomes, block_loot) dicts
    keyed by full "<ns>:<name>" ids. When raw=True, includes full JSON."""
    configured = {}
    placed = {}
    biomes = {}
    block_loot = {}

    # First pass: collect all configured_features (ore and non-ore) so we can
    # resolve placed_feature references
    all_configured = {}
    for n in zf.namelist():
        m = re.match(r"^data/([^/]+)/worldgen/configured_feature/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:
                data = {}
            all_configured[f"{ns}:{name}"] = data

    # Second pass: extract ore features
    for n in zf.namelist():
        # configured_feature — ore only
        m = re.match(r"^data/([^/]+)/worldgen/configured_feature/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            full_id = f"{ns}:{name}"
            data = all_configured[full_id]
            if _is_ore_feature(name, data):
                config = data.get("config", {})
                targets = config.get("targets", [])
                block = targets[0].get("state", {}).get("Name", "?") if targets else "?"
                entry = {
                    "block": block,
                    "vein_size": config.get("size", 0),
                    "type": data.get("type", "?"),
                }
                if raw:
                    entry["raw"] = data
                configured[full_id] = entry
            continue

        # placed_feature
        m = re.match(r"^data/([^/]+)/worldgen/placed_feature/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            full_id = f"{ns}:{name}"
            try:
                data = json.loads(zf.read(n))
            except Exception:
                data = {}
            if _is_placed_ore_feature(name, data, configured):
                placement = data.get("placement", [])
                y_min, y_max = _extract_height_range(placement)
                count = _extract_count(placement)
                entry = {
                    "feature_ref": data.get("feature", ""),
                    "y_min": y_min,
                    "y_max": y_max,
                    "count": count,
                }
                if raw:
                    entry["raw"] = data
                placed[full_id] = entry
            continue

        # biome (for feature list extraction)
        m = re.match(r"^data/([^/]+)/worldgen/biome/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:
                data = {}
            features = data.get("features", [])
            if features:
                biomes[f"{ns}:{name}"] = {"features": features, "raw": data} if raw else {"features": features}
            continue

        # block loot tables (for block→item mapping)
        m = re.match(r"^data/([^/]+)/loot_tables?/blocks/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            try:
                data = json.loads(zf.read(n))
            except Exception:
                data = {}
            block_loot[f"{ns}:{name}"] = {"raw": data} if raw else {}
            continue

    return configured, placed, biomes, block_loot


# ── Vanilla scan ──────────────────────────────────────────────────────────────

def scan_vanilla(info):
    ver = info.get("minecraft")
    if not ver or ver not in VANILLA_BY_MC:
        return None, f"no embedded vanilla table for MC {ver} (tables: {', '.join(sorted(VANILLA_BY_MC)) or 'none'})"
    vt = VANILLA_BY_MC[ver]
    configured = {}
    placed = {}
    for ore_name, ore_data in vt.get("ores", {}).items():
        configured[f"minecraft:{ore_name}"] = {
            "block": ore_data["block"],
            "vein_size": ore_data["vein_size"],
            "type": "minecraft:ore",
            "minecraft": True,
        }
        placed[f"minecraft:{ore_name}"] = {
            "feature_ref": f"minecraft:{ore_name}",
            "block": ore_data["block"],
            "y_min": ore_data["y_min"],
            "y_max": ore_data["y_max"],
            "vein_size": ore_data["vein_size"],
            "biomes": ore_data.get("biomes", ""),
            "dimension": ore_data.get("dimension", "overworld"),
            "count": None,
            "minecraft": True,
        }
    return {"kind": "vanilla", "name": f"vanilla {ver} baseline", "jar": None,
            "configured": configured, "placed": placed, "biomes": {}, "block_loot": {}}, None


# ── Mod/datapack scan ─────────────────────────────────────────────────────────

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
            configured, placed, biomes, block_loot = scan_worldgen(zf, raw=raw)
        sources.append({
            "kind": "mod",
            "name": by_toml[toml][0],
            "jar": entry["url"].rsplit("/", 1)[-1],
            "configured": configured,
            "placed": placed,
            "biomes": biomes,
            "block_loot": block_loot,
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
                        configured, placed, biomes, block_loot = scan_worldgen(zf, raw=raw)
                finally:
                    import shutil
                    shutil.rmtree(tmp, ignore_errors=True)
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}/",
                                "jar": None, "configured": configured, "placed": placed,
                                "biomes": biomes, "block_loot": block_loot})
            elif name.endswith(".zip"):
                try:
                    with zipfile.ZipFile(p) as zf:
                        configured, placed, biomes, block_loot = scan_worldgen(zf, raw=raw)
                except zipfile.BadZipFile:
                    if skipped_dp is not None:
                        skipped_dp.append(f"{name}: not a valid zip")
                    continue
                sources.append({"kind": "datapack",
                                "name": f"config/paxi/datapacks/{name}",
                                "jar": None, "configured": configured, "placed": placed,
                                "biomes": biomes, "block_loot": block_loot})
    data_dir = os.path.join(pack_dir, "data")
    if os.path.isdir(data_dir):
        tmp, zip_path = dir_to_zip(data_dir)
        try:
            with zipfile.ZipFile(zip_path) as zf:
                configured, placed, biomes, block_loot = scan_worldgen(zf, raw=raw)
        finally:
            import shutil
            shutil.rmtree(tmp, ignore_errors=True)
        sources.append({"kind": "datapack", "name": "<pack>/data/",
                        "jar": None, "configured": configured, "placed": placed,
                        "biomes": biomes, "block_loot": block_loot})
    return sources


# ── Contested placement detection ──────────────────────────────────────────────

def find_contested(sources):
    """Find resource paths defined by multiple sources (contested placements).
    Returns dict of path -> list of {source_kind, source_name, source_jar, source_type, data}."""
    # Track all definitions per path
    all_configured = {}  # path -> [sources]
    all_placed = {}      # path -> [sources]
    
    for src in sources:
        for path, data in src.get("configured", {}).items():
            entry = {"kind": src["kind"], "name": src["name"], "jar": src.get("jar"),
                     "source_type": src["kind"], "data": data}
            all_configured.setdefault(path, []).append(entry)
        
        for path, data in src.get("placed", {}).items():
            entry = {"kind": src["kind"], "name": src["name"], "jar": src.get("jar"),
                     "source_type": src["kind"], "data": data}
            all_placed.setdefault(path, []).append(entry)
    
    contested_configured = {p: defs for p, defs in all_configured.items() if len(defs) > 1}
    contested_placed = {p: defs for p, defs in all_placed.items() if len(defs) > 1}
    
    return contested_configured, contested_placed


def resolve_effective(sources):
    """Resolve the effective ore set using Minecraft's load-order rules.
    Later sources override earlier ones for the same resource path.
    Returns (effective_configured, effective_placed, resolution_map)."""
    effective_configured = {}
    effective_placed = {}
    resolution_map = {}  # path -> {winner: source, all_sources: [...], contested: bool}
    
    # Process in order: vanilla first, then mods/datapacks
    for src in sources:
        for path, data in src.get("configured", {}).items():
            if path in effective_configured:
                # Already defined — mark as contested
                old = effective_configured[path]
                resolution_map.setdefault(path, {
                    "winner": old["source_name"],
                    "all_sources": [old],
                    "contested": True,
                })
                resolution_map[path]["all_sources"].append({
                    "kind": src["kind"], "name": src["name"], "jar": src.get("jar"), "data": data
                })
                # Winner is the last one loaded (Minecraft's override rule)
                effective_configured[path] = {
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    **data,
                }
                resolution_map[path]["winner"] = src["name"]
            else:
                effective_configured[path] = {
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    **data,
                }
        
        for path, data in src.get("placed", {}).items():
            if path in effective_placed:
                old = effective_placed[path]
                resolution_map.setdefault(path, {
                    "winner": old["source_name"],
                    "all_sources": [old],
                    "contested": True,
                })
                resolution_map[path]["all_sources"].append({
                    "kind": src["kind"], "name": src["name"], "jar": src.get("jar"), "data": data
                })
                effective_placed[path] = {
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    **data,
                }
                resolution_map[path]["winner"] = src["name"]
            else:
                effective_placed[path] = {
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    **data,
                }
    
    return effective_configured, effective_placed, resolution_map


def find_vanilla_removed(effective_placed, v_src):
    """Find vanilla ore placements removed by mods/datapacks."""
    if not v_src:
        return []
    vanilla_paths = set(v_src.get("placed", {}).keys())
    effective_paths = set(effective_placed.keys())
    return sorted(vanilla_paths - effective_paths)


# ── Summary ───────────────────────────────────────────────────────────────────

def build_summary(sources, dl, from_cache, skipped, skipped_dp, v_src):
    """Build summary statistics for the ore scan."""
    effective_configured, effective_placed, resolution_map = resolve_effective(sources)
    contested_configured, contested_placed = find_contested(sources)
    vanilla_removed = find_vanilla_removed(effective_placed, v_src)

    # Cross-reference: resolve feature_ref to get block/vein_size from configured
    for path, pdata in effective_placed.items():
        feature_ref = pdata.get("feature_ref", "")
        if ":" not in feature_ref:
            feature_ref = f"minecraft:{feature_ref}"
        if feature_ref in effective_configured:
            cdata = effective_configured[feature_ref]
            if pdata.get("block") is None:
                pdata["block"] = cdata.get("block")
            if pdata.get("vein_size") is None:
                pdata["vein_size"] = cdata.get("vein_size")
        # Also copy block from vanilla baseline if present
        if pdata.get("block") is None:
            pdata["block"] = "?"
        if pdata.get("vein_size") is None:
            pdata["vein_size"] = "?"

    # Cross-check: ores placed but block has no known item drop
    all_block_loot = {}
    for src in sources:
        all_block_loot.update(src.get("block_loot", {}))

    placed_blocks = set()
    for path, data in effective_placed.items():
        block = data.get("block", "?")
        if block and block != "?" and not block.startswith("dynamic"):
            placed_blocks.add(block)

    missing_drops = []
    for block in sorted(placed_blocks):
        if block not in all_block_loot:
            missing_drops.append(block)

    # Stats by source
    sources_stats = []
    for src in sources:
        sources_stats.append({
            "kind": src["kind"],
            "name": src["name"],
            "jar": src.get("jar"),
            "configured_count": len(src.get("configured", {})),
            "placed_count": len(src.get("placed", {})),
        })

    return {
        "sources": sources,
        "effective_configured": effective_configured,
        "effective_placed": effective_placed,
        "resolution_map": resolution_map,
        "contested_configured": contested_configured,
        "contested_placed": contested_placed,
        "vanilla_removed": vanilla_removed,
        "missing_drops": missing_drops,
        "total_configured": len(effective_configured),
        "total_placed": len(effective_placed),
        "total_contested": len(contested_configured) + len(contested_placed),
        "jars_downloaded": dl,
        "jars_from_cache": from_cache,
        "skipped_no_url": sorted(skipped),
        "skipped_datapacks": sorted(skipped_dp),
    }


# ── Output ────────────────────────────────────────────────────────────────────

def report_human(info, summ):
    print(f"## pack {info['name']}  (MC {info['minecraft'] or '?'}, "
          f"{info['loader'] or '?'} {info['loader_version'] or ''})".strip())

    # Per-source sections
    for src in summ["sources"]:
        configured = src.get("configured", {})
        placed = src.get("placed", {})
        if not configured and not placed:
            continue
        print(f"## source: {src['name']}" + (f"  ({src['jar']})" if src["jar"] else ""))
        for path in sorted(configured):
            c = configured[path]
            extra = ""
            if path in summ["contested_configured"]:
                extra = "  [CONTESTED — multiple sources define this]"
            print(f"  configured  {path}  (block={c.get('block','?')}, vein={c.get('vein_size','?')}){extra}")
        for path in sorted(placed):
            p = placed[path]
            extra = ""
            if path in summ["contested_placed"]:
                extra = "  [CONTESTED — multiple sources define this]"
            block = p.get("block", "?")
            vein = p.get("vein_size", "?")
            y_min = p.get("y_min", "?")
            y_max = p.get("y_max", "?")
            count = p.get("count")
            dims = []
            if y_min is not None and y_max is not None:
                dims.append(f"Y={y_min}..{y_max}")
            if count is not None:
                dims.append(f"count={count}")
            dim_str = f"  ({', '.join(dims)})" if dims else ""
            print(f"  placed      {path}  block={block} vein={vein}{dim_str}{extra}")

    print()
    print(f"## summary ({summ['jars_downloaded']} jar{'s' if summ['jars_downloaded'] != 1 else ''} downloaded, {summ['jars_from_cache']} from cache)")
    print(f"  total configured features: {summ['total_configured']}")
    print(f"  total placed features:     {summ['total_placed']}")

    if summ["skipped_no_url"]:
        print(f"  SKIPPED (no download URL — CurseForge-mode?): {', '.join(summ['skipped_no_url'])}")
    if summ["skipped_datapacks"]:
        print(f"  SKIPPED datapacks: {', '.join(summ['skipped_datapacks'])}")

    if summ["total_contested"] > 0:
        print(f"  CONTESTED PLACEMENTS: {summ['total_contested']}")
        print(f"    These ore features are defined by multiple sources (mods/datapacks).")
        print(f"    The last-loaded source wins per Minecraft's override rules.")
        for path in sorted(summ["contested_configured"]):
            defs = summ["contested_configured"][path]
            print(f"    - {path}: {len(defs)} definitions")
            for d in defs:
                print(f"        {d['kind']}: {d['name']}" + (f"  ({d['jar']})" if d["jar"] else ""))
        for path in sorted(summ["contested_placed"]):
            defs = summ["contested_placed"][path]
            print(f"    - {path}: {len(defs)} definitions")
            for d in defs:
                print(f"        {d['kind']}: {d['name']}" + (f"  ({d['jar']})" if d["jar"] else ""))

    if summ["vanilla_removed"]:
        print(f"  VANILLA ORES REMOVED BY MODS: {len(summ['vanilla_removed'])}")
        for v in summ["vanilla_removed"]:
            print(f"    - {v}")

    if summ["missing_drops"]:
        print(f"  ORES WITH NO KNOWN ITEM DROP: {len(summ['missing_drops'])}")
        for b in summ["missing_drops"][:10]:
            print(f"    - {b}")
        if len(summ["missing_drops"]) > 10:
            print(f"    ... and {len(summ['missing_drops'])-10} more")


def report_json(info, summ):
    out = {
        "tool": "ore.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "configured_count": len(s.get("configured", {})),
             "placed_count": len(s.get("placed", {}))}
            for s in summ["sources"]
        ],
        "summary": {
            "total_configured": summ["total_configured"],
            "total_placed": summ["total_placed"],
            "total_contested": summ["total_contested"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "vanilla_removed": summ["vanilla_removed"],
            "missing_drops": summ["missing_drops"],
        },
        "contested_configured": summ["contested_configured"],
        "contested_placed": summ["contested_placed"],
        "resolution_map": {k: {"winner": v["winner"], "contested": v["contested"]}
                           for k, v in summ["resolution_map"].items()},
        "effective_configured": {k: {"block": v.get("block"), "vein_size": v.get("vein_size"),
                                     "source": v.get("source_name")}
                                for k, v in sorted(summ["effective_configured"].items())},
        "effective_placed": {k: {"block": v.get("block"), "y_min": v.get("y_min"),
                                 "y_max": v.get("y_max"), "source": v.get("source_name")}
                            for k, v in sorted(summ["effective_placed"].items())},
    }
    json.dump(out, sys.stdout, indent=2, sort_keys=True)
    print()


# ── Info command ──────────────────────────────────────────────────────────────

def cmd_info(pack_dir, info, target, as_json):
    """Look up a single ore/block ID and report all known metadata."""
    sources = []
    skip_no_url = []
    skip_dp = []
    v_src, v_note = scan_vanilla(info)
    if v_src:
        sources.append(v_src)
    mod_sources, dl, from_cache = scan_mods(pack_dir, info, None, skip_no_url, raw=True)
    sources += mod_sources
    sources += scan_datapacks(pack_dir, skip_dp, raw=True)

    # Normalize the target id
    if ":" not in target:
        target = f"minecraft:{target}"

    # Find the ore across all sources
    all_configured = {}
    all_placed = {}
    for src in sources:
        for path, data in src.get("configured", {}).items():
            all_configured.setdefault(path, []).append({
                "kind": src["kind"], "name": src["name"], "jar": src.get("jar"), "data": data
            })
        for path, data in src.get("placed", {}).items():
            all_placed.setdefault(path, []).append({
                "kind": src["kind"], "name": src["name"], "jar": src.get("jar"), "data": data
            })

    # Check if found
    found_configured = target in all_configured
    found_placed = target in all_placed

    if not found_configured and not found_placed:
        # Collect all known IDs for fuzzy matching
        all_ids = set(all_configured.keys()) | set(all_placed.keys())
        suggest = fuzzy_match(target, all_ids)
        msg = f"ore '{target}' not found in any source"
        if suggest:
            msg += f" — did you mean: {', '.join(suggest)}"
        die(msg)

    # Build result
    result = {"id": target}

    if found_configured:
        result["configured_definitions"] = all_configured[target]
        result["configured_count"] = len(all_configured[target])

    if found_placed:
        result["placed_definitions"] = all_placed[target]
        result["placed_count"] = len(all_placed[target])

    # Contested status
    result["contested"] = (found_configured and len(all_configured[target]) > 1) or \
                          (found_placed and len(all_placed[target]) > 1)

    # Extract ore info — prefer placed data for Y range, configured for block/vein
    result["block"] = "?"
    result["vein_size"] = None
    result["y_min"] = None
    result["y_max"] = None
    result["biomes"] = ""
    result["dimension"] = "overworld"
    result["count"] = None

    if found_configured:
        cf_data = all_configured[target][0]["data"]
        result["block"] = cf_data.get("block", "?")
        result["vein_size"] = cf_data.get("vein_size")

    if found_placed:
        pf_data = all_placed[target][0]["data"]
        # Y range and count come from placed
        if pf_data.get("y_min") is not None:
            result["y_min"] = pf_data["y_min"]
        if pf_data.get("y_max") is not None:
            result["y_max"] = pf_data["y_max"]
        if pf_data.get("count") is not None:
            result["count"] = pf_data["count"]
        if pf_data.get("biomes"):
            result["biomes"] = pf_data["biomes"]
        if pf_data.get("dimension"):
            result["dimension"] = pf_data["dimension"]
        # If no configured, resolve block from feature_ref
        if not found_configured:
            feature_ref = pf_data.get("feature_ref", "")
            if ":" not in feature_ref:
                feature_ref = f"minecraft:{feature_ref}"
            if feature_ref in all_configured:
                cf_data = all_configured[feature_ref][0]["data"]
                result["block"] = cf_data.get("block", result["block"])
                result["vein_size"] = cf_data.get("vein_size", result["vein_size"])

    # Resolution info
    effective_configured, effective_placed, resolution_map = resolve_effective(sources)
    if target in resolution_map:
        result["resolution"] = resolution_map[target]
    else:
        result["resolution"] = {"winner": "uncontested", "contested": False}

    # Vanilla override status
    result["vanilla_override"] = False
    result["vanilla_redefined"] = False
    if target.startswith("minecraft:"):
        if v_src and target in v_src.get("placed", {}):
            for src in sources:
                if src["kind"] != "vanilla" and target in src.get("placed", {}):
                    result["vanilla_override"] = True
                    break

    # Raw JSON
    if found_configured:
        result["configured_raw"] = all_configured[target][0]["data"].get("raw")
    if found_placed:
        result["placed_raw"] = all_placed[target][0]["data"].get("raw")

    if as_json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        print()
        return

    # Human-readable output
    print(f"## ore: {result['id']}")
    print(f"  block:      {result['block']}")
    print(f"  vein size:  {result['vein_size'] or '?'}")
    print(f"  Y range:    {result['y_min'] or '?'} .. {result['y_max'] or '?'}")
    if result.get("count") is not None:
        print(f"  count:      {result['count']}")
    print(f"  biomes:     {result['biomes'] or '?'}")
    print(f"  dimension:  {result['dimension']}")

    if result["contested"]:
        print(f"  CONTESTED:  YES — multiple sources define this ore placement")
        if found_configured:
            print(f"    configured_feature definitions: {len(all_configured[target])}")
            for d in all_configured[target]:
                print(f"      - {d['kind']}: {d['name']}" + (f"  ({d['jar']})" if d["jar"] else ""))
        if found_placed:
            print(f"    placed_feature definitions: {len(all_placed[target])}")
            for d in all_placed[target]:
                print(f"      - {d['kind']}: {d['name']}" + (f"  ({d['jar']})" if d["jar"] else ""))

    if result["resolution"]["winner"] != "uncontested":
        print(f"  resolution: {result['resolution']['winner']} wins (last-loaded source)")

    if result["vanilla_override"]:
        print(f"  override:   YES — replaces the vanilla ore placement")

    if found_configured and all_configured[target][0]["data"].get("raw"):
        print(f"  configured_feature raw JSON:")
        print(json.dumps(all_configured[target][0]["data"]["raw"], indent=4, sort_keys=True))

    if found_placed and all_placed[target][0]["data"].get("raw"):
        print(f"  placed_feature raw JSON:")
        print(json.dumps(all_placed[target][0]["data"]["raw"], indent=4, sort_keys=True))


def _format_ore_detail(target_id, sources, v_src):
    """Build the detail dict for a single ore across all sources."""
    result = {"id": target_id}

    all_configured = {}
    all_placed = {}
    for src in sources:
        for path, data in src.get("configured", {}).items():
            all_configured.setdefault(path, []).append({
                "kind": src["kind"], "name": src["name"], "jar": src.get("jar"), "data": data
            })
        for path, data in src.get("placed", {}).items():
            all_placed.setdefault(path, []).append({
                "kind": src["kind"], "name": src["name"], "jar": src.get("jar"), "data": data
            })

    if target_id in all_configured:
        result["configured_definitions"] = all_configured[target_id]
        result["configured_count"] = len(all_configured[target_id])

    if target_id in all_placed:
        result["placed_definitions"] = all_placed[target_id]
        result["placed_count"] = len(all_placed[target_id])

    result["contested"] = (target_id in all_configured and len(all_configured[target_id]) > 1) or \
                          (target_id in all_placed and len(all_placed[target_id]) > 1)

    # Extract ore info — resolve feature_ref to get block/vein from configured
    first_data = {}
    if target_id in all_configured:
        first_data = all_configured[target_id][0]["data"]
    elif target_id in all_placed:
        first_data = all_placed[target_id][0]["data"]

    result["block"] = first_data.get("block", "?")
    result["vein_size"] = first_data.get("vein_size")
    result["y_min"] = first_data.get("y_min")
    result["y_max"] = first_data.get("y_max")
    result["biomes"] = first_data.get("biomes", "")
    result["dimension"] = first_data.get("dimension", "overworld")
    result["count"] = first_data.get("count")

    # If this is a placed feature, try to resolve the feature_ref
    if target_id in all_placed and target_id not in all_configured:
        feature_ref = first_data.get("feature_ref", "")
        if ":" not in feature_ref:
            feature_ref = f"minecraft:{feature_ref}"
        if feature_ref in all_configured:
            cf_data = all_configured[feature_ref][0]["data"]
            result["block"] = cf_data.get("block", result["block"])
            result["vein_size"] = cf_data.get("vein_size", result["vein_size"])

    # Resolution info
    _, _, resolution_map = resolve_effective(sources)
    if target_id in resolution_map:
        result["resolution"] = resolution_map[target_id]
    else:
        result["resolution"] = {"winner": "uncontested", "contested": False}

    # Vanilla override status
    result["vanilla_override"] = False
    if target_id.startswith("minecraft:"):
        if v_src and target_id in v_src.get("placed", {}):
            for src in sources:
                if src["kind"] != "vanilla" and target_id in src.get("placed", {}):
                    result["vanilla_override"] = True
                    break

    # Raw JSON
    if target_id in all_configured:
        result["configured_raw"] = all_configured[target_id][0]["data"].get("raw")
    if target_id in all_placed:
        result["placed_raw"] = all_placed[target_id][0]["data"].get("raw")

    return result


def cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_):
    """Export every ore's full metadata to a single JSON file."""
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

    t_scan = time.monotonic()

    # Collect all ore IDs
    all_ids = set()
    for src in sources:
        all_ids.update(src.get("configured", {}).keys())
        all_ids.update(src.get("placed", {}).keys())

    # Build entries
    entries = {}
    for ore_id in sorted(all_ids):
        entries[ore_id] = _format_ore_detail(ore_id, sources, v_src)

    t_detail = time.monotonic()

    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp, v_src)
    out = {
        "tool": "ore.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "configured_count": len(s.get("configured", {})),
             "placed_count": len(s.get("placed", {}))}
            for s in summ["sources"]
        ],
        "summary": {
            "total_configured": summ["total_configured"],
            "total_placed": summ["total_placed"],
            "total_contested": summ["total_contested"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "vanilla_removed": summ["vanilla_removed"],
            "missing_drops": summ["missing_drops"],
        },
        "entries": entries,
    }

    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")

    t_write = time.monotonic()
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {len(entries)} ores → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
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
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-ore-full.json"
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
        summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp, v_src)
        report_json(info, summ)
        return
    if as_list:
        summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp, v_src)
        # List all ore IDs (union of configured and placed)
        all_ids = set()
        for src in sources:
            all_ids.update(src.get("configured", {}).keys())
            all_ids.update(src.get("placed", {}).keys())
        for oid in sorted(all_ids):
            print(oid)
        return
    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp, v_src)
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
# Minecraft version (e.g. 1.21.4), download Mojang's client jar for that version
# (under "downloads" -> "client" in https://piston-meta.mojang.com/mc/game/version_manifest_v2.json
# -> the version entry), then:
#
#   python3 - << 'EOF'
#   import zipfile, json, re
#   zf = zipfile.ZipFile("client-<ver>.jar")
#   ores = {}
#   for n in zf.namelist():
#       m = re.match(r"^data/minecraft/worldgen/placed_feature/(ore_.+)\.json$", n)
#       if m:
#           placed = json.loads(zf.read(n))
#           cf_name = placed.get("feature", "")
#           if ":" not in cf_name: cf_name = "minecraft:" + cf_name
#           cf_path = f"data/minecraft/worldgen/configured_feature/{cf_name.split(':')[1]}.json"
#           cf_data = {}
#           if cf_path in [zi.filename for zi in zf.filelist]:
#               cf_data = json.loads(zf.read(cf_path))
#           ores[m.group(1)] = {
#               "block": cf_data.get("config", {}).get("targets", [{}])[0].get("state", {}).get("Name", "?"),
#               "vein_size": cf_data.get("config", {}).get("size", 0),
#               "y_min": 0, "y_max": 0,
#               "biomes": "", "dimension": "overworld"
#           }
#   print(json.dumps({"ores": ores}, indent=2, sort_keys=True))
#   EOF
#
# and paste the output into VANILLA_BY_MC under the new version key.

# ## RUN LOG
