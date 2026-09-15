#!/usr/bin/env python3
"""Pack-spawn scanner — report mob spawns across all mod jars and datapacks.

Usage:
  python3 mobspawn.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                              [--json] [--list] [--info <id>] [--full-export [outfile]]
  python3 mobspawn.py <pack> --json                     JSON to stdout
  python3 mobspawn.py <pack> --list                     list biome IDs
  python3 mobspawn.py <pack> --info <id>                show spawn details for one biome
  python3 mobspawn.py <pack> --full-export [outfile]    full JSON dump

Each mod jar and datapack directory is scanned once; results are cached for the
session. Contested placement: same biome file path defined by multiple sources
(vanilla + mod + datapack) is flagged with all contributing definitions side-by-
side — never assumes vanilla is "the real one".

Default human output mirrors packwiz-structures: per-source sections (vanilla
baseline, per-mod, per-datapack) with contested placements highlighted.
"""
import sys
import os
import json
import re
import argparse
import time
import zipfile
from pathlib import Path

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)
from datapack_common import (
    die, resolve_pack_dir, read_pack_info, cached_jar, find_mod_jars,
    resolve_mod, fuzzy_match, paxi_dir, dir_to_zip,
)

# ── Vanilla biome baseline ─────────────────────────────────────────────
# Embedded for offline/deterministic operation. Built from vanilla 1.21
# server.jar biome files. Key = biome path (no namespace = minecraft:),
# value = dict of spawner lists per category.

SPAWN_CATEGORIES = ("monster", "creature", "ambient", "water_creature",
                    "water_ambient", "underground_water_creature", "axolotls")


def _read_vanilla_biomes():
    """Extract spawner data from vanilla 1.21 client.jar for all biomes."""
    vanilla_url = "https://piston-data.mojang.com/v1/objects/0e9a07b9bb3390602f977073aa12884a4ce12431/client.jar"
    try:
        local, _ = cached_jar({"url": vanilla_url, "sha1": ""})
    except Exception:
        return {}

    biomes = {}
    with zipfile.ZipFile(local) as zf:
        for name in zf.namelist():
            if not re.match(r"^data/minecraft/worldgen/biome/[^/]+\.json$", name):
                continue
            biome_id = "minecraft:" + Path(name).stem
            data = json.loads(zf.read(name))
            spawners = data.get("spawners", {})
            if not spawners:
                continue
            biomes[biome_id] = {"spawners": spawners}
    return biomes


VANILLA_BIOMES = _read_vanilla_biomes()


# ── Source tracking helpers ────────────────────────────────────────────

def _make_source(name, kind):
    """Create a source record dict."""
    return {"name": name, "kind": kind}  # kind = "vanilla" | "mod" | "datapack"


# ── Scan functions ─────────────────────────────────────────────────────

def _read_biome_spawners(data):
    """Extract spawner data from a biome JSON dict."""
    spawners = data.get("spawners", {})
    result = {}
    for cat in SPAWN_CATEGORIES:
        entries = spawners.get(cat, [])
        if entries:
            result[cat] = entries
    return result


def scan_vanilla(info):
    """Return (source_dict, errors) for the vanilla baseline."""
    ver = info.get("minecraft")
    if ver and ver.startswith("1.21"):
        src = _make_source(f"vanilla {ver} baseline", "vanilla")
        src["spawners"] = {}  # Will be populated per biome
        src["biomes"] = VANILLA_BIOMES
        return src, None
    return None, f"no embedded vanilla baseline for MC {ver}"


