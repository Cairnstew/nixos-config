#!/usr/bin/env python3
"""Item Acquisition CLI — consolidate every factual acquisition path for items.

Standalone, stdlib-only. Cross-references recipes, loot tables, ore placements,
mob spawns, and structures to determine HOW each item can be obtained.

No scoring — pure factual consolidation. Each item gets a list of acquisition
paths with concrete evidence (recipe IDs, loot table paths, ore placements, etc.).

Usage (manual):
  python3 item-acquisition.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                                     [--json] [--list] [--info <item>]
                                     [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the item ids, one per line (fastest for piping).
  --info <item>     detailed acquisition info for a single item (fuzzy match on miss).
  --full-export [f] write every item's acquisition record to a single JSON file.
                    If f is omitted, defaults to <packname>-acquisition-full.json.

Acquisition paths (each item may have any subset):
  crafting        — recipe(s) that produce this item, with ingredient items
  smelting        — smelting/blasting/smoking recipe(s) with input item
  loot            — loot table(s) containing this item, with context
  ore             — ore placement data (dimension, Y range, block)
  mob_drop        — mob loot table(s) containing this item
  structure_chest — items found in structure chest loot tables
  fishing         — fishing loot table(s) containing this item
  trade           — villager/wandering trader trade recipe(s)
  tag             — item tags (indicates what categories the item belongs to)
  advancement     — item referenced in advancements

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/item-acquisition.py (scoped-exception
dir — direct RUN LOG edits are expected). Append dated fixes to the // ## RUN LOG
block at the end of THIS file.
"""

import os
import sys
import json
import subprocess
import tempfile
import time

from datapack_common import (
    die, repo_root, resolve_pack_dir, read_pack_info, fuzzy_match,
)

TOOL = "item-acquisition.py"


# ── Known vanilla mob drops ────────────────────────────────────────────────────
# Vanilla entity loot tables have empty items[] in the baseline (scanner limitation).
# This static mapping provides the factual mob-drop data for vanilla mobs.
# Mod mobs are handled by the loot scanner when their jars include pool data.

KNOWN_MOB_DROPS = {
    # Mobs and their guaranteed/likely drops (not exhaustive — common drops only)
    "minecraft:blaze": ["minecraft:blaze_rod"],
    "minecraft:chicken": ["minecraft:chicken", "minecraft:feather"],
    "minecraft:cow": ["minecraft:beef", "minecraft:leather"],
    "minecraft:creeper": ["minecraft:gunpowder"],
    "minecraft:elder_guardian": ["minecraft:prismarine_shard", "minecraft:prismarine_crystals", "minecraft:fish"],
    "minecraft:ender_dragon": ["minecraft:dragon_breath"],
    "minecraft:enderman": ["minecraft:ender_pearl"],
    "minecraft:ghast": ["minecraft:ghast_tear", "minecraft:gunpowder"],
    "minecraft:glow_squid": ["minecraft:glow_ink_sac"],
    "minecraft:guardian": ["minecraft:prismarine_shard", "minecraft:prismarine_crystals", "minecraft:fish"],
    "minecraft:hoglin": ["minecraft:raw_porkchop", "minecraft:leather"],
    "minecraft:husk": ["minecraft:rotten_flesh"],
    "minecraft:magma_cube": ["minecraft:magma_cream"],
    "minecraft:phantom": ["minecraft:phantom_membrane"],
    "minecraft:pig": ["minecraft:raw_porkchop"],
    "minecraft:piglin": ["minecraft:gold_nugget"],
    "minecraft:piglin_brute": ["minecraft:gold_nugget"],
    "minecraft:pillager": ["minecraft:arrow"],
    "minecraft:rabbit": ["minecraft:rabbit_foot", "minecraft:rabbit_hide"],
    "minecraft:salmon": ["minecraft:salmon"],
    "minecraft:sheep": ["minecraft:mutton", "minecraft:white_wool"],
    "minecraft:shulker": ["minecraft:shulker_shell"],
    "minecraft:skeleton": ["minecraft:bone", "minecraft:arrow"],
    "minecraft:slime": ["minecraft:slime_ball"],
    "minecraft:spider": ["minecraft:string", "minecraft:spider_eye"],
    "minecraft:stray": ["minecraft:bone", "minecraft:arrow"],
    "minecraft:vex": ["minecraft:iron_sword"],
    "minecraft:vindicator": ["minecraft:iron_axe"],
    "minecraft:witch": ["minecraft:glowstone_dust", "minecraft:redstone", "minecraft:stick", "minecraft:gunpowder", "minecraft:spider_eye", "minecraft:glass_bottle", "minecraft:sugar"],
    "minecraft:wither_skeleton": ["minecraft:bone", "minecraft:coal"],
    "minecraft:zombie": ["minecraft:rotten_flesh"],
    "minecraft:zombie_villager": ["minecraft:rotten_flesh"],
}


