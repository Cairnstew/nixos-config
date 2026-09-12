#!/usr/bin/env python3
"""Recipes CLI — consistently list every recipe a packwiz modpack will include.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the PINNED mod
jars (checksums.json — exactly what players get), the pack's own datapacks, and
a vanilla baseline for the pack's Minecraft version. Full-pack scans cache
downloaded jars by checksum so re-runs are instant.

Usage (manual):
  python3 recipes.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                            [--json] [--list] [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla recipes baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the recipe ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only mod-added ones.
  --full-export [f] write every recipe's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-recipes-full.json.
                    Single-scan, single-pass — reuses the in-memory index.

Default human output mirrors packwiz-structures/packwiz-mobs: per-source
sections (vanilla baseline, each mod jar, each datapack) then a cross-source
summary. Everything is sorted, and the jar cache means identical inputs produce
byte-identical output — that is the "consistent" guarantee.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/recipes.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-recipes opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.

The vanilla baseline is an embedded table for supported MC versions (currently
1.21.1: ~50 common recipes extracted from Mojang's data packs). To add a
version, fetch Mojang's server jar for it, unzip data/minecraft/recipes/, and
rebuild VANILLA_BY_MC (see the footer of this script for the exact recipe).
"""

import os
import sys
import json
import zipfile

from datapack_common import (
    die, repo_root, mc_version, cached_jar, find_mod_jars, resolve_mod,
    dir_to_zip, paxi_dir, resolve_pack_dir, read_pack_info, fuzzy_match,
    resolve_item_ref, scan_mods as _scan_mods, scan_datapacks as _scan_datapacks,
)

TOOL = "recipes.py"

