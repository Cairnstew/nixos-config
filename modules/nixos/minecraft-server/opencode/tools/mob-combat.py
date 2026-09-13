#!/usr/bin/env python3
"""Mob Combat CLI — consolidate the raw combat-relevant facts for every entity.

Standalone, stdlib-only. Cross-references the entity attribute dump
(attributes.py) with biome spawn data (mobspawn.py) to record the *facts* about
how dangerous a mob is — its standard combat attributes, any custom mod combat
attributes it carries, and where/how often it spawns. This tool has NO scoring
opinion; it only consolidates evidence. Scoring lives in mob-tier.py.

Design principles:
  - Every entity in the attribute dump is recorded.
  - Standard combat attributes come from minecraft:generic.* (the NeoForge
    attribute registry). Custom mod attributes (epicfight:impact, etc.) are
    recorded separately and tagged by namespace — we do NOT fold them into a
    generic score, because we don't know each mod's semantics.
  - Spawn data is cross-referenced from mobspawn.py: spawn weight, biomes,
    inferred dimension(s), and mob category (monster/creature/ambient/...).
  - Each entity gets a combat-data completeness classification:
      full         — has standard combat attributes (attack_damage + max_health)
      passive-only — has health/movement but no attack_damage — genuinely
                     non-hostile, NOT a data gap
      custom-only  — combat driven primarily by custom attributes this tool
                     can't interpret (e.g. an epicfight mob whose real
                     difficulty isn't captured by vanilla attack_damage)
      no-data      — no attribute entry at all (flagged explicitly, never guessed)
  - Hostility (whether a mob is a combat encounter at all) is a SEPARATE signal
    from data completeness: a cow has full attributes but is not hostile. The
    `hostile` field uses spawn category + the vanilla friendly metadata, so
    mob-tier.py can exclude passives from the numeric tier without confusing
    "full data" with "this is a combat threat".

Usage (manual):
  python3 mob-combat.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                                 [--json] [--list] [--info <entity>]
                                 [--full-export [outfile]]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --mods            restrict the jar scan to these mods (comma-separated slugs).
  --no-datapacks    skip the pack's datapacks (config/paxi/datapacks/ + data/).
  --no-vanilla      omit the embedded vanilla baseline.
  --json            machine-readable JSON document (stable schema, see below).
  --list            print just the entity ids, one per line (fastest for piping).
  --info <entity>   detailed combat facts for a single entity (fuzzy match).
  --full-export [f] write every entity's combat record to a single JSON file.
                    If f is omitted, defaults to <packname>-mob-combat-full.json.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/mob-combat.py (scoped-exception
dir — direct RUN LOG edits are expected; a `note=` path exists on the
packwiz-mob-combat opencode tool which appends to its own .ts + skill). Append
dated fixes to the // ## RUN LOG-style block at the end of THIS file.
"""

import os
import sys
import json
import subprocess
import tempfile
import time

from datapack_common import (
    die, repo_root, resolve_pack_dir, read_pack_info, fuzzy_match,
    find_mod_jars, resolve_mod,
)

TOOL = "mob-combat.py"

# ── Standard combat attributes (NeoForge registry names) ──────────────────────
# These are the vanilla-standard attributes whose semantics we understand.
STANDARD_ATTRIBUTES = {
    "minecraft:generic.max_health": "max_health",
    "minecraft:generic.attack_damage": "attack_damage",
    "minecraft:generic.armor": "armor",
    "minecraft:generic.armor_toughness": "armor_toughness",
    "minecraft:generic.movement_speed": "movement_speed",
    "minecraft:generic.knockback_resistance": "knockback_resistance",
    "minecraft:generic.follow_range": "follow_range",
}
# Aliases some mods register for the same concept (attribute ID → canonical short)
ATTRIBUTE_ALIASES = {
    "minecraft:generic.attack_knockback": "attack_knockback",
}

# Custom-mod combat namespaces that indicate a combat-overhaul mod the tool
# can't fully interpret. Presence of non-default values from one of these means
# the mob's real difficulty may not be captured by vanilla attack_damage alone,
# so mob-tier.py should mark it confidence: partial.
#
# Two tiers of namespace:
#   COMBAT_OVERHAUL_NAMESPACES — anything that augments combat (used for the
#     `has_custom_combat` flag / confidence signal). Includes apothic_attributes,
#     which is an RPG-stat mod that adds passive attributes to EVERY entity.
#   COMBAT_DRIVEN_NAMESPACES — a genuine combat-overhaul whose custom attributes
#     can carry a mob's entire real difficulty even when vanilla attack_damage is
#     absent/neutral (epicfight is the canonical example). Only these drive the
#     "custom-only" combat-data classification; apothic is present on everything
#     so it cannot distinguish a custom-driven mob from a vanilla-shaped one.
COMBAT_OVERHAUL_NAMESPACES = {"epicfight", "bettercombat", "apothic_attributes"}
COMBAT_DRIVEN_NAMESPACES = {"epicfight", "bettercombat"}