# ── Loot table context inference ──────────────────────────────────────────────

def _loot_context(loot_table_id: str) -> str:
    """Classify a loot table path into an acquisition context."""
    lt = loot_table_id.lower()
    if "fishing" in lt:
        return "fishing"
    if lt.startswith("entities/") or lt.startswith("entity/"):
        return "mob_drop"
    if "chests/" in lt or lt.endswith("_chest"):
        return "structure_chest"
    if lt.startswith("blocks/") or lt.startswith("block/"):
        return "block_drop"
    if lt.startswith("gameplay/"):
        if "piglin" in lt:
            return "piglin_barter"
        return "gameplay"
    if "entity" in lt:
        return "mob_drop"
    return "unknown"


# ── Run a scanner tool's --full-export ────────────────────────────────────────

def _run_scanner(tool_name: str, pack: str, extra_args: list = None) -> dict:
    """Run a scanner tool's --full-export and return the parsed JSON."""
    tool_path = os.path.join(os.path.dirname(__file__), tool_name)
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
        tmp_path = f.name
    try:
        cmd = [sys.executable, tool_path, pack, "--full-export", tmp_path]
        if extra_args:
            cmd.extend(extra_args)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            print(f"  Warning: {tool_name} failed: {result.stderr[:200]}", file=sys.stderr)
            return {}
        with open(tmp_path) as f:
            return json.load(f)
    except Exception as e:
        print(f"  Warning: {tool_name} error: {e}", file=sys.stderr)
        return {}
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)


# ── Core scanner ──────────────────────────────────────────────────────────────

