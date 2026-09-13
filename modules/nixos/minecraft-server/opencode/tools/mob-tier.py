#!/usr/bin/env python3
"""Mob Tier CLI — deterministic 0-7 combat-difficulty scorer for pack mobs.

Standalone, stdlib-only. Consumes mob-combat.py's consolidated combat facts and
produces a deterministic 0-7 difficulty tier (7 = hardest) per mob.

Same scoring philosophy as item-tier.py:
  - Weighted geometric mean for the base combat score, so one outlier stat
    (e.g. a huge max_health) does not dominate the result.
  - No guessing. Entities we cannot score get tier=null with an explicit reason,
    never a fallback number.

Two LENSES, reported separately plus a combined tier (so a reader always knows
which one they're looking at):
  combat_score       — 0-7 from the mob's own stats alone (health, attack
                       damage, armor+armor_toughness as effective-DR, with
                       movement speed and knockback resistance as small
                       secondary multipliers).
  context_score      — 0-7 from where/how the mob is encountered (dimension
                       difficulty + spawn rarity). A mob that is both strong AND
                       rare/dimension-gated tiers higher than one equally strong
                       that spawns everywhere in the overworld.
  combined_tier      — combat_score scaled by the encounter context, clamped 0-7.
                       This is the headline number; the two sub-scores explain it.

Passive mobs (cow, chicken, villager...) are NOT scored on the hostile scale.
They get combat_tier / combined_tier = null with mob_class "passive" — a cow is
not "combat tier 0", it is "not a combat encounter at all". They are listed in a
separate passives bucket in the summary.

Bosses / phase-based mobs (ender_dragon, wither, modded summons): the computed
tier reflects BASE STATS ONLY and likely underrepresents real difficulty. They
carry a `boss_note` flag so nobody mistakes the number for the whole picture. No
fake "boss bonus" is added.

custom-only / no-data entities (epicfight-driven combat the tool can't fully
interpret): tier=null with an explicit reason and confidence=partial. We do not
silently score them on vanilla attributes alone.

Dimension-difficulty weighting (established here; the item-tiering system had no
precedent to reuse, so this is the documented scheme):
  overworld = 1.0   (baseline)
  nether    = 1.6
  end       = 2.2
  unknown   = 1.0   (no inferable dimension — treat as baseline, flagged)

The 0-7 combat scale is referenced to a fixed "zombie-like" baseline hostile
(sqrt(20 HP × 3 attack) ≈ 7.75 → tier 3). This keeps tiers absolute and
interpretable across packs instead of shifting with whatever boss happens to be
in a given pack's population.

Usage (manual):
  python3 mob-tier.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                              [--json] [--list] [--info <entity>]
                              [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print entity_id=tier pairs, one per line (fastest for piping).
  --info <entity>   detailed tier info for a single entity (fuzzy match).
  --full-export [f] write every entity's tier record to a single JSON file.
                    If f is omitted, defaults to <packname>-mob-tiers-full.json.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/mob-tier.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-mob-tier opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.
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

TOOL = "mob-tier.py"

# Dimension-difficulty multipliers (documented scheme; no item-tier precedent).
DIMENSION_WEIGHTS = {
    "overworld": 1.0,
    "nether": 1.6,
    "end": 2.2,
}

# Spawn-weight rarity: how much a lower spawn weight raises the context score.
# Weights in modern packs are compressed (common hostile ≈ 10, rare ≈ 1), so use
# a gentle log curve: rarity climbs only for genuinely infrequent spawns and
# stays near 1.0 for common ones. BASE_WEIGHT is the "common hostile" reference.
RARITY_BASE_WEIGHT = 10.0
RARITY_SCALE = 0.15

# Bosses: phase-based / scripted combat whose real difficulty exceeds base stats.
# Vanilla bosses + known modded boss/unique-spawn entities. These get the
# stats-only note. (Populated from an embedded list; annotated entries are
# clearly game-knowledge.)
KNOWN_BOSSES = {
    "minecraft:ender_dragon", "minecraft:wither",
    "minecraft:elder_guardian", "minecraft:warden",
    # Modded bosses / unique summons (stats-only caveat applies).
    "iceandfire:fire_dragon", "iceandfire:ice_dragon",
    "iceandfire:lightning_dragon", "iceandfire:sea_serpent",
    "iceandfire:ghost", "iceandfire:cyclops", "iceandfire:gorgon",
    "iceandfire:hydra", "epicfight:wither_ghost",
    "legendary_monsters:annihilator", "mowziesmobs:grottol",
}

# Mob-class display: entities that are never a combat encounter.
def _is_passive(rec: dict) -> bool:
    return not rec.get("hostile", True)


# ── Score computation ─────────────────────────────────────────────────────────

def _damage_reduction(standard: dict) -> float:
    """Effective damage reduction from armor + armor_toughness.

    Uses a simplified vanilla-like curve scaled into 0..~0.8 so it acts as a
    multiplier on effective health without dominating the geometric mean."""
    armor = standard.get("armor", 0) or 0
    toughness = standard.get("armor_toughness", 0) or 0
    # Vanilla reduces ~4% damage per armor point below 20, roughly. Combine with
    # a toughness share, clamp at 0.8 so no mob becomes effectively immune.
    dr = min(0.8, armor * 0.04 + toughness * 0.03)
    return dr


def _effective_health(standard: dict) -> float:
    hp = standard.get("max_health", 0) or 0
    dr = _damage_reduction(standard)
    return hp / (1.0 - dr) if dr < 1.0 else hp * 5.0


# Reference baseline: a "zombie-like" hostile (sqrt(20 HP × 3 attack) ≈ 7.75)
# maps to tier 3. Fixed so tiers are absolute/interpretable across packs.
ZOMBIE_REFERENCE = math.sqrt(20.0 * 3.0)


def _combat_score(standard: dict) -> float | None:
    """0-7 combat score from stats alone (weighted geometric mean), referenced
    to a fixed zombie-like baseline (tier 3). Returns None if there's no attack
    damage signal (cannot score a combat difficulty)."""
    attack_damage = standard.get("attack_damage", 0) or 0
    if attack_damage <= 0:
        return None
    effective_hp = _effective_health(standard)
    attack_damage = max(attack_damage, 1.0)
    movement = standard.get("movement_speed", 0) or 0
    kb = standard.get("knockback_resistance", 0) or 0
    follow = standard.get("follow_range", 0) or 0

    # Primary threat components combined via geometric mean: sqrt of the product
    # of effective health and attack damage (each weight 1).
    raw_eff_hp_vs_base = effective_hp
    raw_dmg_vs_base = attack_damage

    # Secondary multipliers — small so they modulate but never dominate.
    speed_mult = 1.0 + 0.5 * math.log2(max(movement, 0.01) / 0.25)
    kb_mult = 1.0 + 0.5 * kb
    follow_mult = 1.0 + 0.2 * math.log2(max(follow, 1.0) / 16.0)

    threat = math.sqrt(raw_eff_hp_vs_base * raw_dmg_vs_base) * speed_mult * kb_mult * follow_mult

    base = ZOMBIE_REFERENCE
    ratio = threat / base if base and base > 0 else threat / 7.75
    score = 3.0 + math.log2(max(ratio, 1e-6))
    return min(7.0, max(0.0, score))


def _context_multiplier(rec: dict) -> float:
    """Encounter-context multiplier from dimension difficulty + spawn rarity.

    dims          : list of inferred dimensions (from mob-combat)
    spawn_weight  : min spawn weight across biomes (rare = higher bonus)
    Returns a multiplier applied to combc_score to make combined_tier."""
    dims = rec.get("dimensions") or []
    dim_weight = 1.0
    if dims:
        # "Dimension-gated" means ONLY found in a hard dimension. A mob that also
        # spawns in the overworld is not gated — you meet it at overworld
        # difficulty, so the EASIEST present dimension governs (overworld < nether < end).
        dim_weight = min(DIMENSION_WEIGHTS.get(d, 1.0) for d in dims)
    dim_factor = 1.0 + (dim_weight - 1.0) * 0.5  # compress 1-2.2 into ~1-1.6

    min_weight = rec.get("weight_min")
    rarity_factor = 1.0
    if min_weight is not None and min_weight > 0:
        # Lower spawn weight = rarer = slightly harder to deliberately encounter.
        # log-scaled so it climbs gently; no-spawn entities keep rarity 1.0.
        rarity_factor = 1.0 + RARITY_SCALE * math.log2(1.0 + RARITY_BASE_WEIGHT / min_weight)

    return dim_factor * rarity_factor


def _tier_from_combat(combat_score: float | None, mult: float) -> int | None:
    if combat_score is None:
        return None
    return min(7, max(0, round(combat_score * mult)))


# ── Core scan ─────────────────────────────────────────────────────────────────

def scan_tiers(pack_dir, info, pack, want_mods=None, scan_dp=True, scan_van=True):
    """Compute deterministic combat tiers for every mob in the pack."""
    t0 = time.monotonic()

    extra_args = []
    if want_mods:
        extra_args.extend(["--mods", ",".join(want_mods)])
    if not scan_dp:
        extra_args.append("--no-datapacks")
    if not scan_van:
        extra_args.append("--no-vanilla")

    print("  Loading mob combat facts...", file=sys.stderr)
    tool_path = os.path.join(os.path.dirname(__file__), "mob-combat.py")
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as f:
        tmp_path = f.name
    try:
        cmd = [sys.executable, tool_path, pack, "--full-export", tmp_path] + extra_args
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            die(f"mob-combat.py failed: {result.stderr[:500]}")
        with open(tmp_path) as f:
            combat_data = json.load(f)
    finally:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)

    t_load = time.monotonic()
    entries = combat_data.get("entries", {}) or {}

    # Calibrate the 0-7 scale on the pack's actual hostile population: the raw
    # threat of "an average hostile spawn" maps to tier ~3.
    base = ZOMBIE_REFERENCE

    t_cal = time.monotonic()

    records = {}
    for entity_id in sorted(entries.keys()):
        rec = entries[entity_id]
        std = rec.get("standard") or {}
        is_boss = entity_id in KNOWN_BOSSES
        # Curated game knowledge (KNOWN_BOSSES) overrides the weak no-spawn
        # hostility heuristic: a known boss is always a combat encounter even if
        # its base registry entry reads neutral (e.g. young-stage iceandfire
        # dragons). Its tier is stats-only, flagged accordingly.
        is_passive = _is_passive(rec) and not is_boss

        combat = _combat_score(std) if not is_passive else None
        context_mult = _context_multiplier(rec)
        combined = _tier_from_combat(combat, context_mult)

        # Reason + confidence logic.
        reason = None
        confidence = "full"
        if is_passive:
            reason = "passive mob — not a combat encounter"
            combat = None
            combined = None
        elif combat is None:
            reason = "no attack-damage signal (cannot score combat difficulty)"
            confidence = "partial"
        elif is_boss:
            # Stats-only note: computed from base attributes; real difficulty is
            # higher (scripted / phase-based combat) — never add a fake bonus.
            reason = "boss — tier reflects base stats only and underrepresents real difficulty"
            confidence = "partial"
        elif rec.get("has_custom_combat"):
            reason = "custom combat attributes present — tier scored on vanilla stats only (confidence partial)"
            confidence = "partial"
        else:
            reason = "computed from standard combat attributes"

        records[entity_id] = {
            "id": entity_id,
            "source": rec.get("source"),
            "mod": rec.get("mod"),
            "mob_class": "passive" if is_passive else ("boss" if is_boss else "hostile"),
            "combat_data": rec.get("combat_data"),
            "hostile": rec.get("hostile"),
            # combat_tier = integer tier from stats alone (float combat_score kept raw)
            "combat_tier": (min(7, max(0, round(combat))) if combat is not None and not is_passive else None),
            "combat_score": round(combat, 3) if combat is not None and not is_passive else None,
            "context_score": round(3.0 + math.log2(context_mult), 3) if not is_passive else None,
            "combined_tier": combined,
            "confidence": confidence,
            "reason": reason,
            "boss_note": is_boss,
            "encounter_context": {
                "dimensions": rec.get("dimensions"),
                "dimension_multiplier": round(_context_dim(rec), 3),
                "spawn_weight": rec.get("weight_min"),
                "spawn_rarity_factor": round(_context_rarity(rec), 3),
                "context_multiplier": round(context_mult, 3),
            },
            "factors": {
                "effective_health": round(_effective_health(std), 1) if std else None,
                "damage_reduction": round(_damage_reduction(std), 3) if std else None,
                "attack_damage": std.get("attack_damage"),
                "movement_speed": std.get("movement_speed"),
                "knockback_resistance": std.get("knockback_resistance"),
            },
            "standard_missing": rec.get("standard_missing"),
        }

    t_build = time.monotonic()

    # Distribution summary.
    tier_counts = {}
    class_counts = {}
    for rec in records.values():
        cls = rec["mob_class"]
        class_counts[cls] = class_counts.get(cls, 0) + 1
        t = rec["combined_tier"]
        key = str(t) if t is not None else "null"
        tier_counts[key] = tier_counts.get(key, 0) + 1

    return {
        "records": records,
        "entity_count": len(records),
        "tier_counts": tier_counts,
        "class_counts": class_counts,
        "hostile_count": sum(1 for r in records.values() if r["hostile"]),
        "calibration_base": round(base, 2),
        "timing": {
            "load": t_load - t0,
            "calibrate": t_cal - t_load,
            "build": t_build - t_cal,
            "total": t_build - t0,
        },
    }


def _context_dim(rec: dict) -> float:
    dims = rec.get("dimensions") or []
    if not dims:
        return 1.0
    # Easiest present dimension governs — a mob that also spawns in the
    # overworld is not "dimension-gated" and is met at overworld difficulty.
    return min(DIMENSION_WEIGHTS.get(d, 1.0) for d in dims)


def _context_rarity(rec: dict) -> float:
    min_weight = rec.get("weight_min")
    if min_weight is None or min_weight <= 0:
        return 1.0
    return 1.0 + RARITY_SCALE * math.log2(1.0 + RARITY_BASE_WEIGHT / min_weight)


# ── CLI ───────────────────────────────────────────────────────────────────────

def cmd_list(result):
    """Print entity_id=tier pairs, one per line."""
    for eid in sorted(result["records"].keys()):
        rec = result["records"][eid]
        t = rec["combined_tier"]
        print(f"{eid}={t if t is not None else 'null'}")


def cmd_info(result, target, as_json=False):
    """Print detailed tier info for a single entity."""
    records = result["records"]
    if target in records:
        info = records[target]
    else:
        matches = fuzzy_match(target, list(records.keys()))
        if not matches:
            die(f"No entity found matching '{target}'")
        if len(matches) > 1:
            die(f"Ambiguous '{target}'; did you mean: {', '.join(matches[:5])}")
        info = records[matches[0]]

    if as_json:
        print(json.dumps(info, indent=2))
        return

    print(f"Mob: {info['id']}")
    print(f"  Class: {info['mob_class']}   Source: {info['source']}")
    if info.get("boss_note"):
        print(f"  ⚠ BOSS — computed tier reflects base stats only and underrepresents real difficulty.")
    ct = info["combat_tier"]
    cs = info["combat_score"]
    cc = info["context_score"]
    at = info["combined_tier"]
    print(f"  combat_tier:   {ct if ct is not None else 'n/a'}   (stats alone; raw score {cs if cs is not None else 'n/a'})")
    print(f"  context_score: {cc if cc is not None else 'n/a'}   (dimension + rarity)")
    print(f"  combined_tier: {at if at is not None else 'n/a'}   (combat × context)")
    print(f"  Confidence: {info['confidence']}")
    print(f"  Reason: {info['reason']}")
    ec = info.get("encounter_context") or {}
    if ec:
        print(f"  Encounter: dimensions={ec.get('dimensions')} spawn_weight={ec.get('spawn_weight')} "
              f"(dim_mult={ec.get('dimension_multiplier')} rarity={ec.get('spawn_rarity_factor')})")
    fx = info.get("factors") or {}
    if fx.get("effective_health"):
        print(f"  Factors: effective_health={fx['effective_health']} dmg_reduction={fx['damage_reduction']} "
              f"attack_damage={fx['attack_damage']} speed={fx['movement_speed']} kb={fx['knockback_resistance']}")


def cmd_json(result):
    """Print the full tier records as JSON."""
    print(json.dumps(result["records"], indent=2))


def cmd_full_export(result, info, outfile):
    """Write every entity's tier record to a single JSON file."""
    out = {
        "tool": TOOL,
        "pack": info,
        "version": "1",
        "summary": {
            "entity_count": result["entity_count"],
            "hostile_count": result["hostile_count"],
            "class_counts": result["class_counts"],
            "tier_counts": result["tier_counts"],
            "calibration_base": result["calibration_base"],
        },
        "entries": result["records"],
    }
    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {result['entity_count']} entities → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)
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
        if a in ("--help", "-h"):
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
        die("Usage: mob-tier.py <pack> [--mods ...] [--json] [--list] [--info <entity>] [--full-export [file]]")

    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)

    result = scan_tiers(pack_dir, info, pack, want_mods, scan_dp, scan_van)

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-mob-tiers-full.json"
        cmd_full_export(result, info, outfile)
    elif as_list:
        cmd_list(result)
    elif info_target:
        cmd_info(result, info_target, as_json)
    elif as_json:
        cmd_json(result)
    else:
        # Default: human-readable summary
        print(f"Mob Tier — {info.get('name', 'pack')}")
        print(f"  Entities: {result['entity_count']}  (hostile: {result['hostile_count']})")
        print(f"  Classes: {result['class_counts']}")
        print(f"  Tier distribution (combined):")
        for tier in sorted(result["tier_counts"].keys(), key=lambda x: (x == "null", x)):
            print(f"    Tier {tier}: {result['tier_counts'][tier]}")
        print(f"  Calibration base: {result['calibration_base']}")
        print(f"  Timing: load={result['timing']['load']:.1f}s  build={result['timing']['build']:.1f}s  total={result['timing']['total']:.1f}s")


if __name__ == "__main__":
    main()

# ## RUN LOG