# Spawn categories that represent a hostile/combat encounter vs a passive one.
# A mob that ONLY appears in the non-hostile set (and never as monster) is not
# a combat encounter.
HOSTILE_CATEGORIES = {"monster"}
NON_HOSTILE_CATEGORIES = {
    "creature", "ambient", "water_creature", "water_ambient",
    "underground_water_creature", "axolotls", "misc",
}

# Vanilla friendly-metadata source (mobs.py) — used as an extra hostility signal
# for vanilla entities that may not be listed in spawn data by category.
def _load_vanilla_friendly() -> dict:
    """Load {entity_id: friendly_bool} for the vanilla baseline from mobs.py."""
    try:
        import importlib.util
        path = os.path.join(os.path.dirname(__file__), "mobs.py")
        spec = importlib.util.spec_from_file_location("mobsmod", path)
        mobs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mobs)
        vanilla = mobs.VANILLA_BY_MC.get("1.21.1", {}).get("mobs", {})
        return {eid: meta.get("friendly", False) for eid, meta in vanilla.items()}
    except Exception:
        return {}


# ── Biome → dimension inference ────────────────────────────────────────────────
# Vanilla has no biome→dimension data file in the client jar (the mapping lives
# in the registry). We infer from biome id naming + known vanilla nether/end
# biome set. Modnether/end biome ids are caught by name pattern. This powers the
# encounter-context factor in mob-tier.py.

VANILLA_NETHER_BIOMES = {
    "minecraft:nether_wastes", "minecraft:soul_sand_valley", "minecraft:crimson_forest",
    "minecraft:warped_forest", "minecraft:basalt_deltas",
}
VANILLA_END_BIOMES = {
    "minecraft:the_end", "minecraft:end_barrens", "minecraft:end_highlands",
    "minecraft:end_midlands", "minecraft:small_end_islands",
}


def infer_dimension(biome_id: str) -> str:
    """Infer overworld/nether/end from a biome id (naming + known vanilla set)."""
    bid = biome_id.lower()
    if bid in VANILLA_NETHER_BIOMES or "nether" in bid:
        return "nether"
    if bid in VANILLA_END_BIOMES or bid.endswith("_end") or "endland" in bid:
        return "end"
    return "overworld"


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


# ── Classification ────────────────────────────────────────────────────────────

def classify_combat_data(attrs: dict) -> str:
    """Classify combat-data completeness for an entity's attribute dict.

    full         — attack_damage AND max_health present (standard combat attrs)
    passive-only — has health/movement but NO attack_damage → genuinely
                   non-hostile, not a data gap
    custom-only  — has attribute data but combat driven primarily by custom
                   attributes (no standard attack_damage signal, yet carries
                   meaningful combat-overhaul custom attrs)
    no-data      — no attribute dict at all
    """
    if not attrs:
        return "no-data"
    ad = attrs.get("minecraft:generic.attack_damage")
    hp = attrs.get("minecraft:generic.max_health")
    has_std_attack = isinstance(ad, (int, float)) and ad > 0
    has_std_hp = isinstance(hp, (int, float)) and hp > 0

    # Meaningful custom combat attributes = non-default values from a
    # combat-overhaul namespace (e.g. epicfight:impact != 0).
    meaningful_custom = _meaningful_custom_combat(attrs)

    if has_std_attack and has_std_hp:
        return "full"
    if _meaningful_custom_combat(attrs, COMBAT_DRIVEN_NAMESPACES):
        # Combat driven by custom attributes we can't interpret (no vanilla
        # attack stat, but real combat-overhaul custom data exists).
        return "custom-only"
    if has_std_hp or attrs:
        # Has health/movement but no attack signal → genuinely non-hostile.
        return "passive-only"
    return "no-data"


