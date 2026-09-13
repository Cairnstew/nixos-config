#!/usr/bin/env python3
"""Item Tier CLI — deterministic 0-7 rarity scorer for pack items.

Standalone, stdlib-only. Uses item-acquisition.py data to compute a deterministic
rarity tier (0-7) for every item based on acquisition difficulty.

No guessing — items with no acquisition paths get tier=null with a reason.
No category fallback — if no paths can compute a score, tier is null.

Usage (manual):
  python3 item-tier.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                              [--json] [--list] [--info <item>]
                              [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print item_id tier pairs, one per line (fastest for piping).
  --info <item>     detailed tier info for a single item (fuzzy match on miss).
  --full-export [f] write every item's tier record to a single JSON file.
                    If f is omitted, defaults to <packname>-tiers-full.json.

Tier scale (0-7):
  0  — World-generated blocks (dirt, stone, sand, gravel, wood)
  1  — Common resources (coal, iron, copper, flint, leather)
  2  — Uncommon resources (gold, lapis, redstone, string, bones)
  3  — Rare resources (diamonds, emeraldls, ender pearls, blaze rods)
  4  — Crafted items (iron tools, basic machines, bread, torches)
  5  — Advanced crafted items (diamond tools, enchanted gear, potions)
  6  — Endgame items (netherite gear, max enchanted, elytra)
  7  — Ultra-rare / admin items (command blocks, bedrock, barriers)

Scoring rules:
  - Multi-path items resolve to EASIEST path (min tier)
  - recipe_tier = max(ingredient_base_tier) + small log-scaled bonus
  - Per-path scoring uses weighted geometric mean
  - Normalization via percentile bucketing across full item set
  - Tier overrides from tier-overrides.toml applied post-computation

Curated overrides:
  tier-overrides.toml in the pack dir applies post-computation overrides.
  Format: item_id = tier (0-7)
  Override values shown alongside computed values for transparency.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/item-tier.py (scoped-exception
dir — direct RUN LOG edits are expected). Append dated fixes to the // ## RUN LOG
block at the end of THIS file.
"""

import os
import sys
import json
import math
import subprocess
import tempfile
import time

from datapack_common import (
    die, repo_root, resolve_pack_dir, read_pack_info, fuzzy_match,
)

TOOL = "item-tier.py"


# ── Tier definitions ──────────────────────────────────────────────────────────

