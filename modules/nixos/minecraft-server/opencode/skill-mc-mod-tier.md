---
name: mc-mod-tier
description: Use when asked to review or assign combat-difficulty tiers to mobs in a packwiz modpack in this repo — deterministic 0-7 combat scores (7=hardest) based on a mob's combat attributes and its encounter context. Use packwiz-mob-tier / the standalone mob-tier.py to scan a pack before deciding combat balance, boss difficulty, progression gating, or spawning tweaks. Pairs with the mc-mod-combat skill (the fact-gathering step); this is the scoring step.
---

# Mob Tier Review (packwiz)

Compute deterministic **0-7 combat-difficulty tiers** (7 = hardest) for every
mob in a pack, from the consolidated facts in `mob-combat.py`. Same philosophy
as the item-tier system: **weighted geometric mean** so one outlier stat doesn't
dominate, and **no guessing** — entities that can't be scored get `tier: null`
with an explicit reason.

## Three scores (all reported — know which one you're reading)

| Score | Meaning |
|-------|---------|
| `combat_tier` (0-7) | the mob's **own stats alone** — effective health (health + armor/armor_toughness as damage reduction), attack damage, with movement speed and knockback resistance as small secondary multipliers. Ref'd to a fixed zombie-like baseline (tier 3), so tiers are absolute across packs. |
| `context_score` (0-7) | **encounter context** — how hard it is to actually face: dimension difficulty + spawn rarity. A mob that's strong AND rare/dimension-gated tiers higher than an equally strong mob that spawns everywhere in the overworld. |
| `combined_tier` (0-7) | combat × context — the headline number. |
| `confidence` | `full` (scored on trustworthy vanilla stats) or `partial` (custom combat attrs present, or a boss). |

## Explicit handling rules

- **Passive mobs** (cow, chicken, villager…) are **never scored** — `combat_tier` /
  `combined_tier` = n/a, `mob_class = passive`. A cow is not "combat tier 0",
  it is "not a combat encounter at all", listed in a separate passives bucket.
- **Bosses / phase-based mobs** (ender_dragon, wither, modded bosses) carry a
  **stats-only note**: the tier reflects base attributes only and *underrepresents*
  real difficulty. No fake "boss bonus" is ever added.
- **custom-only / no-data** entities (epicfight-driven combat, no attribute
  entry) get `tier: null` with an explicit reason and `confidence: partial` —
  never a guessed fallback.
- **Dimension gating**: only a mob found *solely* in the nether/end is
  dimension-gated; if it also spawns in the overworld the easiest present
  dimension governs (that's where you actually meet it).

## Dimension-difficulty weighting

```
overworld = 1.0   baseline
nether    = 1.6
end       = 2.2
```

## Tools

- **`packwiz-mob-tier`** (opencode tool) — the scan in a session. Accepts
  `mobInfo`, `mods=`, `noDatapacks`, `noVanilla`, `list`, `json`, `fullExport`.
- **`python3 modules/nixos/minecraft-server/opencode/tools/mob-tier.py`**
  (standalone CLI). Accepts a pack NAME or a path.
- `mc-pack.py <pack> mob-tier [flags]` — same engine via mc-pack.py.
- `mc-pack.py <pack> mob-tier-info <id> [--json]` — single-mob lookup.

### Flags

```
mob-tier.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                   [--json] [--list] [--info <entity>] [--full-export [file]]
  --mods          restrict the scan to listed mods
  --no-datapacks  skip the pack's datapacks
  --no-vanilla    omit the vanilla baseline
  --json          machine-readable JSON
  --list          entity_id=tier pairs, one per line
  --info <entity> detailed tier info for one mob (fuzzy match)
  --full-export   write every mob's tier record to a single JSON file
```

## Example (`--info minecraft:zombie`)

```
Mob: minecraft:zombie
  Class: hostile   Source: vanilla_modified
  combat_tier:   3   (stats alone; raw score 3.264)
  context_score: 3.202   (dimension + rarity)
  combined_tier: 4   (combat × context)
  Confidence: partial
  Reason: custom combat attributes present — tier scored on vanilla stats only (confidence partial)
  Encounter: dimensions=['overworld'] spawn_weight=10 (dim_mult=1.0 rarity=1.15)
  Factors: effective_health=21.7 dmg_reduction=0.08 attack_damage=3.0 speed=0.23 kb=0.0
```

A boss always carries the explicit caveat:
```
  ⚠ BOSS — computed tier reflects base stats only and underrepresents real difficulty.
```

## When to use

- **When balancing combat** — verify boss difficulty is plausible (and remember
  boss tiers are floors, not ceilings).
- **When designing progression** — check tier distribution across hostile mobs.
- **When a combat-overhaul mod is installed** — expect `confidence: partial` on
  epicfight-affected mobs; don't trust the number as precise.
- **When adding a new mod's mobs** — see how they compare to what exists.

## Limitations

- **Boss tiers underrepresent** by design — they're base-stats-only with a loud
  note, never inflated.
- **Attribute values are base registry values** — apply-time modifiers are not
  represented.
- **custom-only mobs** (epicfight) are deliberately not scored on vanilla stats
  alone — expect null tiers / partial confidence, which is honest, not a gap.
- **No-spawn modded entities** whose base entry underreports (e.g. iceandfire
  dragons read as young-stage) will tier low despite being hard bosses — the
  boss flag + stats-only note apply.