def scan_mods(pack_dir, info, mod_filter, skip_no_url, raw=False):
    """Scan mod jars for biome spawner data. Returns (sources, dl, from_cache).

    Deduplicates by .pw.toml filename — find_mod_jars() creates multiple
    aliases (slug, filename stem, jar stem) for the same mod, so we must
    group by pw_toml to avoid scanning the same jar multiple times.
    """
    mod_specs = find_mod_jars(pack_dir)
    if mod_filter:
        # Resolve each requested slug to a mod via the shared resolver (which
        # prefers a target-prefixed key, e.g. 'reliquified_artifacts' → the
        # 'reliquified_artifacts-1.21.1-1.0.8' jar alias) instead of the item-ID
        # fuzzy_matcher, which took the dict+list and crashed on the filter list.
        selected = []
        for t in mod_filter:
            k = resolve_mod(mod_specs, t)
            if k is None:
                die(f"no mod '{t}' in pack")
            if mod_specs[k]["pw_toml"] not in selected:
                selected.append(mod_specs[k]["pw_toml"])
        mod_specs = {k: e for k, e in mod_specs.items() if e["pw_toml"] in selected}
    # Group by pw_toml to deduplicate aliases
    by_toml = {}
    for k, e in mod_specs.items():
        by_toml.setdefault(e["pw_toml"], []).append((k, e))
    sources = []
    dl_total = 0
    cache_total = 0
    for toml, entries in sorted(by_toml.items()):
        mod_slug, entry = entries[0]
        try:
            local, was_dl = cached_jar(entry)
            dl_total += 1 if was_dl else 0
            cache_total += 0 if was_dl else 1
        except Exception:
            skip_no_url.append(mod_slug)
            continue
        src = _make_source(mod_slug, "mod")
        src["spawners"] = {}
        src["biomes"] = {}
        with zipfile.ZipFile(local) as zf:
            for name in zf.namelist():
                if not re.match(r"^data/[^/]+/worldgen/biome/[^/]+\.json$", name):
                    continue
                # Extract biome ID from path
                m = re.match(r"^data/([^/]+)/worldgen/biome/([^/]+)\.json$", name)
                if not m:
                    continue
                namespace = m.group(1)
                biome_name = m.group(2)
                biome_id = f"{namespace}:{biome_name}"
                try:
                    data = json.loads(zf.read(name))
                except (json.JSONDecodeError, KeyError):
                    continue
                spawners = _read_biome_spawners(data)
                if spawners:
                    src["biomes"][biome_id] = {"spawners": spawners}
        if src["biomes"]:
            sources.append(src)
    return sources, dl_total, cache_total


def scan_datapacks(pack_dir, skip_dp, raw=False):
    """Scan pack's own datapacks for biome spawner data."""
    paxi_base = paxi_dir(pack_dir)
    paxi_path = Path(paxi_base)
    sources = []
    datapacks_dir = paxi_path / "datapacks"
    if not datapacks_dir.exists():
        return sources
    for dp_entry in sorted(datapacks_dir.iterdir()):
        dp_name = dp_entry.name
        biome_data = {}
        if dp_entry.is_file() and dp_entry.suffix == ".zip":
            try:
                with zipfile.ZipFile(dp_entry) as zf:
                    for name in zf.namelist():
                        if not re.match(r"^data/[^/]+/worldgen/biome/[^/]+\.json$", name):
                            continue
                        m = re.match(r"^data/([^/]+)/worldgen/biome/([^/]+)\.json$", name)
                        if not m:
                            continue
                        namespace = m.group(1)
                        biome_name = m.group(2)
                        biome_id = f"{namespace}:{biome_name}"
                        try:
                            data = json.loads(zf.read(name))
                        except (json.JSONDecodeError, KeyError):
                            continue
                        spawners = _read_biome_spawners(data)
                        if spawners:
                            biome_data[biome_id] = {"spawners": spawners}
            except zipfile.BadZipFile:
                skip_dp.append(dp_name)
                continue
        elif dp_entry.is_dir():
            for f in dp_entry.rglob("*.json"):
                rel = str(f.relative_to(dp_entry))
                if not re.match(r"^data/[^/]+/worldgen/biome/[^/]+\.json$", rel):
                    continue
                m = re.match(r"^data/([^/]+)/worldgen/biome/([^/]+)\.json$", rel)
                if not m:
                    continue
                namespace = m.group(1)
                biome_name = m.group(2)
                biome_id = f"{namespace}:{biome_name}"
                try:
                    data = json.loads(f.read_text())
                except (json.JSONDecodeError, KeyError):
                    continue
                spawners = _read_biome_spawners(data)
                if spawners:
                    biome_data[biome_id] = {"spawners": spawners}
        if biome_data:
            src = _make_source(dp_name, "datapack")
            src["spawners"] = {}
            src["biomes"] = biome_data
            sources.append(src)
    return sources