def scan_acquisition(pack_dir, info, pack, want_mods=None, scan_dp=True, scan_van=True):
    """Build acquisition records for every item in the pack."""
    t0 = time.monotonic()

    # Build extra args for scanners
    extra_args = []
    if want_mods:
        extra_args.extend(["--mods", ",".join(want_mods)])
    if not scan_dp:
        extra_args.append("--no-datapacks")
    if not scan_van:
        extra_args.append("--no-vanilla")

    # ── Phase 1: Run all scanners ─────────────────────────────────────────
    print("  Running items scanner...", file=sys.stderr)
    items_data = _run_scanner("items.py", pack, extra_args)
    print("  Running recipes scanner...", file=sys.stderr)
    recipes_data = _run_scanner("recipes.py", pack, extra_args)
    print("  Running loot scanner...", file=sys.stderr)
    loot_data = _run_scanner("loot.py", pack, extra_args)
    print("  Running ore scanner...", file=sys.stderr)
    ore_data = _run_scanner("ore.py", pack, extra_args)
    print("  Running mobspawn scanner...", file=sys.stderr)
    mobspawn_data = _run_scanner("mobspawn.py", pack, extra_args)

    t_scan = time.monotonic()

    # ── Phase 2: Build indices ────────────────────────────────────────────

    # Items index: item_id → metadata
    item_index = {}
    all_item_ids = set()
    for src in items_data.get("sources", []):
        for iid, idata in src.get("items", {}).items():
            if iid not in item_index:
                item_index[iid] = {
                    "id": iid,
                    "category": idata.get("category") or "unknown",
                    "stack": idata.get("stack"),
                    "lang_name": idata.get("lang_name"),
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    "in_recipes": list(idata.get("in_recipes", [])),
                    "in_loot_tables": list(idata.get("in_loot_tables", [])),
                    "in_tags": list(idata.get("in_tags", [])),
                    "in_advancements": list(idata.get("in_advancements", [])),
                }
            all_item_ids.add(iid)

    # Also include items from full-export entries if available
    for iid, idata in items_data.get("entries", {}).items():
        if iid not in item_index:
            item_index[iid] = {
                "id": iid,
                "category": idata.get("category") or "unknown",
                "stack": idata.get("stack"),
                "lang_name": idata.get("lang_name"),
                "source_kind": idata.get("source_kind"),
                "source_name": idata.get("source_name"),
                "source_jar": idata.get("source_jar"),
                "in_recipes": list(idata.get("in_recipes", [])),
                "in_loot_tables": list(idata.get("in_loot_tables", [])),
                "in_tags": list(idata.get("in_tags", [])),
                "in_advancements": list(idata.get("in_advancements", [])),
            }
        all_item_ids.add(iid)

    # Recipes index: result_item_id → list of recipes
    recipe_index = {}
    recipe_detail = {}
    all_recipe_ids = set()
    for rid, rdata in recipes_data.get("entries", {}).items():
        all_recipe_ids.add(rid)
        result = rdata.get("result")
        # Extract item ID from result (may be dict with 'id' or 'item' key)
        if isinstance(result, dict):
            result_id = result.get("id") or result.get("item")
        elif isinstance(result, list):
            result_id = None  # Handle list case separately
        else:
            result_id = result
        if result_id:
            if result_id not in recipe_index:
                recipe_index[result_id] = []
            recipe_index[result_id].append({
                "id": rid,
                "type": rdata.get("type", "unknown"),
                "ingredients": rdata.get("ingredients", []),
                "source_name": rdata.get("source_name"),
                "source_kind": rdata.get("source_kind"),
                "source_jar": rdata.get("source_jar"),
                "raw": rdata.get("raw", {}),
            })
        recipe_detail[rid] = rdata

    # Loot table index: item_id → list of loot tables
    loot_index = {}
    loot_detail = {}
    all_loot_ids = set()
    for tid, tdata in loot_data.get("entries", {}).items():
        all_loot_ids.add(tid)
        loot_detail[tid] = {
            "id": tid,
            "type": tdata.get("type", "unknown"),
            "pools": tdata.get("pools", []),
            "items": tdata.get("items", []),
            "source_name": tdata.get("source_name"),
            "source_kind": tdata.get("source_kind"),
            "source_jar": tdata.get("source_jar"),
        }
        context = _loot_context(tid)
        for item_id in tdata.get("items", []):
            if item_id not in loot_index:
                loot_index[item_id] = []
            loot_index[item_id].append({
                "table_id": tid,
                "context": context,
                "source_name": tdata.get("source_name"),
            })

    # Supplement with known vanilla mob drops (vanilla entity loot tables have empty items[])
    for mob_type, drops in KNOWN_MOB_DROPS.items():
        for item_id in drops:
            if item_id not in loot_index:
                loot_index[item_id] = []
            loot_index[item_id].append({
                "table_id": f"minecraft:entities/{mob_type.split(':')[1]}",
                "context": "mob_drop",
                "source_name": "vanilla game knowledge",
            })

    # Ore index: block_item_id → ore placement data
    ore_index = {}
    for oid, odata in ore_data.get("effective_placed", {}).items():
        block_id = odata.get("block", oid)
        if block_id not in ore_index:
            ore_index[block_id] = []
        ore_index[block_id].append({
            "source": odata.get("source", "unknown"),
            "y_min": odata.get("y_min"),
            "y_max": odata.get("y_max"),
        })

    # Mob spawn index: mob_type → biome list (for cross-referencing mob drops)
    mob_index = {}
    for bid, bdata in mobspawn_data.get("effective_biomes", {}).items():
        for category in ("monster", "creature", "water_creature",
                       "underground_water_creature", "water_ambient", "misc"):
            for entry in bdata.get(category, []):
                mob_type = entry.get("type", "")
                if mob_type not in mob_index:
                    mob_index[mob_type] = []
                mob_index[mob_type].append({
                    "biome_id": bid,
                    "category": category,
                    "weight": entry.get("weight"),
                    "min_count": entry.get("minCount"),
                    "max_count": entry.get("maxCount"),
                })

    t_index = time.monotonic()

    # ── Phase 3: Build acquisition records ─────────────────────────────────

    records = {}
    for item_id in sorted(all_item_ids):
        meta = item_index.get(item_id, {})
        record = {
            "id": item_id,
            "category": meta.get("category", "unknown"),
            "lang_name": meta.get("lang_name"),
            "source_kind": meta.get("source_kind"),
            "source_name": meta.get("source_name"),
            "paths": {},
        }

        # Crafting paths
        crafting_recipes = recipe_index.get(item_id, [])
        non_smelting = [r for r in crafting_recipes
                       if r["type"] not in ("minecraft:smelting", "minecraft:blasting", "minecraft:smoking")]
        if non_smelting:
            record["paths"]["crafting"] = []
            for recipe in non_smelting:
                # Extract ingredient items from raw data
                ingredients = recipe["ingredients"]
                raw = recipe.get("raw", {})
                if "key" in raw:
                    ingredients = []
                    for slot, ref in raw["key"].items():
                        if isinstance(ref, dict):
                            if "item" in ref:
                                ingredients.append(ref["item"])
                            elif "tag" in ref:
                                ingredients.append(f"#{ref['tag']}")
                        elif isinstance(ref, str):
                            ingredients.append(ref)
                elif "ingredients" in raw:
                    ingredients = []
                    for ref in raw["ingredients"]:
                        if isinstance(ref, dict):
                            if "item" in ref:
                                ingredients.append(ref["item"])
                            elif "tag" in ref:
                                ingredients.append(f"#{ref['tag']}")
                        elif isinstance(ref, str):
                            ingredients.append(ref)

                record["paths"]["crafting"].append({
                    "recipe_id": recipe["id"],
                    "recipe_type": recipe["type"],
                    "ingredients": ingredients,
                    "source_name": recipe["source_name"],
                })

        # Smelting paths
        smelting_recipes = [r for r in crafting_recipes
                          if r["type"] in ("minecraft:smelting", "minecraft:blasting", "minecraft:smoking")]
        if smelting_recipes:
            record["paths"]["smelting"] = []
            for recipe in smelting_recipes:
                input_item = None
                raw = recipe.get("raw", {})
                if "ingredient" in raw:
                    ing = raw["ingredient"]
                    if isinstance(ing, str):
                        input_item = ing
                    elif isinstance(ing, dict):
                        input_item = ing.get("item") or ing.get("tag")
                if not input_item and recipe["ingredients"]:
                    input_item = recipe["ingredients"][0]
                record["paths"]["smelting"].append({
                    "recipe_id": recipe["id"],
                    "recipe_type": recipe["type"],
                    "input": input_item,
                    "source_name": recipe["source_name"],
                })

        # Loot paths
        loot_refs = loot_index.get(item_id, [])
        if loot_refs:
            record["paths"]["loot"] = []
            for ref in loot_refs:
                loot_entry = {
                    "table_id": ref["table_id"],
                    "context": ref["context"],
                    "source_name": ref["source_name"],
                }
                # Cross-reference mob drops with mob spawn data
                if ref["context"] == "mob_drop":
                    # Extract mob type from loot table path (e.g., "entities/zombie" → "minecraft:zombie")
                    lt_path = ref["table_id"]
                    if "/" in lt_path:
                        mob_name = lt_path.split("/", 1)[1]
                        mob_type = f"minecraft:{mob_name}" if ":" not in mob_name else mob_name
                    else:
                        mob_type = lt_path

                    # Look up mob spawn data
                    mob_spawns = mob_index.get(mob_type, [])
                    if mob_spawns:
                        # Get unique biomes and spawn categories
                        biomes = list(set(s["biome_id"] for s in mob_spawns))
                        categories = list(set(s["category"] for s in mob_spawns))
                        # Get spawn weight range
                        weights = [s["weight"] for s in mob_spawns if s.get("weight") is not None]
                        min_weight = min(weights) if weights else None
                        max_weight = max(weights) if weights else None
                        loot_entry["mob_type"] = mob_type
                        loot_entry["mob_biomes"] = biomes[:20]  # Cap for readability
                        loot_entry["mob_categories"] = categories
                        loot_entry["mob_spawn_weight"] = {"min": min_weight, "max": max_weight}

                record["paths"]["loot"].append(loot_entry)

        # Ore paths
        ore_refs = ore_index.get(item_id, [])
        if ore_refs:
            record["paths"]["ore"] = ore_refs

        # Tag references
        if meta.get("in_tags"):
            record["paths"]["tag"] = meta["in_tags"]

        # Advancement references
        if meta.get("in_advancements"):
            record["paths"]["advancement"] = meta["in_advancements"]

        records[item_id] = record

    t_build = time.monotonic()

    return {
        "records": records,
        "item_count": len(records),
        "recipe_count": len(all_recipe_ids),
        "loot_table_count": len(all_loot_ids),
        "timing": {
            "scan": t_scan - t0,
            "index": t_index - t_scan,
            "build": t_build - t_index,
            "total": t_build - t0,
        },
    }