def _meaningful_custom_combat(attrs: dict, namespaces: set = None) -> bool:
    """True if the entity carries non-default combat-overhaul custom attributes.

    `namespaces` defaults to the broad COMBAT_OVERHAUL_NAMESPACES (for the
    confidence / has_custom_combat flag). Pass COMBAT_DRIVEN_NAMESPACES for the
    classification "custom-only" decision."
    """
    if namespaces is None:
        namespaces = COMBAT_OVERHAUL_NAMESPACES
    for key, val in attrs.items():
        if ":" not in key:
            continue
        ns = key.split(":", 1)[0]
        if ns not in namespaces:
            continue
        # Skip neutral defaults these mods set on everything (1.0 = identity).
        if isinstance(val, (int, float)) and val not in (0.0, 1.0, 0, 1):
            return True
    return False


def _hostility(spawn_data: dict, entity_id: str, vanilla_friendly: dict) -> bool:
    """Whether an entity is a combat encounter, from spawn categories + vanilla
    friendly metadata. Separate from data completeness."""
    cats = spawn_data.get("categories", [])
    if "monster" in cats:
        return True
    # If we have spawn data and it's all non-hostile categories → passive.
    if cats:
        return False
    # No spawn data: fall back to vanilla friendly metadata.
    return not vanilla_friendly.get(entity_id, True)


def _combat_capable(standard: dict, attrs: dict) -> dict:
    """For a no-natural-spawn entity, decide hostility from STRONG attribute
    signals only, and return (hostile, source) explaining the decision.

    No-spawn modded entities are genuinely ambiguous (minecolonies raiders and
    iceandfire dragons are hostile; bees, particles and decorative entities are
    not, and the attribute dump can't separate them). We only commit to
    `hostile=True` on signals that are very unlikely to be a neutral default:
    a combat-overhaul custom attribute, a huge max_health (a summoned boss), or
    an attack_damage well above the universal neutral default of ~2.0. Everything
    else is left non-hostile — a modded boss whose base registry entry
    underreports its real stats (e.g. iceandfire dragons read as young-stage:
    20 HP / 1 AD) is flagged as NOT reliably representable rather than guessed.
    """
    if _meaningful_custom_combat(attrs, COMBAT_DRIVEN_NAMESPACES):
        return True, "combat-overhaul custom attributes"
    if standard.get("max_health", 0) >= 80:
        return True, "high base max_health (summoned boss)"
    if standard.get("attack_damage", 0) > 5:
        return True, "high base attack_damage"
    return False, "no natural spawn + no strong combat signal (neutral default)"


# ── Core scan ─────────────────────────────────────────────────────────────────