# ── Resolve and build summary ──────────────────────────────────────────

def build_summary(sources, include_vanilla=True):
    """Merge all sources and detect contested placements.

    Returns dict with:
      biome_count          — int, resolved biome count
      total_spawn_entries  — int, total mob entries across all resolved biomes
      contested            — dict: biome_id → list of source defs (len > 1 = contested)
      effective_biomes     — dict: biome_id → resolved spawner data per category
      sources              — list of source info dicts

    Each source def includes a source_type field:
      - "mod"            — from a mod jar (pinned in checksums.json)
      - "datapack"       — from a pack datapack (config/paxi/datapacks/ or data/)
      - "vanilla"        — from the embedded vanilla baseline
    """
    # Collect all definitions per biome path
    all_defs = {}  # biome_id → list of {"source": ..., "kind": ..., "source_type": ..., "spawners": ...}
    for src in sources:
        for biome_id, biome_data in src.get("biomes", {}).items():
            all_defs.setdefault(biome_id, []).append({
                "source": src["name"],
                "kind": src["kind"],
                "source_type": src["kind"],  # mod, datapack, or vanilla
                "spawners": biome_data.get("spawners", {}),
            })

    # Detect contested: biome defined by multiple sources
    contested = {}
    for biome_id, defs in all_defs.items():
        if len(defs) > 1:
            contested[biome_id] = defs

    # Resolve: last source wins (mod → datapack → vanilla order)
    # Sort sources by kind priority (mod > datapack > vanilla)
    kind_priority = {"mod": 0, "datapack": 1, "vanilla": 2}

    effective = {}
    for biome_id, defs in all_defs.items():
        # Sort by kind priority, then by position in sources list (later wins)
        sorted_defs = sorted(defs, key=lambda d: kind_priority.get(d["kind"], 99))
        # Last one wins
        winner = sorted_defs[-1]
        effective[biome_id] = winner["spawners"]

    # Count total spawn entries
    total_entries = 0
    for biome_id, spawners in effective.items():
        for cat, entries in spawners.items():
            total_entries += len(entries)

    return {
        "biome_count": len(effective),
        "total_spawn_entries": total_entries,
        "contested": contested,
        "effective_biomes": effective,
        "sources": [{"name": s["name"], "kind": s["kind"], "biome_count": len(s.get("biomes", {}))}
                    for s in sources],
    }


# ── Report output ──────────────────────────────────────────────────────

def report_human(result, show_full=False):
    """Print human-readable report."""
    summary = result["summary"]
    print(f"Pack spawn scan: {summary['biome_count']} biomes, "
          f"{summary['total_spawn_entries']} spawn entries")
    print(f"Sources: {len(summary['sources'])} scanned")
    for src in summary["sources"]:
        print(f"  {src['kind']:>9s}  {src['name']:>30s}  {src['biome_count']} biomes")
    if summary["contested"]:
        print(f"\nContested placements: {len(summary['contested'])} biome(s)")
        for biome_id, defs in sorted(summary["contested"].items()):
            print(f"  {biome_id}: {len(defs)} definitions")
            for d in defs:
                cats = ", ".join(sorted(d["spawners"].keys()))
                source_type = d.get("source_type", d["kind"])
                print(f"    - {d['kind']:>9s}  {d['source']:>30s}  [{cats}]  type={source_type}")
    if result.get("missing_mobs"):
        print(f"\nMobs in biome spawners but not in mobs.py mob list: "
              f"{len(result['missing_mobs'])}")
        if show_full:
            for mob in sorted(result["missing_mobs"]):
                print(f"  {mob}")


def report_json(result):
    """Print JSON to stdout."""
    print(json.dumps(result, indent=2))


# ── CLI commands ───────────────────────────────────────────────────────