# ── CLI ───────────────────────────────────────────────────────────────────────

def cmd_list(result):
    """Print item IDs, one per line."""
    for item_id in sorted(result["records"].keys()):
        print(item_id)


def cmd_info(result, target, as_json=False):
    """Print detailed acquisition info for a single item."""
    records = result["records"]

    # Exact match
    if target in records:
        info = records[target]
    else:
        # Fuzzy match
        matches = fuzzy_match(target, list(records.keys()))
        if not matches:
            die(f"No item found matching '{target}'")
        if len(matches) > 1:
            die(f"Ambiguous '{target}'; did you mean one of: {', '.join(matches[:5])}")
        info = records[matches[0]]

    if as_json:
        print(json.dumps(info, indent=2))
        return

    # Human-readable output
    print(f"Item: {info['id']}")
    print(f"  Category: {info['category']}")
    if info.get("lang_name"):
        print(f"  Name: {info['lang_name']}")
    print(f"  Source: {info['source_name']} ({info['source_kind']})")

    paths = info.get("paths", {})
    if not paths:
        print("  No acquisition paths found.")
        return

    print(f"\n  Acquisition paths:")

    if "crafting" in paths:
        print(f"\n    Crafting ({len(paths['crafting'])} recipe(s)):")
        for p in paths["crafting"]:
            ing_str = ", ".join(p["ingredients"]) if p["ingredients"] else "(unknown)"
            print(f"      {p['recipe_id']} ({p['recipe_type']})")
            print(f"        Ingredients: {ing_str}")
            print(f"        Source: {p['source_name']}")

    if "smelting" in paths:
        print(f"\n    Smelting ({len(paths['smelting'])} recipe(s)):")
        for p in paths["smelting"]:
            print(f"      {p['recipe_id']} ({p['recipe_type']})")
            print(f"        Input: {p['input'] or '(unknown)'}")
            print(f"        Source: {p['source_name']}")

    if "loot" in paths:
        print(f"\n    Loot ({len(paths['loot'])} table(s)):")
        for p in paths["loot"]:
            print(f"      {p['table_id']} [{p['context']}]")
            print(f"        Source: {p['source_name']}")
            if p.get("mob_type"):
                print(f"        Mob: {p['mob_type']}")
                if p.get("mob_biomes"):
                    print(f"        Biomes: {', '.join(p['mob_biomes'][:10])}{'...' if len(p['mob_biomes']) > 10 else ''}")
                if p.get("mob_categories"):
                    print(f"        Spawn category: {', '.join(p['mob_categories'])}")
                if p.get("mob_spawn_weight"):
                    w = p["mob_spawn_weight"]
                    print(f"        Spawn weight: {w['min']}-{w['max']}")

    if "ore" in paths:
        print(f"\n    Ore placement ({len(paths['ore'])} source(s)):")
        for p in paths["ore"]:
            y_range = f"Y {p['y_min']} to {p['y_max']}" if p.get("y_min") is not None else "Y unknown"
            print(f"      {p['source']} — {y_range}")

    if "tag" in paths:
        print(f"\n    Tags ({len(paths['tag'])} tag(s)):")
        for t in paths["tag"][:10]:
            print(f"      {t}")
        if len(paths["tag"]) > 10:
            print(f"      ... and {len(paths['tag']) - 10} more")

    if "advancement" in paths:
        print(f"\n    Advancements ({len(paths['advancement'])} reference(s)):")
        for a in paths["advancement"][:5]:
            print(f"      {a}")
        if len(paths["advancement"]) > 5:
            print(f"      ... and {len(paths['advancement']) - 5} more")