def scan_combat(pack_dir, info, pack, want_mods=None, scan_dp=True, scan_van=True):
    """Build a combat-facts record for every entity with attribute data."""
    t0 = time.monotonic()

    extra_args = []
    # NOTE: --mods is NOT passed to attributes.py — it reads the cached
    # attributes-dump.json (attribute-centric, no jar scan), so a --mods filter
    # there is an argparse error that silently hollows out the whole scan
    # (_run_scanner swallows the failure and returns {}). Filter the records
    # post-hoc by entity namespace instead (below).
    if not scan_van:
        extra_args.append("--no-vanilla")

    print("  Loading attributes...", file=sys.stderr)
    attr_data = _run_scanner("attributes.py", pack, extra_args)
    print("  Loading mob spawn data...", file=sys.stderr)
    spawn_extra = []
    if want_mods:
        spawn_extra.extend(["--mods", ",".join(want_mods)])
    if not scan_dp:
        spawn_extra.append("--no-datapacks")
    if not scan_van:
        spawn_extra.append("--no-vanilla")
    spawn_data = _run_scanner("mobspawn.py", pack, spawn_extra)

    t_scan = time.monotonic()

    vanilla_friendly = _load_vanilla_friendly()

    # Build per-mob spawn summary from effective_biomes.
    # mob_id → {categories, weight_min, weight_max, biomes, dimensions}
    mob_spawn = {}
    effective = spawn_data.get("effective_biomes", {})
    for biome_id, cats_data in effective.items():
        for cat, entries in cats_data.items():
            for e in entries:
                mob_type = e.get("type", "")
                if not mob_type:
                    continue
                rec = mob_spawn.setdefault(mob_type, {
                    "categories": [], "weights": [],
                    "biomes": set(), "dimensions": set(),
                })
                if cat not in rec["categories"]:
                    rec["categories"].append(cat)
                w = e.get("weight")
                if w is not None:
                    rec["weights"].append(w)
                rec["biomes"].add(biome_id)
                rec["dimensions"].add(infer_dimension(biome_id))

    # Consolidate spawn fact sets.
    def _spawn_facts(mob_type: str) -> dict:
        rec = mob_spawn.get(mob_type, {})
        cats = rec.get("categories", [])
        weights = rec.get("weights", [])
        dims = sorted(rec.get("dimensions", [])) or None
        return {
            "spawns_naturally": bool(cats),
            "categories": sorted(cats),
            "weight_min": min(weights) if weights else None,
            "weight_max": max(weights) if weights else None,
            "biome_count": len(rec.get("biomes", set())),
            "dimensions": dims,
        }

    records = {}
    entities = attr_data.get("entities", {}) or {}
    for entity_id in sorted(entities.keys()):
        edata = entities[entity_id]
        attrs = edata.get("attributes", {}) or {}
        spawn_facts = _spawn_facts(entity_id)

        # Standard combat attributes.
        standard = {}
        for attr_key, short in STANDARD_ATTRIBUTES.items():
            val = attrs.get(attr_key)
            if isinstance(val, (int, float)):
                standard[short] = val
        for attr_key, short in ATTRIBUTE_ALIASES.items():
            if short not in standard and isinstance(attrs.get(attr_key), (int, float)):
                standard[short] = attrs[attr_key]

        # Custom mod attributes, tagged separately by namespace.
        custom_attrs = {}
        for key, val in attrs.items():
            if key in STANDARD_ATTRIBUTES or key in ATTRIBUTE_ALIASES:
                continue
            ns = key.split(":", 1)[0] if ":" in key else "unknown"
            custom_attrs.setdefault(ns, {})[key] = val

        classification = classify_combat_data(attrs)

        # Hostility: authoritative spawn category when present; for no-spawn
        # entities fall back to vanilla friendly metadata, then combat capability
        # (so modded boss summons like epicfight:wither_ghost read hostile). We
        # record WHY so a reader can tell an aggressive mob from a neutral one
        # that merely has high-but-neutral stats.
        if spawn_facts["spawns_naturally"]:
            hostile = _hostility(spawn_facts, entity_id, vanilla_friendly)
            hostile_source = "spawn category"
        else:
            friendly = vanilla_friendly.get(entity_id)
            if friendly is not None:
                hostile = not friendly
                hostile_source = f"vanilla friendly metadata (friendly={friendly})"
            else:
                hostile, hostile_source = _combat_capable(standard, attrs)

        records[entity_id] = {
            "id": entity_id,
            "source": edata.get("source", "unknown"),
            "mod": edata.get("mod"),
            "combat_data": classification,
            "hostile": hostile,
            "hostility_source": hostile_source,
            "standard": standard,
            "standard_missing": sorted(
                short for short in (
                    "max_health", "attack_damage", "armor", "armor_toughness",
                    "movement_speed", "knockback_resistance", "follow_range",
                ) if short not in standard
            ),
            "custom_attributes": custom_attrs,
            "has_custom_combat": _meaningful_custom_combat(attrs),
            **spawn_facts,
        }

    t_build = time.monotonic()

    # Post-hoc --mods filter.
    # attributes.py reads a cached attribute-centric dump and cannot filter by
    # mod; we resolve the requested slugs to their entity namespaces (from
    # find_mod_jars aliases, so both 'iceandfire-ce' and the 'iceandfire'
    # namespace work) and keep records whose entity namespace belongs to one.
    if want_mods:
        mods = find_mod_jars(pack_dir)
        keep_ns = set()
        for t in want_mods:
            k = resolve_mod(mods, t)
            if k is None:
                die(f"no mod '{t}' in pack")
            ns = k.split("-")[0].split(" ")[0].lower().replace(" ", "_")
            keep_ns.add(ns)
            # Exact pw_toml stem is a namespace too when it's a bare name.
            toml = mods[k]["pw_toml"]
            if toml.endswith(".pw.toml"):
                stem = toml[:-8].lower().replace(" ", "_")
                keep_ns.add(stem)
        records = {eid: rec for eid, rec in records.items()
                   if eid.split(":", 1)[0] in keep_ns}

    # Classification + hostility summary for the summary line.
    by_class = {}
    hostile_count = 0
    for rec in records.values():
        by_class[rec["combat_data"]] = by_class.get(rec["combat_data"], 0) + 1
        if rec["hostile"]:
            hostile_count += 1

    return {
        "records": records,
        "entity_count": len(records),
        "classification_counts": by_class,
        "hostile_count": hostile_count,
        "timing": {
            "scan": t_scan - t0,
            "build": t_build - t_scan,
            "total": t_build - t0,
        },
    }


# ── CLI commands ──────────────────────────────────────────────────────────────

def cmd_list(result):
    """Print entity ids, one per line."""
    for eid in sorted(result["records"].keys()):
        print(eid)


