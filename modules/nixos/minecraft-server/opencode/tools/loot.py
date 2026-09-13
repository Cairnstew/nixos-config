#!/usr/bin/env python3
"""Loot CLI — consistently list every loot table a packwiz modpack will include.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the PINNED mod
jars (checksums.json — exactly what players get), the pack's own datapacks, and
a vanilla baseline for the pack's Minecraft version. Full-pack scans cache
downloaded jars by checksum so re-runs are instant.

Usage (manual):
  python3 loot.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                         [--json] [--list] [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla loot tables baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the loot table ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only mod-added ones.
  --full-export [f] write every loot table's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-loot-full.json.
                    Single-scan, single-pass — reuses the in-memory index.

Default human output mirrors packwiz-structures/packwiz-mobs: per-source
sections (vanilla baseline, each mod jar, each datapack) then a cross-source
summary. Everything is sorted, and the jar cache means identical inputs produce
byte-identical output — that is the "consistent" guarantee.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/loot.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-loot opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.

The vanilla baseline is an embedded table for supported MC versions (currently
1.21.1: ~30 common loot tables extracted from Mojang's data packs). To add a
version, fetch Mojang's server jar for it, unzip data/minecraft/loot_tables/,
and rebuild VANILLA_BY_MC (see the footer of this script for the exact recipe).
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

TOOL = "loot.py"

# ── Vanilla loot tables baseline ──────────────────────────────────────────────
# Embedded so the tool is offline and deterministic.  Each loot table has:
#   type:  loot table type (entity, chest, block, gameplay, etc.)
#   mod:   always "minecraft" for vanilla tables
#
# Source: data/minecraft/loot_tables/ from Mojang's 1.21.1 server jar.
# This is a SUBSET (~30 of ~200+) — the most commonly overridden ones.
#
# To regenerate: download the 1.21.1 server jar, run:
#   python3 -c "
#   import zipfile, json, re
#   zf = zipfile.ZipFile('server-1.21.1.jar')
#   tables = {}
#   for name in zf.namelist():
#       m = re.match(r'^data/minecraft/loot_tables/(.+)\.json$', name)
#       if m:
#           tid = 'minecraft:' + m.group(1)
#           data = json.loads(zf.read(name))
#           tables[tid] = {'type': data.get('type', '?')}
#   print(json.dumps(tables, indent=2, sort_keys=True))
#   "
VANILLA_BY_MC = {
    "1.21.1": {
        "loot_tables": {
            # ── Block drops ──
            "minecraft:blocks/diamond_ore":      {"type": "minecraft:block"},
            "minecraft:blocks/deepslate_diamond_ore": {"type": "minecraft:block"},
            "minecraft:blocks/gold_ore":         {"type": "minecraft:block"},
            "minecraft:blocks/deepslate_gold_ore": {"type": "minecraft:block"},
            "minecraft:blocks/iron_ore":         {"type": "minecraft:block"},
            "minecraft:blocks/deepslate_iron_ore": {"type": "minecraft:block"},
            "minecraft:blocks/lapis_ore":        {"type": "minecraft:block"},
            "minecraft:blocks/redstone_ore":     {"type": "minecraft:block"},
            "minecraft:blocks/emerald_ore":      {"type": "minecraft:block"},
            "minecraft:blocks/deepslate_emerald_ore": {"type": "minecraft:block"},
            "minecraft:blocks/coal_ore":         {"type": "minecraft:block"},
            "minecraft:blocks/copper_ore":       {"type": "minecraft:block"},
            "minecraft:blocks/ancient_debris":   {"type": "minecraft:block"},
            "minecraft:blocks/obsidian":         {"type": "minecraft:block"},
            "minecraft:blocks/crying_obsidian":  {"type": "minecraft:block"},
            "minecraft:blocks/grass_block":      {"type": "minecraft:block"},
            "minecraft:blocks/dirt":             {"type": "minecraft:block"},
            "minecraft:blocks/sand":             {"type": "minecraft:block"},
            "minecraft:blocks/gravel":           {"type": "minecraft:block"},
            "minecraft:blocks/clay":             {"type": "minecraft:block"},
            "minecraft:blocks/soul_sand":        {"type": "minecraft:block"},
            # ── Entity drops ──
            "minecraft:entities/zombie":         {"type": "minecraft:entity"},
            "minecraft:entities/skeleton":       {"type": "minecraft:entity"},
            "minecraft:entities/creeper":        {"type": "minecraft:entity"},
            "minecraft:entities/spider":         {"type": "minecraft:entity"},
            "minecraft:entities/enderman":       {"type": "minecraft:entity"},
            "minecraft:entities/pig":            {"type": "minecraft:entity"},
            "minecraft:entities/cow":            {"type": "minecraft:entity"},
            "minecraft:entities/sheep":          {"type": "minecraft:entity"},
            "minecraft:entities/chicken":        {"type": "minecraft:entity"},
            "minecraft:entities/wither_skeleton": {"type": "minecraft:entity"},
            "minecraft:entities/blaze":          {"type": "minecraft:entity"},
            "minecraft:entities/ghast":          {"type": "minecraft:entity"},
            "minecraft:entities/ender_dragon":   {"type": "minecraft:entity"},
            # ── Chest loot ──
            "minecraft:chests/abandoned_mineshaft": {"type": "minecraft:chest"},
            "minecraft:chests/desert_pyramid":  {"type": "minecraft:chest"},
            "minecraft:chests/jungle_pyramid":  {"type": "minecraft:chest"},
            "minecraft:chests/simple_dungeon":  {"type": "minecraft:chest"},
            "minecraft:chests/village_blacksmith": {"type": "minecraft:chest"},
            "minecraft:chests/end_city_treasure": {"type": "minecraft:chest"},
            "minecraft:chests/buried_treasure": {"type": "minecraft:chest"},
            # ── Gameplay ──
            "minecraft:gameplay/fishing":       {"type": "minecraft:gameplay"},
            "gameplay/fishing/junk":            {"type": "minecraft:gameplay"},
            "gameplay/fishing/treasure":        {"type": "minecraft:gameplay"},
        },
    },
}


# ── Loot table extraction from jar/datapack ────────────────────────────────────

def scan_loot(zf):
    """Scan a jar/zip for loot tables. Returns {lt_id: {type, pools, items, data}}."""
    tables = {}
    for n in zf.namelist():
        m = re.match(r"^data/([^/]+)/loot_tables?/(.+)\.json$", n)
        if m:
            ns, name = m.group(1), m.group(2)
            lt_id = f"{ns}:{name}"
            try:
                data = json.loads(zf.read(n))
            except Exception:
                continue
            lt_type = data.get("type", "unknown")
            pools = _parse_pools(data)
            items = _extract_items_from_loot(data)
            tables[lt_id] = {
                "type": lt_type,
                "pools": pools,
                "items": items,
                "data": data,
            }
    return tables


def _parse_pools(data):
    """Parse loot table pools into a structured list."""
    raw_pools = data.get("pools", [])
    if not raw_pools and isinstance(data.get("type"), str):
        raw_pools = [data]
    pools = []
    for pool in raw_pools:
        entries = []
        for entry in pool.get("entries", []):
            entries.append(_parse_entry(entry))
        pools.append({
            "rolls": pool.get("rolls", 1),
            "entries": entries,
            "conditions": [c.get("condition", "?") for c in pool.get("conditions", [])],
        })
    return pools


def _parse_entry(entry):
    """Parse a single loot table entry."""
    etype = entry.get("type", "unknown")
    name = entry.get("name", "")
    result = {"type": etype, "name": name}

    # Item count ranges
    functions = entry.get("functions", [])
    for func in functions:
        ftype = func.get("function", "")
        if ftype == "minecraft:set_count":
            count = func.get("count", {})
            if isinstance(count, dict):
                result["min_count"] = count.get("min", 1)
                result["max_count"] = count.get("max", 1)
            else:
                result["min_count"] = count
                result["max_count"] = count
        elif ftype == "minecraft:set_damage":
            damage = func.get("damage", {})
            if isinstance(damage, dict):
                result["min_damage"] = damage.get("min", 0)
                result["max_damage"] = damage.get("max", 1)

    # Condition
    conditions = entry.get("conditions", [])
    if conditions:
        result["conditions"] = [c.get("condition", "?") for c in conditions]

    # Children (for group entries)
    children = entry.get("children", [])
    if children:
        result["children"] = [_parse_entry(c) for c in children]

    return result


def _extract_items_from_loot(data):
    """Extract all item references from a loot table."""
    items = []
    pools = data.get("pools", [])
    if not pools and isinstance(data.get("type"), str):
        pools = [data]
    for pool in pools:
        for entry in pool.get("entries", []):
            _extract_items_from_entry(entry, items)
    return items


def _extract_items_from_entry(entry, items):
    """Recursively extract items from a loot entry."""
    etype = entry.get("type", "")
    if etype == "minecraft:item":
        name = entry.get("name")
        if name:
            ref = resolve_item_ref(name)
            if ref:
                items.append(ref)
    elif etype == "minecraft:loot_table":
        ref = entry.get("name")
        if ref:
            items.append(ref)
    # Children
    for child in entry.get("children", []):
        _extract_items_from_entry(child, items)
    # Functions can reference items
    for func in entry.get("functions", []):
        ftype = func.get("function", "")
        # Some functions reference items (e.g. set_contents)
        for key in ("entries", "data"):
            if key in func:
                v = func[key]
                if isinstance(v, list):
                    for sub in v:
                        if isinstance(sub, dict):
                            _extract_items_from_entry(sub, items)


# ── Vanilla scan ───────────────────────────────────────────────────────────────

def scan_vanilla(info):
    ver = info.get("minecraft")
    if not ver or ver not in VANILLA_BY_MC:
        return None, (f"no embedded vanilla baseline for MC {ver} "
                      f"(tables: {', '.join(sorted(VANILLA_BY_MC)) or 'none'})")
    vt = VANILLA_BY_MC[ver]
    tables = {}
    for tid, tdata in vt["loot_tables"].items():
        tables[tid] = {
            "type": tdata["type"],
            "pools": [],  # vanilla baseline doesn't store full pool data
            "items": [],
            "data": {},
        }
    return {"kind": "vanilla", "name": f"vanilla {ver} baseline", "jar": None,
            "data": tables}, None


# ── scanning ──────────────────────────────────────────────────────────────────

def scan_mods(pack_dir, info, want_mods=None, skipped=None):
    return _scan_mods(pack_dir, info, scan_loot,
                      want_mods=want_mods, skipped=skipped)


def scan_datapacks(pack_dir, skipped_dp=None):
    return _scan_datapacks(pack_dir, scan_loot, skipped_dp=skipped_dp)


# ── summary ───────────────────────────────────────────────────────────────────

def build_summary(sources, dl, from_cache, skipped, skipped_dp, item_index=None):
    all_tables = {}  # lt_id -> {type, pools, items, source_kind, ...}
    by_mod = {}
    by_type = {}
    vanilla_overrides = []
    unresolved_items = []
    empty_tables = []

    # Collect all loot table IDs
    all_lt_ids = set()
    vanilla_lt_ids = set()
    for src in sources:
        if src["kind"] == "vanilla":
            vanilla_lt_ids.update(src["data"].keys())

    for src in sources:
        src_count = 0
        for lt_id, ltdata in src["data"].items():
            src_count += 1
            all_lt_ids.add(lt_id)
            if lt_id not in all_tables:
                all_tables[lt_id] = {
                    "type": ltdata.get("type", "unknown"),
                    "pools": ltdata.get("pools", []),
                    "items": ltdata.get("items", []),
                    "source_kind": src["kind"],
                    "source_name": src["name"],
                    "source_jar": src.get("jar"),
                    "vanilla_override": False,
                }
            else:
                existing = all_tables[lt_id]
                if ltdata.get("pools") and not existing["pools"]:
                    existing["pools"] = ltdata["pools"]
                if ltdata.get("items") and not existing["items"]:
                    existing["items"] = ltdata["items"]

            # Check vanilla override
            if lt_id.startswith("minecraft:") and lt_id in vanilla_lt_ids:
                if src["kind"] != "vanilla":
                    all_tables[lt_id]["vanilla_override"] = True

        if src["kind"] == "mod":
            by_mod[src["name"]] = src_count

    # Count by type
    for lt_id, ltdata in all_tables.items():
        lttype = ltdata.get("type", "unknown")
        by_type[lttype] = by_type.get(lttype, 0) + 1

    # Vanilla overrides
    for lt_id, ltdata in sorted(all_tables.items()):
        if ltdata["vanilla_override"]:
            vanilla_overrides.append(lt_id)

    # Unresolved items (item references not in item index)
    if item_index:
        for lt_id, ltdata in all_tables.items():
            for item_ref in ltdata.get("items", []):
                if item_ref not in item_index:
                    unresolved_items.append({"loot_table": lt_id, "item": item_ref})

    # Empty tables (no pools or all pools have no entries)
    for lt_id, ltdata in all_tables.items():
        pools = ltdata.get("pools", [])
        if not pools:
            empty_tables.append(lt_id)
        elif all(not p.get("entries") for p in pools):
            empty_tables.append(lt_id)

    return {
        "sources": sources,
        "all_tables": all_tables,
        "total_tables": len(all_tables),
        "jars_downloaded": dl,
        "jars_from_cache": from_cache,
        "skipped_no_url": sorted(skipped),
        "skipped_datapacks": sorted(skipped_dp),
        "by_mod": by_mod,
        "by_type": by_type,
        "vanilla_overrides": vanilla_overrides,
        "unresolved_items": unresolved_items,
        "empty_tables": empty_tables,
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
        for lt_id in sorted(src["data"]):
            ltdata = src["data"][lt_id]
            lttype = ltdata.get("type", "?")
            items = ltdata.get("items", [])
            items_str = ""
            if items:
                items_str = f"  items: {', '.join(items[:5])}"
                if len(items) > 5:
                    items_str += f" (+{len(items)-5} more)"
            pools = ltdata.get("pools", [])
            pools_str = f"  pools: {len(pools)}" if pools else ""
            extra = ""
            if src["kind"] != "vanilla" and lt_id in summ.get("vanilla_overrides", []):
                extra = "  [OVERRIDES VANILLA]"
            print(f"  loot    {lt_id}  type={lttype}{pools_str}{items_str}{extra}")

    print()
    print(f"## summary ({summ['jars_downloaded']} jar{'s' if summ['jars_downloaded'] != 1 else ''} downloaded, {summ['jars_from_cache']} from cache)")
    print(f"  total loot tables: {summ['total_tables']}")
    if summ["skipped_no_url"]:
        print(f"  SKIPPED (no download URL): {', '.join(summ['skipped_no_url'][:5])}")
        if len(summ["skipped_no_url"]) > 5:
            print(f"    ... ({len(summ['skipped_no_url']) - 5} more)")
    if summ["skipped_datapacks"]:
        print(f"  SKIPPED datapacks: {', '.join(summ['skipped_datapacks'][:5])}")

    # Type breakdown
    print(f"  by type:")
    for lttype, count in sorted(summ["by_type"].items(), key=lambda x: -x[1]):
        print(f"    {lttype}: {count}")

    # By mod breakdown
    if summ["by_mod"]:
        print(f"  by mod (top 20):")
        for mod, count in sorted(summ["by_mod"].items(), key=lambda x: -x[1])[:20]:
            print(f"    {mod}: {count}")
        if len(summ["by_mod"]) > 20:
            print(f"    ... ({len(summ['by_mod']) - 20} more mods)")

    if summ["vanilla_overrides"]:
        print(f"  vanilla loot tables overridden: {len(summ['vanilla_overrides'])}")
        for v in summ["vanilla_overrides"][:15]:
            print(f"    - {v}")
        if len(summ["vanilla_overrides"]) > 15:
            print(f"    ... ({len(summ['vanilla_overrides']) - 15} more)")

    if summ["unresolved_items"]:
        print(f"  loot tables referencing unresolved items: {len(summ['unresolved_items'])}")
        for u in summ["unresolved_items"][:15]:
            print(f"    - {u['loot_table']} -> {u['item']}")
        if len(summ["unresolved_items"]) > 15:
            print(f"    ... ({len(summ['unresolved_items']) - 15} more)")

    if summ["empty_tables"]:
        print(f"  empty/produce-nothing tables: {len(summ['empty_tables'])}")
        for e in summ["empty_tables"][:15]:
            print(f"    - {e}")
        if len(summ["empty_tables"]) > 15:
            print(f"    ... ({len(summ['empty_tables']) - 15} more)")


def report_json(info, summ):
    out = {
        "tool": "loot.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "loot_tables": {k: {"type": v.get("type"), "pools": v.get("pools", []),
                                 "items": v.get("items", []),
                                 "vanilla_override": v.get("vanilla_override", False)}
                            for k, v in sorted(s["data"].items())}}
            for s in summ["sources"]
        ],
        "summary": {
            "total_tables": summ["total_tables"],
            "jars_downloaded": summ["jars_downloaded"],
            "jars_from_cache": summ["jars_from_cache"],
            "skipped_no_url": summ["skipped_no_url"],
            "skipped_datapacks": summ["skipped_datapacks"],
            "by_mod": summ["by_mod"],
            "by_type": summ["by_type"],
            "vanilla_overrides": summ["vanilla_overrides"],
            "unresolved_items": summ["unresolved_items"],
            "empty_tables": summ["empty_tables"],
        },
    }
    json.dump(out, sys.stdout, indent=2, sort_keys=True)
    print()


def cmd_info(pack_dir, info, target, as_json):
    """Look up a single loot table ID and report all known metadata."""
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

    # Find the loot table across all sources
    found = False
    result = {}
    for src in sources:
        if target in src["data"]:
            found = True
            ltdata = src["data"][target]
            result["id"] = target
            result["type"] = ltdata.get("type", "unknown")
            result["pools"] = ltdata.get("pools", [])
            result["items"] = ltdata.get("items", [])
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["raw"] = ltdata.get("data", {})
            break

    if not found:
        all_ids = set()
        for src in sources:
            all_ids.update(src["data"].keys())
        suggest = fuzzy_match(target, all_ids)
        msg = f"loot table '{target}' not found in any source"
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
    print(f"## loot table: {result['id']}")
    print(f"  type:       {result['type']}")
    print(f"  source:     {result['source_kind']}: {result['source_name']}"
          + (f"  ({result['source_jar']})" if result["source_jar"] else ""))
    if result["vanilla_override"]:
        print(f"  override:   YES — replaces the vanilla loot table (mod redefines {target})")
    if result["pools"]:
        print(f"  pools:      {len(result['pools'])}")
        for i, pool in enumerate(result["pools"][:3]):
            rolls = pool.get("rolls", 1)
            entries = pool.get("entries", [])
            entry_types = [e.get("type", "?") for e in entries]
            print(f"    pool {i}: rolls={rolls}, entries={len(entries)} ({', '.join(entry_types[:5])})")
            if len(entries) > 5:
                print(f"      ... ({len(entries) - 5} more entries)")
        if len(result["pools"]) > 3:
            print(f"    ... ({len(result['pools']) - 3} more pools)")
    else:
        print(f"  pools:      (none)")
    if result["items"]:
        print(f"  items:      {', '.join(result['items'][:10])}")
        if len(result["items"]) > 10:
            print(f"              ... ({len(result['items']) - 10} more)")
    else:
        print(f"  items:      (none recorded)")
    # Raw JSON for debugging
    if result.get("raw"):
        print(f"  raw JSON:")
        raw_str = json.dumps(result["raw"], indent=4, sort_keys=True)
        for line in raw_str.split("\n")[:30]:
            print(f"    {line}")
        if raw_str.count("\n") > 30:
            print(f"    ... ({raw_str.count(chr(10)) - 30} more lines)")


def _format_loot_detail(target_id, sources):
    """Build the detail dict for a single loot table across all sources."""
    result = {}
    for src in sources:
        if target_id in src["data"]:
            ltdata = src["data"][target_id]
            result["id"] = target_id
            result["type"] = ltdata.get("type", "unknown")
            result["pools"] = ltdata.get("pools", [])
            result["items"] = ltdata.get("items", [])
            result["source_kind"] = src["kind"]
            result["source_name"] = src["name"]
            result["source_jar"] = src.get("jar")
            result["raw"] = ltdata.get("data", {})
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
    """Export every loot table's full metadata to a single JSON file."""
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
    for lid in sorted(all_ids):
        entries[lid] = _format_loot_detail(lid, sources)

    t_detail = time.monotonic()

    summ = build_summary(sources, dl, from_cache, skip_no_url, skip_dp)
    out = {
        "tool": "loot.py",
        "pack": info,
        "version": "1",
        "sources": [
            {"kind": s["kind"], "name": s["name"], "jar": s.get("jar"),
             "loot_table_count": len(s["data"])}
            for s in summ["sources"]
        ],
        "summary": {
            "total_loot_tables": summ["total_tables"],
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
    print(f"full-export: {len(entries)} loot tables → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
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
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-loot-full.json"
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
        all_lt_ids = set()
        for src in sources:
            all_lt_ids.update(src["data"].keys())
        for lt_id in sorted(all_lt_ids):
            print(lt_id)
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
#   tables = {}
#   for name in zf.namelist():
#       m = re.match(r'^data/minecraft/loot_tables/(.+)\.json$', name)
#       if m:
#           tid = 'minecraft:' + m.group(1)
#           data = json.loads(zf.read(name))
#           tables[tid] = {'type': data.get('type', '?')}
#   print(json.dumps(tables, indent=2, sort_keys=True))
#   "
# Then select the ~30 most commonly overridden tables and embed them above.

# ## RUN LOG
# ### 2026-09-07
# Created as the standalone loot table enumerator.  Mirrors items.py architecture:
# embedded vanilla 1.21.1 baseline (~30 common loot tables), jar cache by
# checksum, datapack scanning.  Flags vanilla overrides, unresolved item
# references, empty/produce-nothing tables.  Supports --json (stable schema),
# --list, and --info for single-table lookup with fuzzy suggestions.