# Base tiers for vanilla items (fallback for items not in acquisition data)
# These represent the "natural" difficulty of obtaining the item without crafting
VANILLA_BASE_TIERS = {
    # Tier 0: World-generated blocks
    "minecraft:dirt": 0, "minecraft:stone": 0, "minecraft:cobblestone": 0,
    "minecraft:sand": 0, "minecraft:gravel": 0, "minecraft:clay": 0,
    "minecraft:grass_block": 0, "minecraft:podzol": 0, "minecraft:mycelium": 0,
    "minecraft:andesite": 0, "minecraft:diorite": 0, "minecraft:granite": 0,
    "minecraft:dripstone_block": 0, "minecraft:deepslate": 0,
    "minecraft:bedrock": 7, "minecraft:barrier": 7, "minecraft:command_block": 7,
    "minecraft:structure_block": 7, "minecraft:jigsaw": 7,

    # Tier 1: Common resources
    "minecraft:coal": 1, "minecraft:iron_ingot": 1, "minecraft:copper_ingot": 1,
    "minecraft:flint": 1, "minecraft:leather": 1, "minecraft:stick": 1,
    "minecraft:string": 1, "minecraft:bone": 1, "minecraft:rotten_flesh": 1,
    "minecraft:arrow": 1, "minecraft:bowl": 1,

    # Tier 2: Uncommon resources
    "minecraft:gold_ingot": 2, "minecraft:lapis_lazuli": 2,
    "minecraft:redstone": 2, "minecraft:dye": 2,
    "minecraft:bone_meal": 2, "minecraft:glowstone_dust": 2,
    "minecraft:blaze_powder": 2, "minecraft:ender_pearl": 2,
    "minecraft:ghast_tear": 2, "minecraft:magma_cream": 2,
    "minecraft:spider_eye": 2, "minecraft:gunpowder": 2,

    # Tier 3: Rare resources
    "minecraft:diamond": 3, "minecraft:emerald": 3,
    "minecraft:netherite_scrap": 3, "minecraft:netherite_ingot": 3,
    "minecraft:echo_shard": 3, "minecraft:disc_fragment": 3,
    "minecraft:amethyst_shard": 3, "minecraft:crying_obsidian": 3,

    # Tier 4: Crafted items (basic tools, blocks)
    "minecraft:iron_pickaxe": 4, "minecraft:iron_sword": 4,
    "minecraft:iron_axe": 4, "minecraft:iron_shovel": 4, "minecraft:iron_hoe": 4,
    "minecraft:iron_helmet": 4, "minecraft:iron_chestplate": 4,
    "minecraft:iron_leggings": 4, "minecraft:iron_boots": 4,
    "minecraft:torch": 4, "minecraft:crafting_table": 4,
    "minecraft:furnace": 4, "minecraft:chest": 4,
    "minecraft:bucket": 4, "minecraft:flint_and_steel": 4,

    # Tier 5: Advanced crafted items
    "minecraft:diamond_pickaxe": 5, "minecraft:diamond_sword": 5,
    "minecraft:diamond_axe": 5, "minecraft:diamond_shovel": 5,
    "minecraft:diamond_helmet": 5, "minecraft:diamond_chestplate": 5,
    "minecraft:diamond_leggings": 5, "minecraft:diamond_boots": 5,
    "minecraft:enchanted_golden_apple": 5,
    "minecraft:ender_chest": 5, "minecraft:anvil": 5,

    # Tier 6: Endgame items
    "minecraft:netherite_pickaxe": 6, "minecraft:netherite_sword": 6,
    "minecraft:netherite_axe": 6, "minecraft:netherite_helmet": 6,
    "minecraft:netherite_chestplate": 6, "minecraft:netherite_leggings": 6,
    "minecraft:netherite_boots": 6,
    "minecraft:elytra": 6, "minecraft:totem_of_undying": 6,
    "minecraft:trident": 6, "minecraft:nautilus_shell": 6,
    "minecraft:beacon": 6, "minecraft:conduit": 6,

    # Tier 7: Ultra-rare / admin
    "minecraft:bedrock": 7, "minecraft:barrier": 7,
    "minecraft:command_block": 7, "minecraft:chain_command_block": 7,
    "minecraft:repeating_command_block": 7, "minecraft:structure_block": 7,
    "minecraft:jigsaw": 7, "minecraft:knowledge_book": 7,
    "minecraft:debug_stick": 7, "minecraft:light": 7,
    "minecraft:command_block_minecart": 7, "minecraft:structure_void": 7,
}

# Loot table context weights (how much each context contributes to difficulty)
CONTEXT_WEIGHTS = {
    "mob_drop": 0.3,        # Mob drops are relatively easy
    "fishing": 0.4,         # Fishing is random but common
    "block_drop": 0.2,      # Block drops are easiest
    "structure_chest": 0.6, # Structure chests require exploration
    "piglin_barter": 0.5,   # Piglin bartering requires gold
    "gameplay": 0.5,        # Other gameplay
    "unknown": 0.4,         # Unknown context
}


# ── Load tier overrides from TOML ────────────────────────────────────────────