def cmd_info(result, target, as_json=False):
    """Print detailed combat facts for a single entity."""
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

    print(f"Entity: {info['id']}")
    print(f"  Source: {info['source']}  (mod: {info['mod'] or 'n/a'})")
    print(f"  Combat data: {info['combat_data']}")
    print(f"  Hostile encounter: {'yes' if info['hostile'] else 'no (passive)'}")
    print(f"  Hostility basis: {info.get('hostility_source', 'n/a')}")
    std = info.get("standard", {})
    if std:
        print(f"  Standard combat attributes:")
        for k in ("max_health", "attack_damage", "armor", "armor_toughness",
                  "movement_speed", "knockback_resistance", "follow_range"):
            if k in std:
                print(f"    {k}: {std[k]}")
    if info.get("standard_missing"):
        print(f"  Missing standard attrs: {', '.join(info['standard_missing'])}")
    if info.get("has_custom_combat"):
        print(f"  Custom combat attributes present (confidence: partial):")
        for ns, vals in (info.get("custom_attributes") or {}).items():
            if ns in COMBAT_OVERHAUL_NAMESPACES and any(
                isinstance(v, (int, float)) and v not in (0.0, 1.0)
                for v in vals.values()
            ):
                print(f"    [{ns}] {list(vals.keys())}")
    if info.get("spawns_naturally"):
        print(f"  Spawn: categories={info['categories']} "
              f"weight {info['weight_min']}-{info['weight_max']} "
              f"biomes={info['biome_count']} dimensions={info['dimensions']}")
    else:
        print(f"  Spawn: no natural spawn data (boss/summoned/event)")


def cmd_json(result):
    """Print the full combat records as JSON."""
    print(json.dumps(result["records"], indent=2))


def cmd_full_export(result, info, outfile):
    """Write every entity's combat record to a single JSON file."""
    out = {
        "tool": TOOL,
        "pack": info,
        "version": "1",
        "summary": {
            "entity_count": result["entity_count"],
            "classification_counts": result["classification_counts"],
            "hostile_count": result["hostile_count"],
        },
        "entries": result["records"],
    }
    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {result['entity_count']} entities → {outfile} ({size_kb:.0f} KB)",
          file=sys.stderr)
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
        die("Usage: mob-combat.py <pack> [--mods ...] [--json] [--list] [--info <entity>] [--full-export [file]]")

    pack_dir = resolve_pack_dir(pack)
    info = read_pack_info(pack_dir)

    result = scan_combat(pack_dir, info, pack, want_mods, scan_dp, scan_van)

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) else f"{info.get('name', 'pack')}-mob-combat-full.json"
        cmd_full_export(result, info, outfile)
    elif as_list:
        cmd_list(result)
    elif info_target:
        cmd_info(result, info_target, as_json)
    elif as_json:
        cmd_json(result)
    else:
        # Default: human-readable summary
        print(f"Mob Combat Facts — {info.get('name', 'pack')}")
        print(f"  Entities: {result['entity_count']}")
        print(f"  Hostile encounters: {result['hostile_count']}")
        print(f"  Combat-data classification:")
        for cls in ("full", "passive-only", "custom-only", "no-data"):
            print(f"    {cls}: {result['classification_counts'].get(cls, 0)}")
        print(f"  Timing: scan={result['timing']['scan']:.1f}s  build={result['timing']['build']:.1f}s  total={result['timing']['total']:.1f}s")


if __name__ == "__main__":
    main()

# ## RUN LOG
# ## RUN LOG
# ### 2026-09-13 — --mods silently hollowed out the whole scan
# scan_combat passed --mods to attributes.py, which has NO --mods flag (it reads
# the cached attribute-centric attributes-dump.json, not jars). argparse died,
# _run_scanner swallowed the warning and returned {} -> mob-combat/mob-tier with
# --mods returned zero records with no visible error. Fix: attributes.py runs
# WITHOUT --mods; mobspawn.py gets --mods (now that its own arg-split + resolver
# bugs are fixed); records are filtered post-hoc by entity namespace resolved
# through find_mod_jars + resolve_mod. --mods mowziesmobs now returns rows.

# ### 2026-09-13 (continued)
# mobcontrol/mob-control yield 0 entities even with --mods because Mob Control
# scales VANILLA mobs at runtime — it registers no mobcontrol:* entity types in
# the attributes dump, so a namespace filter correctly returns 0 rows. That is a
# data gap, not a bug: the tool can only tier entities present in the dump.