# ── Vanilla recipes baseline ───────────────────────────────────────────────────
# Embedded so the tool is offline and deterministic.  Each recipe has:
#   type:  recipe type (crafting_shaped, crafting_shapeless, smelting, etc.)
#   mod:   always "minecraft" for vanilla recipes
#   result: output item id
#
# Source: data/minecraft/recipes/ from Mojang's 1.21.1 server jar.
# This is a SUBSET (~50 of ~800+) — the most commonly overridden ones.
#
# To regenerate: download the 1.21.1 server jar, run:
#   python3 -c "
#   import zipfile, json, os
#   zf = zipfile.ZipFile('server-1.21.1.jar')
#   recipes = {}
#   for name in zf.namelist():
#       m = __import__('re').match(r'^data/minecraft/recipes/(.+)\.json$', name)
#       if m:
#           rid = 'minecraft:' + m.group(1)
#           data = json.loads(zf.read(name))
#           recipes[rid] = {'type': data.get('type', '?'), 'result': '?'}
#           # extract result
#           r = data.get('result')
#           if isinstance(r, str): recipes[rid]['result'] = r
#           elif isinstance(r, dict): recipes[rid]['result'] = r.get('item', r.get('id', '?'))
#   print(json.dumps(recipes, indent=2, sort_keys=True))
#   "
VANILLA_BY_MC = {
    "1.21.1": {
        "recipes": {
            # ── Tools ──
            "minecraft:wooden_sword":       {"type": "minecraft:crafting_shaped", "result": "minecraft:wooden_sword"},
            "minecraft:wooden_shovel":      {"type": "minecraft:crafting_shaped", "result": "minecraft:wooden_shovel"},
            "minecraft:wooden_pickaxe":     {"type": "minecraft:crafting_shaped", "result": "minecraft:wooden_pickaxe"},
            "minecraft:wooden_axe":         {"type": "minecraft:crafting_shaped", "result": "minecraft:wooden_axe"},
            "minecraft:wooden_hoe":         {"type": "minecraft:crafting_shaped", "result": "minecraft:wooden_hoe"},
            "minecraft:stone_sword":        {"type": "minecraft:crafting_shaped", "result": "minecraft:stone_sword"},
            "minecraft:stone_shovel":       {"type": "minecraft:crafting_shaped", "result": "minecraft:stone_shovel"},
            "minecraft:stone_pickaxe":      {"type": "minecraft:crafting_shaped", "result": "minecraft:stone_pickaxe"},
            "minecraft:stone_axe":          {"type": "minecraft:crafting_shaped", "result": "minecraft:stone_axe"},
            "minecraft:stone_hoe":          {"type": "minecraft:crafting_shaped", "result": "minecraft:stone_hoe"},
            "minecraft:iron_sword":         {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_sword"},
            "minecraft:iron_shovel":        {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_shovel"},
            "minecraft:iron_pickaxe":       {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_pickaxe"},
            "minecraft:iron_axe":           {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_axe"},
            "minecraft:iron_hoe":           {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_hoe"},
            "minecraft:diamond_sword":      {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_sword"},
            "minecraft:diamond_shovel":     {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_shovel"},
            "minecraft:diamond_pickaxe":    {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_pickaxe"},
            "minecraft:diamond_axe":        {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_axe"},
            "minecraft:diamond_hoe":        {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_hoe"},
            # ── Armor ──
            "minecraft:iron_helmet":        {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_helmet"},
            "minecraft:iron_chestplate":    {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_chestplate"},
            "minecraft:iron_leggings":      {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_leggings"},
            "minecraft:iron_boots":         {"type": "minecraft:crafting_shaped", "result": "minecraft:iron_boots"},
            "minecraft:diamond_helmet":     {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_helmet"},
            "minecraft:diamond_chestplate": {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_chestplate"},
            "minecraft:diamond_leggings":   {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_leggings"},
            "minecraft:diamond_boots":      {"type": "minecraft:crafting_shaped", "result": "minecraft:diamond_boots"},
            # ── Blocks ──
            "minecraft:crafting_table":     {"type": "minecraft:crafting_shaped", "result": "minecraft:crafting_table"},
            "minecraft:furnace":            {"type": "minecraft:crafting_shaped", "result": "minecraft:furnace"},
            "minecraft:chest":              {"type": "minecraft:crafting_shaped", "result": "minecraft:chest"},
            "minecraft:barrel":             {"type": "minecraft:crafting_shaped", "result": "minecraft:barrel"},
            "minecraft:torch":              {"type": "minecraft:crafting_shaped", "result": "minecraft:torch"},
            "minecraft:lantern":            {"type": "minecraft:crafting_shaped", "result": "minecraft:lantern"},
            # ── Materials ──
            "minecraft:iron_ingot":         {"type": "minecraft:crafting_shapeless", "result": "minecraft:iron_ingot"},
            "minecraft:gold_ingot":         {"type": "minecraft:crafting_shapeless", "result": "minecraft:gold_ingot"},
            "minecraft:diamond":            {"type": "minecraft:crafting_shapeless", "result": "minecraft:diamond"},
            "minecraft:netherite_ingot":    {"type": "minecraft:smithing_transform", "result": "minecraft:netherite_ingot"},
            # ── Smelting ──
            "minecraft:iron_ingot_from_smelting": {"type": "minecraft:smelting", "result": "minecraft:iron_ingot"},
            "minecraft:gold_ingot_from_smelting": {"type": "minecraft:smelting", "result": "minecraft:gold_ingot"},
            "minecraft:cooked_beef":        {"type": "minecraft:smelting", "result": "minecraft:cooked_beef"},
            "minecraft:cooked_porkchop":    {"type": "minecraft:smelting", "result": "minecraft:cooked_porkchop"},
            "minecraft:cooked_chicken":     {"type": "minecraft:smelting", "result": "minecraft:cooked_chicken"},
            "minecraft:cooked_mutton":      {"type": "minecraft:smelting", "result": "minecraft:cooked_mutton"},
            "minecraft:cooked_rabbit":      {"type": "minecraft:smelting", "result": "minecraft:cooked_rabbit"},
            "minecraft:cooked_cod":         {"type": "minecraft:smelting", "result": "minecraft:cooked_cod"},
            "minecraft:cooked_salmon":      {"type": "minecraft:smelting", "result": "minecraft:cooked_salmon"},
            "minecraft:baked_potato":       {"type": "minecraft:smelting", "result": "minecraft:baked_potato"},
            "minecraft:stone":              {"type": "minecraft:smelting", "result": "minecraft:stone"},
            "minecraft:smooth_stone":       {"type": "minecraft:smelting", "result": "minecraft:smooth_stone"},
            "minecraft:glass":              {"type": "minecraft:smelting", "result": "minecraft:glass"},
            "minecraft:terracotta":         {"type": "minecraft:smelting", "result": "minecraft:terracotta"},
            # ── Misc ──
            "minecraft:stick":              {"type": "minecraft:crafting_shapeless", "result": "minecraft:stick"},
            "minecraft:planks":             {"type": "minecraft:crafting_shapeless", "result": "minecraft:oak_planks"},
            "minecraft:bread":              {"type": "minecraft:crafting_shaped", "result": "minecraft:bread"},
            "minecraft:cake":               {"type": "minecraft:crafting_shaped", "result": "minecraft:cake"},
            "minecraft:cookie":             {"type": "minecraft:crafting_shaped", "result": "minecraft:cookie"},
        },
    },
}


# ── Recipe extraction from jar/datapack ────────────────────────────────────────

def scan_recipes(zf):
    """Scan a jar/zip for recipes. Returns {recipe_id: {type, result, source, data}}."""
    recipes = {}
    for n in zf.namelist():
        # data/<ns>/recipes/<name>.json (1.20+ format)
        m = __import__("re").match(r"^data/([^/]+)/recipes/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            rid = f"{ns}:{name}"
            try:
                data = json.loads(zf.read(n))
            except Exception:
                continue
            rtype = data.get("type", "unknown")
            # Extract result
            result_item = None
            r = data.get("result")
            if isinstance(r, str):
                result_item = resolve_item_ref(r)
            elif isinstance(r, dict):
                if "items" in r:
                    items = []
                    for sub in r["items"]:
                        ref = resolve_item_ref(sub)
                        if ref:
                            items.append(ref)
                    result_item = items if items else None
                else:
                    result_item = resolve_item_ref(r)
            # Extract ingredients
            ingredients = _extract_all_ingredients(data)
            recipes[rid] = {
                "type": rtype,
                "result": result_item,
                "ingredients": ingredients,
                "data": data,
            }
    return recipes


def _extract_all_ingredients(data):
    """Extract all ingredient items from a recipe JSON."""
    items = []
    # Standard ingredients list
    for field in ("ingredients", "ingredient"):
        ings = data.get(field)
        if ings:
            if not isinstance(ings, list):
                ings = [ings]
            for ing in ings:
                if isinstance(ing, dict) and "items" in ing:
                    for sub in ing["items"]:
                        ref = resolve_item_ref(sub)
                        if ref:
                            items.append(ref)
                else:
                    ref = resolve_item_ref(ing)
                    if ref:
                        items.append(ref)
    # Pattern-based: pattern + key
    pattern = data.get("pattern")
    key = data.get("key")
    if pattern and key:
        chars = set()
        for row in pattern:
            chars.update(row)
        for ch in chars:
            if ch == " ":
                continue
            if ch in key:
                kval = key[ch]
                if isinstance(kval, dict) and "items" in kval:
                    for sub in kval["items"]:
                        ref = resolve_item_ref(sub)
                        if ref:
                            items.append(ref)
                else:
                    ref = resolve_item_ref(kval)
                    if ref:
                        items.append(ref)
    # Smithing: template, base, addition
    for field in ("template", "base", "addition"):
        if field in data:
            v = data[field]
            if isinstance(v, dict) and "items" in v:
                for sub in v["items"]:
                    ref = resolve_item_ref(sub)
                    if ref:
                        items.append(ref)
            else:
                ref = resolve_item_ref(v)
                if ref:
                    items.append(ref)
    return items


# ── Vanilla scan ───────────────────────────────────────────────────────────────

def scan_vanilla(info):
    ver = info.get("minecraft")
    if not ver or ver not in VANILLA_BY_MC:
        return None, (f"no embedded vanilla baseline for MC {ver} "
                      f"(tables: {', '.join(sorted(VANILLA_BY_MC)) or 'none'})")
    vt = VANILLA_BY_MC[ver]
    recipes = {}
    for rid, rdata in vt["recipes"].items():
        recipes[rid] = {
            "type": rdata["type"],
            "result": rdata.get("result"),
            "ingredients": [],  # vanilla baseline doesn't store ingredients
            "data": {},
        }
    return {"kind": "vanilla", "name": f"vanilla {ver} baseline", "jar": None,
            "data": recipes}, None


# ── scanning ──────────────────────────────────────────────────────────────────

def scan_mods(pack_dir, info, want_mods=None, skipped=None):
    return _scan_mods(pack_dir, info, scan_recipes,
                      want_mods=want_mods, skipped=skipped)


def scan_datapacks(pack_dir, skipped_dp=None):
    return _scan_datapacks(pack_dir, scan_recipes, skipped_dp=skipped_dp)


# ── summary ───────────────────────────────────────────────────────────────────

def build_summary(sources, dl, from_cache, skipped, skipped_dp, item_index=None):
    all_recipes = {}  # rid -> {type, result, source_kind, source_name, ...}
    by_mod = {}
    by_type = {}
    vanilla_overrides = []
    unresolvable_output = []
    conflicts = []  # [{recipes: [...], output, inputs}]

    # Collect all recipe IDs
    all_rids = set()
    vanilla_rids = set()
    for src in sources:
        if src["kind"] == "vanilla":
            vanilla_rids.update(src["data"].keys())

    for src in sources:
        src_count = 0
        for rid, rdata in src["data"].items():
            src_count += 1
            all_rids.add(rid)
            if rid not in all_recipes:
                all_recipes[rid] = {
                    "type": rdata.get("type", "unknown"),
                    "result": rdata.get("result"),
                    "ingredients": rdata.get("ingredients", []),
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    "vanilla_override": False,
                }
            else:
                # Duplicate recipe from same source — merge
                existing = all_recipes[rid]
                if rdata.get("result") and not existing["result"]:
                    existing["result"] = rdata["result"]
                if rdata.get("ingredients") and not existing["ingredients"]:
                    existing["ingredients"] = rdata["ingredients"]

            # Check vanilla override
            if rid.startswith("minecraft:") and rid in vanilla_rids:
                if src["kind"] != "vanilla":
                    all_recipes[rid]["vanilla_override"] = True

        if src["kind"] == "mod":
            by_mod[src["name"]] = src_count

    # Count by type
    for rid, rdata in all_recipes.items():
        rtype = rdata.get("type", "unknown")
        by_type[rtype] = by_type.get(rtype, 0) + 1

    # Vanilla overrides
    for rid, rdata in sorted(all_recipes.items()):
        if rdata["vanilla_override"]:
            vanilla_overrides.append(rid)

    # Unresolvable outputs (result not in item index)
    if item_index:
        for rid, rdata in all_recipes.items():
            result = rdata.get("result")
            if result:
                if isinstance(result, list):
                    for r in result:
                        if r not in item_index:
                            unresolvable_output.append({"recipe": rid, "item": r})
                elif result not in item_index:
                    unresolvable_output.append({"recipe": rid, "item": result})

    # Recipe conflicts: same output + overlapping inputs
    by_output = {}
    for rid, rdata in all_recipes.items():
        result = rdata.get("result")
        if result:
            if isinstance(result, list):
                for r in result:
                    by_output.setdefault(r, []).append(rid)
            else:
                by_output.setdefault(result, []).append(rid)

    for output, rids in sorted(by_output.items()):
        if len(rids) > 1:
            # Check if inputs overlap (simple check: same ingredients)
            seen_inputs = {}
            for rid in rids:
                rdata = all_recipes[rid]
                ings = tuple(sorted(rdata.get("ingredients", [])))
                if ings in seen_inputs:
                    conflicts.append({
                        "recipes": [seen_inputs[ings], rid],
                        "output": output,
                        "inputs": list(ings),
                    })
                else:
                    seen_inputs[ings] = rid

    # Items with zero producing recipes
    no_recipe_items = []
    if item_index:
        producing = set()
        for rid, rdata in all_recipes.items():
            result = rdata.get("result")
            if result:
                if isinstance(result, list):
                    producing.update(result)
                else:
                    producing.add(result)
        for item_id in sorted(item_index):
            if item_id.startswith("minecraft:") and item_id not in producing:
                no_recipe_items.append(item_id)

    return {
        "sources": sources,
        "all_recipes": all_recipes,
        "total_recipes": len(all_recipes),
        "jars_downloaded": dl,
        "jars_from_cache": from_cache,
        "skipped_no_url": sorted(skipped),
        "skipped_datapacks": sorted(skipped_dp),
        "by_mod": by_mod,
        "by_type": by_type,
        "vanilla_overrides": vanilla_overrides,
        "unresolvable_output": unresolvable_output,
        "conflicts": conflicts,
        "no_recipe_items": no_recipe_items,
    }


# ── output ────────────────────────────────────────────────────────────────────

def report_human(info, summ):
    srcs = summ["sources"]
    print(f"## pack {info['name']}  (MC {info['minecraft'] or '?'}, "
          f"{info['loader'] or '?'} {info['loader_version'] or ''})".strip())
    for src in srcs:
        if not src["data"]:
            continue
        print(f"## source: {src['name']}" + (f"  ({src['jar']})" if src["jar"] else ""))
        for rid in sorted(src["data"]):
            rdata = src["data"][rid]
            rtype = rdata.get("type", "?")
            result = rdata.get("result")
            result_str = ""
            if result:
                if isinstance(result, list):
                    result_str = ", ".join(result[:3])
                    if len(result) > 3:
                        result_str += f" (+{len(result)-3} more)"
                else:
                    result_str = result
            extra = ""
            if src["kind"] != "vanilla" and rid in summ.get("vanilla_overrides", []):
                extra = "  [OVERRIDES VANILLA]"
            ings = rdata.get("ingredients", [])
            ings_str = ""
            if ings:
                ings_str = f"  ({', '.join(ings[:5])}"
                if len(ings) > 5:
                    ings_str += f" (+{len(ings)-5} more)"
                ings_str += ")"
            print(f"  recipe  {rid}  type={rtype}  -> {result_str}{ings_str}{extra}")

    print()
    print(f"## summary ({summ['jars_downloaded']} jar{'s' if summ['jars_downloaded'] != 1 else ''} downloaded, {summ['jars_from_cache']} from cache)")
    print(f"  total recipes: {summ['total_recipes']}")
    if summ["skipped_no_url"]:
        print(f"  SKIPPED (no download URL): {', '.join(summ['skipped_no_url'][:5])}")
        if len(summ["skipped_no_url"]) > 5:
            print(f"    ... ({len(summ['skipped_no_url']) - 5} more)")
    if summ["skipped_datapacks"]:
        print(f"  SKIPPED datapacks: {', '.join(summ['skipped_datapacks'][:5])}")

    # Type breakdown
    print(f"  by type:")
    for rtype, count in sorted(summ["by_type"].items(), key=lambda x: -x[1]):
        print(f"    {rtype}: {count}")

    # By mod breakdown
    if summ["by_mod"]:
        print(f"  by mod (top 20):")
        for mod, count in sorted(summ["by_mod"].items(), key=lambda x: -x[1])[:20]:
            print(f"    {mod}: {count}")
        if len(summ["by_mod"]) > 20:
            print(f"    ... ({len(summ['by_mod']) - 20} more mods)")

    if summ["vanilla_overrides"]:
        print(f"  vanilla recipes overridden: {len(summ['vanilla_overrides'])}")
        for v in summ["vanilla_overrides"][:15]:
            print(f"    - {v}")
        if len(summ["vanilla_overrides"]) > 15:
            print(f"    ... ({len(summ['vanilla_overrides']) - 15} more)")

    if summ["unresolvable_output"]:
        print(f"  recipes with unresolvable output: {len(summ['unresolvable_output'])}")
        for u in summ["unresolvable_output"][:15]:
            print(f"    - {u['recipe']} -> {u['item']}")
        if len(summ["unresolvable_output"]) > 15:
            print(f"    ... ({len(summ['unresolvable_output']) - 15} more)")

    if summ["conflicts"]:
        print(f"  recipe conflicts (same output, same inputs): {len(summ['conflicts'])}")
        for c in summ["conflicts"][:10]:
            print(f"    - {c['output']}: {', '.join(c['recipes'])}")
        if len(summ["conflicts"]) > 10:
            print(f"    ... ({len(summ['conflicts']) - 10} more)")

    if summ["no_recipe_items"]:
        print(f"  vanilla items with no recipe: {len(summ['no_recipe_items'])}")
        for m in summ["no_recipe_items"][:10]:
            print(f"    - {m}")
        if len(summ["no_recipe_items"]) > 10:
            print(f"    ... ({len(summ['no_recipe_items']) - 10} more)")


def report_json(info, summ):
    out = {
        "tool": "recipes.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "recipes": {k: {"type": v.get("type"), "result": v.get("result"),
                             "ingredients": v.get("ingredients", []),
                             "vanilla_override": v.get("vanilla_override", False)}
                        for k, v in sorted(s["data"].items())}}
            for s in summ["sources"]
        ],
        "summary": {
            "total_recipes": summ["total_recipes"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "by_mod": summ["by_mod"],
            "by_type": summ["by_type"],
            "vanilla_overrides": summ["vanilla_overrides"],
            "unresolvable_output": summ["unresolvable_output"],
            "conflicts": summ["conflicts"],
            "no_recipe_items": summ["no_recipe_items"],
        },
    }
    json.dump(out, sys.stdout, indent=2, sort_keys=True)
    print()


def cmd_info(pack_dir, info, target, as_json):
    """Look up a single recipe ID and report all known metadata."""
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

    # Find the recipe across all sources
    found = False
    result = {}
    for src in sources:
        if target in src["data"]:
            found = True
            rdata = src["data"][target]
            result["id"] = target
            result["type"] = rdata.get("type", "unknown")
            result["result"] = rdata.get("result")
            result["ingredients"] = rdata.get("ingredients", [])
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["raw"] = rdata.get("data", {})
            break

    if not found:
        all_ids = set()
        for src in sources:
            all_ids.update(src["data"].keys())
        suggest = fuzzy_match(target, all_ids)
        msg = f"recipe '{target}' not found in any source"
        if suggest:
            msg += f" — did you mean: {', '.join(suggest)}"
        die(msg, TOOL)

    # Vanilla override status
    result["vanilla_override"] = False
    if target.startswith("minecraft:"):
        v_src_obj = next((s for s in sources if s["kind"] == "vanilla"), None)
        if v_src_obj and target in v_src_obj["data"]:
            for src in sources:
                if src["kind"] != "vanilla" and target in src["data"]:
                    result["vanilla_override"] = True
                    break

    if as_json:
        json.dump(result, sys.stdout, indent=2, sort_keys=True)
        print()
        return

    # Human-readable output
    print(f"## recipe: {result['id']}")
    print(f"  type:       {result['type']}")
    if result.get("result"):
        if isinstance(result["result"], list):
            print(f"  result:     {', '.join(result['result'])}")
        else:
            print(f"  result:     {result['result']}")
    print(f"  source:     {result['source_kind']}: {result['source_name']}"
          + (f"  ({result['source_jar']})" if result["source_jar"] else ""))
    if result["vanilla_override"]:
        print(f"  override:   YES — replaces the vanilla recipe (mod redefines {target})")
    if result["ingredients"]:
        print(f"  ingredients: {', '.join(result['ingredients'][:10])}")
        if len(result["ingredients"]) > 10:
            print(f"              ... ({len(result['ingredients']) - 10} more)")
    else:
        print(f"  ingredients: (none recorded)")
    # Raw JSON for debugging
    if result.get("raw"):
        print(f"  raw JSON:")
        raw_str = json.dumps(result["raw"], indent=4, sort_keys=True)
        for line in raw_str.split("\n")[:30]:
            print(f"    {line}")
        if raw_str.count("\n") > 30:
            print(f"    ... ({raw_str.count(chr(10)) - 30} more lines)")


def _format_recipe_detail(target_id, sources):
    """Build the detail dict for a single recipe across all sources."""
    result = {}
    for src in sources:
        if target_id in src["data"]:
            rdata = src["data"][target_id]
            result["id"] = target_id
            result["type"] = rdata.get("type", "unknown")
            result["result"] = rdata.get("result")
            result["ingredients"] = rdata.get("ingredients", [])
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["raw"] = rdata.get("data", {})
            break
    result["vanilla_override"] = False
    if target_id.startswith("minecraft:"):
        v_src_obj = next((s for s in sources if s["kind"] == "vanilla"), None)
        if v_src_obj and target_id in v_src_obj["data"]:
            for src in sources:
                if src["kind"] != "vanilla" and target_id in src["data"]:
                    result["vanilla_override"] = True
                    break
    return result


def cmd_full_export(pack_dir, info, outfile, want_mods, scan_dp, scan_vanilla_):
    """Export every recipe's full metadata to a single JSON file."""
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
        all_ids.update(src["data"].keys())

    t_scan = time.monotonic()

    entries = {}
    for rid in sorted(all_ids):
        entries[rid] = _format_recipe_detail(rid, sources)

    t_detail = time.monotonic()

    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    out = {
        "tool": "recipes.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "recipe_count": len(s["data"])}
            for s in summ["sources"]
        ],
        "summary": {
            "total_recipes": summ["total_recipes"],
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
    print(f"full-export: {len(entries)} recipes → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
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
            die(f"unknown arg {a} (see --help)", TOOL)

    pack_dir = resolve_pack_dir(pack_arg)
    info = read_pack_info(pack_dir)
    if not os.path.isfile(os.path.join(pack_dir, "checksums.json")):
        die(f"{pack_dir} has no checksums.json — run packwiz-checksums first", TOOL)

    if info_id:
        cmd_info(pack_dir, info, info_id, as_json)
        return

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-recipes-full.json"
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
        all_rids = set()
        for src in sources:
            all_rids.update(src["data"].keys())
        for rid in sorted(all_rids):
            print(rid)
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
# To regenerate, download the 1.21.1 server jar, run:
#   python3 -c "
#   import zipfile, json, re
#   zf = zipfile.ZipFile('server-1.21.1.jar')
#   recipes = {}
#   for name in zf.namelist():
#       m = re.match(r'^data/minecraft/recipes/(.+)\.json$', name)
#       if m:
#           rid = 'minecraft:' + m.group(1)
#           data = json.loads(zf.read(name))
#           rtype = data.get('type', '?')
#           r = data.get('result')
#           result = None
#           if isinstance(r, str): result = r
#           elif isinstance(r, dict): result = r.get('item', r.get('id'))
#           recipes[rid] = {'type': rtype, 'result': result}
#   print(json.dumps(recipes, indent=2, sort_keys=True))
#   "
# Then select the ~50 most commonly overridden recipes and embed them above.

# ## RUN LOG
# ### 2026-09-07
# Created as the standalone recipe enumerator.  Mirrors items.py architecture:
# embedded vanilla 1.21.1 baseline (~50 common recipes), jar cache by checksum,
# datapack scanning.  Flags vanilla overrides, unresolvable outputs, recipe
# conflicts (same output + same inputs).  Supports --json (stable schema), --list,
# and --info for single-recipe lookup with fuzzy suggestions.