def _load_tier_overrides(pack_dir: str) -> dict:
    """Load tier-overrides.toml from the pack dir if it exists."""
    overrides = {}
    toml_path = os.path.join(pack_dir, "tier-overrides.toml")
    if not os.path.exists(toml_path):
        return overrides

    # Simple TOML parser (stdlib only)
    with open(toml_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("["):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                val = val.strip().strip('"').strip("'")
                try:
                    overrides[key] = int(val)
                except ValueError:
                    pass
    return overrides


# ── Tier computation ──────────────────────────────────────────────────────────

def _compute_base_tier(item_id: str, meta: dict) -> float | None:
    """Compute the base tier for an item (before crafting paths).

    Only returns a tier for items in VANILLA_BASE_TIERS. All other items
    (including mod items) are computed iteratively from their paths.
    """
    if item_id in VANILLA_BASE_TIERS:
        return float(VANILLA_BASE_TIERS[item_id])

    return None


def _compute_category_tier(item_id: str, meta: dict) -> float:
    """Compute a rough tier based on item category and source.

    UNUSED — kept for potential future use. Items with no acquisition paths
    get tier=null (see _compute_paths_score), not a guessed category tier.
    """
    source_kind = meta.get("source_kind", "mod")
    category = meta.get("category", "unknown")

    if source_kind == "vanilla":
        return 1.0  # Vanilla items not in base tier map: common

    # Mod items: category-based rough tier
    category_tiers = {
        "material": 2.0,      # Raw materials
        "food": 3.0,          # Food items
        "tool": 4.5,          # Tools
        "weapon": 5.0,        # Weapons
        "armor": 5.0,         # Armor
        "block": 3.0,         # Building blocks
        "decor": 3.5,         # Decorative blocks
        "redstone": 4.0,      # Redstone components
        "transport": 4.0,     # Transport items
        "brewing": 4.5,       # Brewing items
        "misc": 4.0,          # Miscellaneous
        "unknown": 4.0,       # Unknown category
    }
    return category_tiers.get(category, 4.0)


def _compute_recipe_tier(recipe: dict, tier_cache: dict) -> tuple[float | None, dict]:
    """Compute the tier for a recipe based on its ingredients.

    Returns (score, factors) where factors contains the breakdown.
    """
    ingredients = recipe.get("ingredients", [])
    if not ingredients:
        return None, {}

    ingredient_tiers = []
    for ing in ingredients:
        # Skip tag references (we can't resolve them)
        if ing.startswith("#"):
            continue
        # Get ingredient tier from cache
        if ing in tier_cache:
            ingredient_tiers.append(tier_cache[ing])

    if not ingredient_tiers:
        return None, {}

    # recipe_tier = max(ingredient_base_tier) + small bonus
    max_ing_tier = max(ingredient_tiers)
    distinct_count = len(set(ingredients))
    bonus = 0.1 * math.log2(max(distinct_count, 1))
    factors = {
        "max_ingredient_tier": max_ing_tier,
        "distinct_ingredients": distinct_count,
        "bonus": round(bonus, 3),
    }
    return max_ing_tier + bonus, factors


def _compute_loot_tier(loot_refs: list) -> float:
    """Compute the tier contribution from loot table references."""
    if not loot_refs:
        return 0.0

    # Use the hardest loot context
    max_context_weight = 0.0
    for ref in loot_refs:
        context = ref.get("context", "unknown")
        weight = CONTEXT_WEIGHTS.get(context, 0.4)
        max_context_weight = max(max_context_weight, weight)

    return max_context_weight * 7.0  # Scale to 0-7


def _compute_ore_tier(ore_refs: list) -> float:
    """Compute the tier contribution from ore placements."""
    if not ore_refs:
        return 0.0

    # Ore tier based on Y range (deeper = harder)
    min_y = min(r.get("y_min", 0) for r in ore_refs if r.get("y_min") is not None)
    if min_y < -20:
        return 3.0  # Deep ores (diamonds, ancient debris)
    elif min_y < 0:
        return 2.0  # Mid-depth ores (gold, redstone)
    else:
        return 1.0  # Shallow ores (coal, iron, copper)


def _compute_paths_score(paths: dict, tier_cache: dict, item_id: str, meta: dict) -> tuple[float | None, str, dict]:
    """Compute the overall score from all acquisition paths.

    Returns (score, reason, factors) where score is None if no paths are usable.
    """
    if not paths:
        return None, "no acquisition paths", {}

    scores = []
    all_factors = []

    # Crafting paths
    if "crafting" in paths:
        for recipe in paths["crafting"]:
            recipe_tier, factors = _compute_recipe_tier(recipe, tier_cache)
            if recipe_tier is not None:
                scores.append(recipe_tier)
                all_factors.append({"path": "crafting", "score": recipe_tier, **factors})

    # Smelting paths
    if "smelting" in paths:
        for recipe in paths["smelting"]:
            input_item = recipe.get("input")
            if input_item and input_item in tier_cache:
                smelt_score = tier_cache[input_item] + 0.5  # Smelting adds slight value
                scores.append(smelt_score)
                all_factors.append({"path": "smelting", "score": smelt_score, "input_tier": tier_cache[input_item]})

    # Loot paths
    if "loot" in paths:
        loot_score = _compute_loot_tier(paths["loot"])
        scores.append(loot_score)
        loot_contexts = [r.get("context", "unknown") for r in paths["loot"]]
        all_factors.append({"path": "loot", "score": loot_score, "contexts": loot_contexts})

    # Ore paths
    if "ore" in paths:
        ore_score = _compute_ore_tier(paths["ore"])
        scores.append(ore_score)
        all_factors.append({"path": "ore", "score": ore_score})

    # Tag paths are NOT acquisition paths — they're metadata about what categories
    # an item belongs to, not how to get it. We do NOT use them for scoring.
    # Items with only tags and no real paths (crafting, loot, ore, smelting, mob_drop)
    # get tier=null (see the "no usable paths" check below).

    if not scores:
        # No usable paths — tier is null (not a guess)
        return None, "no acquisition paths", {}

    # Easiest path wins (min)
    min_score = min(scores)
    min_idx = scores.index(min_score)
    winning_factors = all_factors[min_idx] if min_idx < len(all_factors) else {}
    return min_score, f"easiest of {len(scores)} path(s)", winning_factors


def _normalize_to_tier(score: float | None) -> int | None:
    """Normalize a score to 0-7 tier using direct mapping.

    Score ranges map to tiers:
      < 1.0 → 0, 1.0-2.0 → 1, 2.0-3.0 → 2, 3.0-4.0 → 3,
      4.0-5.0 → 4, 5.0-6.0 → 5, 6.0-7.0 → 6, > 7.0 → 7
    """
    if score is None:
        return None

    # Direct mapping: score range to tier
    tier = int(score)
    return min(7, max(0, tier))


# ── Core scanner ──────────────────────────────────────────────────────────────

def scan_tiers(pack_dir, info, pack, want_mods=None, scan_dp=True, scan_van=True):
    """Compute deterministic tiers for every item in the pack."""
    t0 = time.monotonic()

    # Build extra args for scanners
    extra_args = []
    if want_mods:
        extra_args.extend(["--mods", ",".join(want_mods)])
    if not scan_dp:
        extra_args.append("--no-datapacks")
    if not scan_van:
        extra_args.append("--no-vanilla")

    # ── Phase 1: Load acquisition data ────────────────────────────────────
    print("  Loading acquisition data...", file=sys.stderr)
    tool_path = os.path.join(os.path.dirname(__file__), "item-acquisition.py")
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
        tmp_path = f.name
    try:
        cmd = [sys.executable, tool_path, pack, "--full-export", tmp_path] + extra_args
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            die(f"item-acquisition.py failed: {result.stderr[:500]}")
        with open(tmp_path) as f:
            acq_data = json.load(f)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    t_load = time.monotonic()

    # ── Phase 2: Load tier overrides ──────────────────────────────────────
    overrides = _load_tier_overrides(pack_dir)
    if overrides:
        print(f"  Loaded {len(overrides)} tier overrides", file=sys.stderr)

    # ── Phase 3: Compute base tiers ───────────────────────────────────────
    tier_cache = {}  # item_id → computed tier (float)
    reasons = {}     # item_id → reason string
    entries = acq_data.get("entries", {})

    # First pass: compute base tiers for all items
    for item_id, record in entries.items():
        base_tier = _compute_base_tier(item_id, record)
        if base_tier is not None:
            tier_cache[item_id] = base_tier
            reasons[item_id] = "vanilla base tier"

    t_base = time.monotonic()

    # ── Phase 4: Compute recipe tiers (iterative) ─────────────────────────
    # Iteratively resolve recipe tiers until stable
    max_iterations = 10
    all_factors = {}  # item_id → winning path factors
    for iteration in range(max_iterations):
        changed = False
        for item_id, record in entries.items():
            if item_id in tier_cache and reasons.get(item_id) != "recipe computed":
                continue  # Already have a base tier

            paths = record.get("paths", {})
            score, reason, factors = _compute_paths_score(paths, tier_cache, item_id, record)
            if score is not None:
                old_tier = tier_cache.get(item_id)
                tier_cache[item_id] = score
                reasons[item_id] = reason
                all_factors[item_id] = factors
                if old_tier != score:
                    changed = True

        if not changed:
            break

    t_compute = time.monotonic()

    # ── Phase 5: Build final tier records ──────────────────────────────────
    tier_records = {}
    for item_id, record in entries.items():
        computed_tier = tier_cache.get(item_id)
        normalized_tier = _normalize_to_tier(computed_tier)

        # Apply overrides
        override_tier = overrides.get(item_id)

        # Determine final tier
        if override_tier is not None:
            final_tier = override_tier
            final_reason = f"curated override (computed={normalized_tier})"
        elif normalized_tier is not None:
            final_tier = normalized_tier
            final_reason = reasons.get(item_id, "computed")
        else:
            final_tier = None
            final_reason = reasons.get(item_id, "no acquisition paths")

        tier_records[item_id] = {
            "id": item_id,
            "category": record.get("category", "unknown"),
            "lang_name": record.get("lang_name"),
            "tier": final_tier,
            "computed_tier": normalized_tier,
            "override_tier": override_tier,
            "reason": final_reason,
            "paths": list(record.get("paths", {}).keys()),
            "factors": all_factors.get(item_id, {}),
        }

    t_build = time.monotonic()

    return {
        "records": tier_records,
        "item_count": len(tier_records),
        "tier_counts": _count_tiers(tier_records),
        "timing": {
            "load": t_load - t0,
            "base": t_base - t_load,
            "compute": t_compute - t_base,
            "build": t_build - t_compute,
            "total": t_build - t0,
        },
    }


def _count_tiers(records: dict) -> dict:
    """Count items per tier."""
    counts = {}
    for rec in records.values():
        tier = rec.get("tier")
        if tier is None:
            counts["null"] = counts.get("null", 0) + 1
        else:
            counts[str(tier)] = counts.get(str(tier), 0) + 1
    return counts


# ── CLI ───────────────────────────────────────────────────────────────────────

def cmd_list(result):
    """Print item_id tier pairs, one per line."""
    for item_id in sorted(result["records"].keys()):
        tier = result["records"][item_id].get("tier")
        print(f"{item_id}={tier if tier is not None else 'null'}")


def cmd_info(result, target, as_json=False):
    """Print detailed tier info for a single item."""
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
    print(f"  Tier: {info['tier']}")
    print(f"  Computed: {info['computed_tier']}")
    if info.get("override_tier") is not None:
        print(f"  Override: {info['override_tier']}")
    print(f"  Reason: {info['reason']}")
    print(f"  Paths: {', '.join(info['paths']) if info['paths'] else 'none'}")
    # Factor breakdown
    factors = info.get("factors", {})
    if factors:
        print(f"  Factors:")
        if "max_ingredient_tier" in factors:
            print(f"    Max ingredient tier: {factors['max_ingredient_tier']}")
        if "distinct_ingredients" in factors:
            print(f"    Distinct ingredients: {factors['distinct_ingredients']}")
        if "bonus" in factors:
            print(f"    Count bonus: {factors['bonus']}")
        if "input_tier" in factors:
            print(f"    Input tier: {factors['input_tier']}")
        if "contexts" in factors:
            print(f"    Loot contexts: {factors['contexts']}")
        if "score" in factors:
            print(f"    Path score: {factors['score']:.3f}")


def cmd_json(result):
    """Print the full tier records as JSON."""
    print(json.dumps(result["records"], indent=2))


def cmd_full_export(result, info, outfile):
    """Write every item's tier record to a single JSON file."""
    out = {
        "tool": TOOL,
        "pack": info,
        "version": "1",
        "summary": {
            "item_count": result["item_count"],
            "tier_counts": result["tier_counts"],
        },
        "entries": result["records"],
    }

    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")

    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {result['item_count']} items → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
    print(f"  total: {result['timing']['total']:.1f}s", file=sys.stderr)


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
        die("Usage: item-tier.py <pack> [--mods ...] [--json] [--list] [--info <item>] [--full-export [file]]")

    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)

    result = scan_tiers(pack_dir, info, pack, want_mods, scan_dp, scan_van)

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-tiers-full.json"
        cmd_full_export(result, info, outfile)
    elif as_list:
        cmd_list(result)
    elif info_target:
        cmd_info(result, info_target, as_json)
    elif as_json:
        cmd_json(result)
    else:
        # Default: human-readable summary
        print(f"Item Tier — {info.get('name', 'pack')}")
        print(f"  Items: {result['item_count']}")
        print(f"  Tier distribution:")
        for tier in sorted(result["tier_counts"].keys(), key=lambda x: (x == "null", x)):
            count = result["tier_counts"][tier]
            print(f"    Tier {tier}: {count} items")
        print(f"  Timing: load={result['timing']['load']:.1f}s  base={result['timing']['base']:.1f}s  compute={result['timing']['compute']:.1f}s  total={result['timing']['total']:.1f}s")


if __name__ == "__main__":
    main()
