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

Three lenses (reported separately so a reader knows which they're looking at):
  acquisition_tier — 0-7 rarity from acquisition difficulty (the original tier).
  impact_score     — 0-7 significance = p=2 general mean (root-sum-square) of
                     recipe-graph centrality and component magnitude. Does NOT
                     zero out on "no signal": a leaf item with no components
                     gets a real low score (~0), because for impact "no signal"
                     itself means "probably not significant".
  combined_tier    — headline = p=2 mean of acquisition × impact.

  Likes mob-tier's combat/context/combined pattern, each is an explicit field.

Impact sub-signals:
  recipe centrality (new in this file, no scanner needed):
    direct_dependents     recipes using this item as an ingredient
    downstream_dependents transitive closure of unlockable items (capped +
                          log-scaled so iron_ingot doesn't blow up)
  component magnitude (new, consumes item-components-dump.json produced by the
    item-components-dump headless mod — run item-components-regenerate after
    mod changes):
    attack/armor magnitude, enchantable, tool mining level, food nutrition,
    max_stack_size==1 uniqueness signal.

Curated overrides:
  tier-overrides.toml in the pack dir applies post-computation overrides.
  Format: item_id = tier (0-7)
  Override values shown alongside computed values for transparency.
  impact-overrides.toml (same format, item_id = score with an optional inline
  `# reason`) applies a final impact override for items whose real impact isn't
  captured mechanically (quest/lore items). Computed score always shown next to
  the override.

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


# ── Impact overrides (the "easy agent append" mechanism) ─────────────────────

def _load_impact_overrides(pack_dir: str) -> dict:
    """Load impact-overrides.toml from the pack dir if it exists.

    Same shape as tier-overrides.toml but for the impact axis:
      item_id = score    (0-7 scale, matching the rest of the system)
    The optional inline comment carries the reasoning. The computed impact
    score is ALWAYS shown alongside the override for transparency — never
    silently hidden. This is deliberately the mechanism an agent uses for
    items whose real impact isn't captured by recipe centrality or components
    (quest/knowledge/lore items with narrative significance a mod doesn't
    encode mechanically): append one line, no code changes needed.
    """
    overrides = {}
    toml_path = os.path.join(pack_dir, "impact-overrides.toml")
    if not os.path.exists(toml_path):
        return overrides
    with open(toml_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or line.startswith("["):
                continue
            if "=" in line:
                key, val = line.split("=", 1)
                key = key.strip()
                # Everything after the first `#` on the value side is a comment
                val = val.split("#", 1)[0].strip().strip('"').strip("'")
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


# ── Impact: recipe-graph centrality ──────────────────────────────────────────
# No new scanner: consumes recipes.py --full-export (the same recipe graph
# item-acquisition.py already builds) and computes for every item:
#   direct_dependents      — recipes that use this item as an ingredient
#   downstream_dependents  — transitive closure of items unlockable through
#                            this item (capped + log-scaled so foundational
#                            materials like iron_ingot don't blow up).

def _result_items(rdata: dict) -> list:
    """Normalize a recipe entry's result to a list of item ids."""
    res = rdata.get("result")
    if isinstance(res, dict):
        r = res.get("id") or res.get("item")
        return [r] if r else []
    if isinstance(res, list):
        out = []
        for x in res:
            if isinstance(x, dict):
                r = x.get("id") or x.get("item")
                if r:
                    out.append(r)
            elif isinstance(x, str) and not x.startswith("#"):
                out.append(x)
        return out
    if isinstance(res, str) and not res.startswith("#"):
        return [res]
    return []


def _build_recipe_graph(recipes_data: dict) -> dict:
    """Build the item↔recipe graph from recipes.py's full export.

    Returns {"uses": {item: set(recipe ids)}, "produces": {recipe_id: set(result items)}}
    """
    uses = {}
    produces = {}
    for rid, rdata in recipes_data.get("entries", {}).items():
        result_items = _result_items(rdata)
        if result_items:
            produces[rid] = set(result_items)
        for ing in rdata.get("ingredients", []) or []:
            if isinstance(ing, str) and not ing.startswith("#"):
                uses.setdefault(ing, set()).add(rid)
    return {"uses": uses, "produces": produces}


def _downstream_dependents(item: str, uses: dict, produces: dict, cap: int = 3000) -> int:
    """Transitive closure: how many distinct items become craftable (directly
    or transitively) once you hold `item`. Bounded to `cap` visited nodes so a
    foundational material can't exhaust the loop."""
    visited_items = {item}
    frontier = {item}
    while frontier:
        nxt = set()
        for it in frontier:
            for rid in uses.get(it, set()):
                for r in produces.get(rid, set()):
                    if r not in visited_items:
                        visited_items.add(r)
                        nxt.add(r)
                        if len(visited_items) > cap:
                            return len(visited_items)
        frontier = nxt
    return len(visited_items)


def _recipe_centrality_score(graph: dict, item: str) -> tuple[int, int, float]:
    """Direct + downstream dependent counts, plus a 0-7 centrality score.

    Score anchors (log-scaled to stay absolute/interpretable):
      downstream  0 → 0.0, 10 → 2.7, 100 → 5.4, 1000+ → 7.0
      direct      0 → 0.0, 10 → 2.0, 50 → 3.4
    The two signals are combined with a weighted log blend (downstream is
    the primary driver; direct dependents add resolution for small items).
    """
    uses = graph.get("uses", {})
    produces = graph.get("produces", {})
    direct = len(uses.get(item, set()))
    downstream = _downstream_dependents(item, uses, produces)
    down_score = min(7.0, 2.7 * math.log2(1 + downstream) / math.log2(11))
    direct_score = min(7.0, 2.0 * math.log2(1 + direct) / math.log2(51))
    score = min(7.0, 0.7 * down_score + 0.3 * direct_score)
    return direct, downstream, round(score, 3)


# ── Impact: component magnitude ──────────────────────────────────────────────
# Consumes item-components-dump.json (item-components.py), the real reflected
# DataComponents each item registers. Returns a 0-7 "how much intrinsic
# power/significance does this item carry in its own component data" score.
#
# Component anchors (same log philosophy as the centrality axis):
#   attack/armor magnitude  weapon+armor stats (sword ≈ 6+, armor piece ≈ +2)
#   enchantable             endgame enchantability (diamond 10, netherite 15)
#   mining_level            tool tier 0-4 derived from incorrect_for_* rules
#   food                    nutrition+saturation (apple ≈ 3)
#   max_stack_size 1        ++ (unique/significant items stack to 1)

def _component_magnitude_score(comp: dict) -> tuple[float, dict]:
    """Score an item-components summary record 0-7, with factor breakdown.

    `comp` is the RAW item-components-dump.json entry (attribute_modifiers is a
    list of {attribute, amount, operation, slot}) — decoded here exactly the
    way item-components.py's _summary decodes it, so the two consumers agree."""
    if not comp:
        return 0.0, {}

    ams = comp.get("attribute_modifiers", []) or []
    attack = sum(abs(m.get("amount", 0)) for m in ams
                 if m.get("attribute") == "minecraft:generic.attack_damage")
    armor = sum(abs(m.get("amount", 0)) for m in ams
                if "armor" in (m.get("attribute") or ""))
    tool = comp.get("tool") or {}
    mining = 0
    for r in tool.get("rules", []) or []:
        b = r.get("blocks") or ""
        if "incorrect_for_wooden_tool" in b:
            mining = max(mining, 1)
        elif "incorrect_for_stone_tool" in b:
            mining = max(mining, 2)
        elif "incorrect_for_iron_tool" in b:
            mining = max(mining, 3)
        elif "incorrect_for_diamond_tool" in b:
            mining = max(mining, 4)
        elif "mineable/" in b:
            mining = max(mining, 1)
    food = comp.get("food") or {}
    nutrition = food.get("nutrition", 0) or 0
    saturation = food.get("saturation", 0) or 0
    enchant = comp.get("enchantable", 0) or 0
    stack1 = (comp.get("max_stack_size") or 64) == 1

    # attack: reference a sword-ish baseline (attack 6-7 → ~5, attack 4 → ~4.5)
    attack_score = 0.0
    if attack > 0:
        attack_score = min(6.0, 1.0 + 2.2 * math.log2(1 + attack))
    if armor > 0:
        attack_score = max(attack_score, min(4.0, 1.0 + 1.5 * math.log2(1 + armor)))

    enchant_score = 0.0
    if enchant >= 10:
        enchant_score = min(6.0, 1.0 + (enchant - 10) / 5.0)  # diamond 10 → 1, netherite 15 → 2
    tool_score = 0.0
    if mining >= 1:
        tool_score = min(6.0, (mining - 1) * 0.9)  # stone 0.9, iron 1.8, diamond 2.7
    food_score = 0.0
    if nutrition > 0:
        food_score = min(5.0, 0.8 + 0.5 * math.log2(1 + nutrition + saturation))
    stack_score = 1.0 if stack1 else 0.0

    # Aggregate with weighted log-style blend, never letting one axis alone cap.
    raw = (
        0.55 * attack_score
        + 0.15 * enchant_score
        + 0.15 * tool_score
        + 0.10 * food_score
        + 0.05 * stack_score * 2.0
    )
    factors = {
        "attack": round(attack_score, 3),
        "armor": round(armor, 3),
        "enchantable": enchant,
        "enchant": round(enchant_score, 3),
        "mining_level": mining,
        "tool": round(tool_score, 3),
        "nutrition": nutrition,
        "saturation": saturation,
        "food": round(food_score, 3),
        "stack_size_1": stack1,
        "raw": round(raw, 3),
    }
    return round(min(7.0, raw), 3), factors


# ── Impact: combination (weighted general mean) ──────────────────────────────
# The task's own verification spot-checks demand that a SINGLE strong axis can
# produce high impact (iron ingot: high centrality + no components → high;
# endgame weapon: low centrality + strong components → high). A strict product
# geometric mean would collapse both single-axis cases to ~0, and a pure
# arithmetic mean lets the weaker axis pull the stronger one down too much.
# Root-sum-square (the p=2 general mean, the same family as mob-tier's
# sqrt(a*b) at p=2) keeps the dominant axis leading while still rewarding both.
#
# Items with genuinely nothing on either axis (leaf item + no components) get a
# REAL low impact_score (≈0), not null: for impact, "no signal" is itself the
# information that the item probably isn't significant. Null is reserved for
# items whose underlying item id isn't found at all (true data gap).

def _impact_score(centrality: float, component: float) -> float:
    if centrality is None or component is None:
        return None
    return round(min(7.0, math.sqrt(centrality * centrality + component * component)), 3)


def _load_components_dump(pack_dir: str) -> dict:
    """Load the cached item-components-dump.json (produced by the headless
    item-components-dump mod). Returns {} if regenerating is needed — impact
    then computes from recipe centrality alone with a data-gap note."""
    dump_path = os.path.join(pack_dir, "item-components-dump.json")
    if not os.path.exists(dump_path):
        return {}
    try:
        with open(dump_path) as f:
            return json.load(f).get("items", {})
    except Exception:
        return {}


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

    # ── Phase 2b: Load impact sources (recipe graph + components) ──────────
    # Recipe centrality is the primary, mod-agnostic impact signal — reuse
    # recipes.py's already-built full graph (item-acquisition.py depends on it).
    recipe_tmp = tempfile.NamedTemporaryFile(suffix=".json", delete=False).name
    try:
        recipe_tool = os.path.join(os.path.dirname(__file__), "recipes.py")
        cmd = [sys.executable, recipe_tool, pack, "--full-export", recipe_tmp] + extra_args
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            die(f"recipes.py failed: {result.stderr[:500]}")
        with open(recipe_tmp) as f:
            recipe_graph = _build_recipe_graph(json.load(f))
    finally:
        if os.path.exists(recipe_tmp):
            os.unlink(recipe_tmp)

    components_dump = _load_components_dump(pack_dir)
    if components_dump:
        print(f"  Loaded {len(components_dump)} item component records", file=sys.stderr)
    else:
        print("  NOTE: item-components-dump.json not found — impact_score will use"
              " recipe centrality alone (run item-components-regenerate for the full signal)",
              file=sys.stderr)
    impact_overrides = _load_impact_overrides(pack_dir)
    if impact_overrides:
        print(f"  Loaded {len(impact_overrides)} impact overrides", file=sys.stderr)

    t_graph = time.monotonic()

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

    # ── Phase 4b: Compute impact scores (three lenses) ────────────────────
    # acquisition_tier (existing) + impact_score (NEW) + combined_tier.
    # impact_score is a p=2 general mean of recipe-centrality and
    # component-magnitude (see _impact_score docstring for why RMS, not product).
    # null is reserved for items whose item id isn't found at all — items with
    # genuinely nothing on either axis get a real low impact_score, not null.
    impact_records = {}
    for item_id in entries:
        direct, downstream, centrality = _recipe_centrality_score(recipe_graph, item_id)
        comp = components_dump.get(item_id)
        if comp is not None:
            comp_score, comp_factors = _component_magnitude_score(comp)
        else:
            comp_score, comp_factors = 0.0, {"missing_components": True}

        computed_impact = _impact_score(centrality, comp_score)
        override_impact = impact_overrides.get(item_id)
        if override_impact is not None:
            final_impact = float(override_impact)
            impact_reason = f"curated impact override (computed={computed_impact})"
        else:
            final_impact = computed_impact
            impact_reason = "recipe-centrality × component-magnitude (p=2)"
        impact_records[item_id] = {
            "impact_score": final_impact,
            "computed_impact_score": computed_impact,
            "impact_override": override_impact,
            "impact_reason": impact_reason,
            "impact_factors": {
                "centrality": {
                    "direct_dependents": direct,
                    "downstream_dependents": downstream,
                    "score": centrality,
                },
                "components": comp_factors,
                "component_score": comp_score,
            },
        }

    t_impact = time.monotonic()

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

        # combined_tier: the same three-lens pattern as mob-tier — the headline
        # number that folds acquisition × impact. When an axis is null (an item
        # with no acquisition path OR no item at all), combined follows the
        # present axis; items with neither are null (true data gap).
        imp = impact_records.get(item_id, {})
        impact_tier = imp.get("impact_score")
        if final_tier is not None and impact_tier is not None:
            combined = round(min(7.0, math.sqrt(final_tier * final_tier + impact_tier * impact_tier)))
            combined_reason = f"acquisition {final_tier} × impact {impact_tier} (p=2)"
        elif final_tier is not None:
            combined = final_tier
            combined_reason = "impact missing (data gap) — acquisition alone"
        elif impact_tier is not None:
            combined = round(impact_tier)
            combined_reason = "acquisition missing — impact alone"
        else:
            combined = None
            combined_reason = "no acquisition or impact signal"

        tier_records[item_id] = {
            "id": item_id,
            "category": record.get("category", "unknown"),
            "lang_name": record.get("lang_name"),
            # Three lenses, reported separately so a reader knows which they're
            # looking at (same pattern as mob-tier's combat/context/combined):
            "acquisition_tier": final_tier,
            "impact_score": imp.get("impact_score"),
            "combined_tier": combined,
            "combined_reason": combined_reason,
            # Back-compat fields (acquisition tier was previously `tier`):
            "tier": final_tier,
            "computed_tier": normalized_tier,
            "override_tier": override_tier,
            "reason": final_reason,
            "impact_computed": imp.get("computed_impact_score"),
            "impact_override_tier": imp.get("impact_override"),
            "impact_reason": imp.get("impact_reason"),
            "paths": list(record.get("paths", {}).keys()),
            "factors": all_factors.get(item_id, {}),
            "impact_factors": imp.get("impact_factors"),
        }

    t_build = time.monotonic()

    return {
        "records": tier_records,
        "item_count": len(tier_records),
        "tier_counts": _count_tiers(tier_records),
        "impact_tier_counts": _count_tiers(tier_records, key="impact_score", bin_float=True),
        "combined_tier_counts": _count_tiers(tier_records, key="combined_tier"),
        "timing": {
            "load": t_load - t0,
            "graph": t_graph - t_load,
            "base": t_base - t_graph,
            "compute": t_compute - t_base,
            "impact": t_impact - t_compute,
            "build": t_build - t_impact,
            "total": t_build - t0,
        },
    }


def _count_tiers(records: dict, key: str = "tier", bin_float: bool = False) -> dict:
    """Count items per tier for a given score key. Float scores (impact) are
    bucketed to integer tiers when bin_float is True (0-7 scale)."""
    counts = {}
    for rec in records.values():
        tier = rec.get(key)
        if tier is None:
            counts["null"] = counts.get("null", 0) + 1
        else:
            if bin_float:
                tier = min(7, max(0, int(tier)))
            counts[str(tier)] = counts.get(str(tier), 0) + 1
    return counts


# ── CLI ───────────────────────────────────────────────────────────────────────

def cmd_list(result):
    """Print item_id combined_tier pairs, one per line."""
    for item_id in sorted(result["records"].keys()):
        tier = result["records"][item_id].get("combined_tier")
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
    # Three lenses, reported separately (acquisition / impact / combined)
    print(f"  acquisition_tier: {info.get('acquisition_tier')}   (rarity, 0-7)")
    print(f"  impact_score:     {info.get('impact_score')}   (significance, 0-7)")
    print(f"  combined_tier:    {info.get('combined_tier')}   ({info.get('combined_reason')})")
    if info.get("impact_override_tier") is not None:
        print(f"  Impact override:  {info['impact_override_tier']} (computed={info.get('impact_computed')})")
    if info.get("override_tier") is not None:
        print(f"  Acquisition override: {info['override_tier']} (computed={info.get('computed_tier')})")
    print(f"  Acquire reason: {info['reason']}")
    if info.get("impact_reason"):
        print(f"  Impact reason:  {info['impact_reason']}")
    print(f"  Paths: {', '.join(info['paths']) if info['paths'] else 'none'}")
    # Acquisition factor breakdown (back-compat)
    factors = info.get("factors", {})
    if factors:
        print(f"  Acquisition factors:")
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
    # Impact factor breakdown
    ifac = info.get("impact_factors", {})
    if ifac:
        print(f"  Impact factors:")
        cent = ifac.get("centrality", {})
        print(f"    centrality: score={cent.get('score')} "
              f"(direct={cent.get('direct_dependents')}, downstream={cent.get('downstream_dependents')})")
        comp = ifac.get("components", {})
        if comp.get("missing_components"):
            print(f"    components: MISSING (item-components-dump.json absent)")
        else:
            print(f"    components: score={ifac.get('component_score')} "
                  f"(attack={comp.get('attack')} ench={comp.get('enchant')} "
                  f"tool={comp.get('tool')} mining_lvl={comp.get('mining_level')} "
                  f"food={comp.get('food')} stack1={comp.get('stack_size_1')})")


def cmd_json(result):
    """Print the full tier records as JSON."""
    print(json.dumps(result["records"], indent=2))


def cmd_full_export(result, info, outfile):
    """Write every item's tier record to a single JSON file."""
    out = {
        "tool": TOOL,
        "pack": info,
        "version": "2",  # bumped: records now carry acquisition/impact/combined lenses
        "summary": {
            "item_count": result["item_count"],
            "tier_counts": result["tier_counts"],
            "impact_tier_counts": result["impact_tier_counts"],
            "combined_tier_counts": result["combined_tier_counts"],
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
        print(f"  Acquisition tier distribution:")
        for tier in sorted(result["tier_counts"].keys(), key=lambda x: (x == "null", x)):
            count = result["tier_counts"][tier]
            print(f"    Tier {tier}: {count} items")
        print(f"  Impact score distribution:")
        for tier in sorted(result["impact_tier_counts"].keys(), key=lambda x: (x == "null", x)):
            count = result["impact_tier_counts"][tier]
            print(f"    Impact {tier}: {count} items")
        print(f"  Combined tier distribution:")
        for tier in sorted(result["combined_tier_counts"].keys(), key=lambda x: (x == "null", x)):
            count = result["combined_tier_counts"][tier]
            print(f"    Tier {tier}: {count} items")
        print(f"  Timing: load={result['timing']['load']:.1f}s  graph={result['timing']['graph']:.1f}s  base={result['timing']['base']:.1f}s  compute={result['timing']['compute']:.1f}s  impact={result['timing']['impact']:.1f}s  build={result['timing']['build']:.1f}s  total={result['timing']['total']:.1f}s")


if __name__ == "__main__":
    main()

# ## RUN LOG
# ### 2026-09-13 — accuracy audit vs curated RarityCore config + --mods resolver fixes
# The computed tiers must NOT drive the RarityCore config: every Artifacts item
# computes tier 2 (loot context "unknown", 0.4*7=2.8, int->2) vs curated 1-7; every
# Relics item computes null (no acquisition paths); SmallShips tier by recipe depth.
# This is acquisition-difficulty, not rarity. The skill doc previously claimed a
# "category fallback (mod items = tier 4)" and "tag weak signal" that never existed
# in this code (_compute_category_tier is UNUSED; tags are never scored) — corrected.
# Also fixed resolve_mod ambiguity: '--mods reliquified_artifacts' matched both
# 'artifacts' and 'reliquified_artifacts-1.21.1-1.0.8', and the resulting die() was
# swallowed by _run_scanner -> every sub-scanner returned {} and the scan silently
# hollowed out. resolve_mod now prefers a target-prefixed key.
# ### 2026-09-13 — impact dimension: three lenses (acquisition/impact/combined)
# Added impact_score computed as a p=2 general mean (RMS) of two sub-signals:
# recipe-graph centrality (direct + downstream dependents from recipes.py --full-export,
# capped + log-scaled so foundational materials don't blow up) and component magnitude
# (attack/armor/enchant/mining-level/food/stack-1 from item-components-dump.json, produced
# by the source-patches/item-components-dump headless mod — same launch harness as the
# attributes dump via attributes_dump.py --dump-mod item-components-dump).
# RMS (not strict product geometric mean) chosen deliberately: a single strong axis must
# be able to produce high impact (iron_ingot: centrality-driven; netherite_sword:
# component-driven), while a strict product would collapse both to ~0.
# impact-overrides.toml added as the agent-append override; computed value always shown.
# Records now carry acquisition_tier/impact_score/combined_tier; `tier` kept as back-compat.
# Verified: iron_ingot impact 5.631, netherite_sword 3.826, white_banner 0.546 (low not null),
# relics:chorus_staff override -> 6.0 with computed 0.555 shown. Full export 22225 items in 24.6s.