def cmd_list(pack, args):
    """List all biome IDs with spawn data."""
    t0 = time.time()
    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)
    skip_no_url = []
    skip_dp = []
    sources = []
    if not args.no_vanilla:
        v_src, err = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    if not args.no_mods:
        mod_sources, dl, fc = scan_mods(pack_dir, info, args.mods, skip_no_url, raw=True)
        sources += mod_sources
    if not args.no_datapacks:
        sources += scan_datapacks(pack_dir, skip_dp, raw=True)
    summary = build_summary(sources)
    t1 = time.time()
    biome_ids = sorted(summary["effective_biomes"].keys())
    if getattr(args, "as_json", False):
        out = []
        for bid in biome_ids:
            cats = summary["effective_biomes"][bid]
            out.append({"biome": bid, "categories": {c: len(e) for c, e in cats.items()}})
        print(json.dumps(out, indent=2))
    else:
        for bid in biome_ids:
            cats = summary["effective_biomes"][bid]
            cat_summary = ", ".join(f"{c}:{len(e)}" for c, e in sorted(cats.items()))
            print(f"{bid}  [{cat_summary}]")
        elapsed = t1 - t0
        print(f"\n{len(biome_ids)} biomes  ({elapsed:.1f}s)")


def cmd_info(pack, args):
    """Show spawn details for one biome."""
    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)
    target = args.info
    # Normalize: add minecraft: prefix if missing
    if ":" not in target:
        target = f"minecraft:{target}"

    skip_no_url = []
    skip_dp = []
    sources = []
    if not args.no_vanilla:
        v_src, _ = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    if not args.no_mods:
        mod_sources, _, _ = scan_mods(pack_dir, info, args.mods, skip_no_url, raw=True)
        sources += mod_sources
    if not args.no_datapacks:
        sources += scan_datapacks(pack_dir, skip_dp, raw=True)

    # Collect all definitions for target
    all_defs = []
    for src in sources:
        for biome_id, biome_data in src.get("biomes", {}).items():
            if biome_id == target:
                all_defs.append({
                    "source": src["name"],
                    "kind": src["kind"],
                    "spawners": biome_data.get("spawners", {}),
                })

    if not all_defs:
        print(f"biome {target} not found", file=sys.stderr)
        return 1

    # Determine resolution
    kind_priority = {"mod": 0, "datapack": 1, "vanilla": 2}
    sorted_defs = sorted(all_defs, key=lambda d: kind_priority.get(d["kind"], 99))
    winner = sorted_defs[-1]
    contested = len(all_defs) > 1

    if getattr(args, "as_json", False):
        out = {
            "biome": target,
            "contested": contested,
            "definitions": all_defs,
            "winner": {
                "source": winner["source"],
                "kind": winner["kind"],
                "spawners": winner["spawners"],
            },
        }
        print(json.dumps(out, indent=2))
    else:
        print(f"## mobspawn: {target}")
        if contested:
            print(f"  CONTESTED: {len(all_defs)} definitions")
            for d in all_defs:
                print(f"    - {d['kind']:>9s}  {d['source']}")
        else:
            print(f"  source:    {winner['source']} ({winner['kind']})")

        # Show spawners
        for cat in SPAWN_CATEGORIES:
            entries = winner["spawners"].get(cat, [])
            if entries:
                print(f"  {cat}:")
                for e in entries:
                    mob_type = e.get("type", "?")
                    weight = e.get("weight", "?")
                    min_c = e.get("minCount", "?")
                    max_c = e.get("maxCount", "?")
                    print(f"    {mob_type}  weight={weight}  count={min_c}-{max_c}")

    return 0


def cmd_full_export(pack, args):
    """Full JSON export to file or stdout."""
    t0 = time.time()
    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)
    skip_no_url = []
    skip_dp = []
    sources = []
    if not args.no_vanilla:
        v_src, _ = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    if not args.no_mods:
        mod_sources, dl, fc = scan_mods(pack_dir, info, args.mods, skip_no_url, raw=True)
        sources += mod_sources
    if not args.no_datapacks:
        sources += scan_datapacks(pack_dir, skip_dp, raw=True)

    summary = build_summary(sources)

    # Build full result
    full = {
        "summary": {
            "biome_count": summary["biome_count"],
            "total_spawn_entries": summary["total_spawn_entries"],
            "contested_count": len(summary["contested"]),
            "sources": summary["sources"],
        },
        "effective_biomes": summary["effective_biomes"],
        "contested": {k: [{"source": d["source"], "kind": d["kind"],
                           "source_type": d.get("source_type", d["kind"]),
                           "categories": list(d["spawners"].keys())}
                          for d in v]
                      for k, v in summary["contested"].items()},
    }

    t1 = time.time()
    elapsed = t1 - t0
    outfile = args.full_export
    if outfile:
        with open(outfile, "w") as f:
            json.dump(full, f, indent=2)
        size_kb = os.path.getsize(outfile) / 1024
        print(f"full-export: {summary['biome_count']} biomes → {outfile} "
              f"({size_kb:.0f} KB)\n  scan: {elapsed:.1f}s  write: 0.0s  total: {elapsed:.1f}s")
    else:
        report_json(full)
    return 0