def cmd_json(result):
    """Print the full acquisition records as JSON."""
    print(json.dumps(result["records"], indent=2))


def cmd_full_export(result, info, outfile):
    """Write every item's acquisition record to a single JSON file."""
    import time
    t0 = time.monotonic()

    out = {
        "tool": TOOL,
        "pack": info,
        "version": "1",
        "summary": {
            "item_count": result["item_count"],
            "recipe_count": result["recipe_count"],
            "loot_table_count": result["loot_table_count"],
        },
        "entries": result["records"],
    }

    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")

    t_write = time.monotonic()
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {result['item_count']} items → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
    print(f"  total: {result['timing']['total']:.1f}s  write: {t_write-t0:.1f}s", file=sys.stderr)


def main():
    pack = None
    want_mods = None
    scan_dp = True
    scan_van = True
    as_json = False
    as_list = False
    info_target = None
    full_export = None

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a == "--help" or a == "-h":
            print(__doc__)
            sys.exit(0)
        elif a == "--mods":
            i += 1
            want_mods = [m.strip() for m in args[i].split(",")]
        elif a == "--no-datapacks":
            scan_dp = False
        elif a == "--no-vanilla":
            scan_van = False
        elif a == "--json":
            as_json = True
        elif a == "--list":
            as_list = True
        elif a == "--info":
            i += 1
            info_target = args[i]
        elif a == "--full-export":
            if i + 1 < len(args) and not args[i + 1].startswith("--"):
                i += 1
                full_export = args[i]
            else:
                full_export = True
        elif not a.startswith("-"):
            pack = a
        else:
            die(f"Unknown option: {a}")
        i += 1

    if not pack:
        die("Usage: item-acquisition.py <pack> [--mods ...] [--json] [--list] [--info <item>] [--full-export [file]]")

    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)

    result = scan_acquisition(pack_dir, info, pack, want_mods, scan_dp, scan_van)

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-acquisition-full.json"
        cmd_full_export(result, info, outfile)
    elif as_list:
        cmd_list(result)
    elif info_target:
        cmd_info(result, info_target, as_json)
    elif as_json:
        cmd_json(result)
    else:
        # Default: human-readable summary
        print(f"Item Acquisition — {info.get('name', 'pack')}")
        print(f"  Items: {result['item_count']}")
        print(f"  Recipes: {result['recipe_count']}")
        print(f"  Loot tables: {result['loot_table_count']}")
        print(f"  Timing: scan={result['timing']['scan']:.1f}s  index={result['timing']['index']:.1f}s  build={result['timing']['build']:.1f}s  total={result['timing']['total']:.1f}s")

        # Count items by acquisition path type
        path_counts = {}
        for item_id, record in result["records"].items():
            for path_type in record.get("paths", {}).keys():
                path_counts[path_type] = path_counts.get(path_type, 0) + 1
        print(f"\n  Path coverage:")
        for path_type, count in sorted(path_counts.items(), key=lambda x: -x[1]):
            print(f"    {path_type}: {count} items")


if __name__ == "__main__":
    main()