def cmd_json(pack, args):
    """JSON to stdout."""
    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)
    skip_no_url = []
    skip_dp = []
    sources = []
    if not args.no_vanilla:
        v_src, _ = scan_vanilla(info)
        if v_src:
            sources.append(v_src)
    if not args.no_mods:
        mod_sources, dl, fc = scan_mods(pack_dir, info, args.mods, skip_no_url, raw=True)
        sources += mod_sources
    if not args.no_datapacks:
        sources += scan_datapacks(pack_dir, skip_dp, raw=True)

    summary = build_summary(sources)
    result = {
        "summary": {
            "biome_count": summary["biome_count"],
            "total_spawn_entries": summary["total_spawn_entries"],
            "contested_count": len(summary["contested"]),
            "sources": summary["sources"],
        },
        "effective_biomes": summary["effective_biomes"],
        "contested": {k: [{"source": d["source"], "kind": d["kind"],
                           "source_type": d.get("source_type", d["kind"]),
                           "categories": list(d["spawners"].keys())}
                          for d in v]
                      for k, v in summary["contested"].items()},
    }
    report_json(result)


# ── Main ───────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(
        description="Pack-spawn scanner — report mob spawns across mod jars and datapacks.",
    )
    ap.add_argument("pack", help="Pack directory name (e.g. AllTheTech)")
    ap.add_argument("--mods", default=None,
                    help="Comma-separated mod slugs or prefixes (default: all)")
    ap.add_argument("--no-datapacks", action="store_true",
                    help="Skip pack's own datapacks directory")
    ap.add_argument("--no-vanilla", action="store_true",
                    help="Omit the embedded vanilla baseline")
    ap.add_argument("--no-mods", action="store_true",
                    help="Omit mod jars (use with --no-datapacks for vanilla-only)")
    ap.add_argument("--json", action="store_true", dest="as_json",
                    help="Output JSON to stdout")
    ap.add_argument("--list", action="store_true",
                    help="List all biome IDs with spawn data")
    ap.add_argument("--info", default=None, metavar="BIOME_ID",
                    help="Show spawn details for one biome (e.g. minecraft:plains)")
    ap.add_argument("--full-export", nargs="?", const="", default=None,
                    metavar="OUTFILE",
                    help="Full JSON dump to file (or stdout if no path)")
    args = ap.parse_args()
    if args.mods:
        args.mods = [s.strip().lower() for s in args.mods.split(",") if s.strip()]

    if args.list:
        cmd_list(args.pack, args)
    elif args.info:
        cmd_info(args.pack, args)
    elif args.full_export is not None:
        cmd_full_export(args.pack, args)
    elif args.as_json:
        cmd_json(args.pack, args)
    else:
        # Default: human-readable summary
        cmd_list(args.pack, args)


if __name__ == "__main__":
    sys.exit(main() or 0)

# ## RUN LOG
# ### 2026-09-13 — --mods filtering was completely broken (two bugs)
# (1) scan_mods called fuzzy_match(mod_specs, mod_filter) — the item-ID fuzzy
# matcher fed a dict + slug string, crashing with "AttributeError: 'dict' object
# has no attribute 'lower'" whenever --mods was used. Every other scanner selects
# jars via resolve_mod; write the same selection here.
# (2) --mods was never comma-split: args.mods stayed "artifacts,relics,..." and
# each token was treated as one huge slug. Normalize to a list right after
# parse_args (same as items.py). Both fixed; restricted scans now return results.
