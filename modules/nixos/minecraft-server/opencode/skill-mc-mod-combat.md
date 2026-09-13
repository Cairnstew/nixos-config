---
name: mc-mod-combat
description: Use when asked to review the raw combat facts or combat capabilities of mobs in a packwiz modpack in this repo — the standard combat attributes (health, attack damage, armor, speed), any custom mod combat attributes (epicfight etc.), spawn data, and whether a mob is a hostile combat encounter vs a passive. Use packwiz-mob-combat / the standalone mob-combat.py to inspect the facts before deciding mob difficulty, loot drops, or encounter balance. Pairs with the mc-mod-tier skill (the scoring step).
---

# Mob Combat Facts Review (packwiz)

Consolidate the **raw combat-relevant facts** for every entity in a pack — a
fact-gathering step with **no scoring opinion**. Scoring lives in `mc-mod-tier`.

Data sources (both deterministic, cached in the repo):
- **attributes.py** — the entity attribute dump (per-entity `minecraft:generic.*`
  values + every custom mod attribute), with correct vanilla / vanilla_modified /
  modded source classification.
- **mobspawn.py** — per-biome spawn weight / category / dimension data.

## What is recorded per entity

| Field | Meaning |
|-------|---------|
| `standard` | the 7 standard combat attributes: `max_health`, `attack_damage`, `armor`, `armor_toughness`, `movement_speed`, `knockback_resistance`, `follow_range` |
| `custom_attributes` | every non-standard attribute, **tagged by namespace** (e.g. `epicfight:impact`). Never folded into a score — each mod's semantics are unknown |
| `has_custom_combat` | whether it carries non-default attributes from a combat-overhaul mod (epicfight, bettercombat, apothic_attributes) |
| spawn facts | spawn weight (`weight_min`/`weight_max`), biome count, inferred `dimensions`, spawn `categories` |
| `combat_data` | data-completeness: `full` / `passive-only` / `custom-only` / `no-data` |
| `hostile` + `hostility_source` | whether it is a combat encounter, and WHY (spawn category / vanilla friendly metadata / combat-stat signal) |

### Combat-data classification

- **full** — has standard combat attributes (attack_damage + max_health).
- **passive-only** — has health/movement but **no** attack_damage — genuinely
  non-hostile, NOT a data gap.
- **custom-only** — combat driven primarily by custom attributes this tool can't
  interpret (e.g. an epicfight mob whose real difficulty isn't captured by
  vanilla attack_damage). Scored as **confidence partial** downstream.
- **no-data** — no attribute entry at all. Flagged explicitly, never guessed.

### Hostility (separate signal from data completeness)

A cow has *full* attributes but is *not* a combat encounter. The `hostile` field
uses, in order of authority: spawn category (monster → hostile), vanilla friendly
metadata for vanilla entities, then a strong combat-stat signal for no-spawn
modded entities (boss summons). The basis is always recorded in
`hostility_source` so an aggressive mob vs a neutral-but-statsy one are
distinguishable.

## Tools

- **`packwiz-mob-combat`** (opencode tool) — the scan in a session. Accepts
  `entityInfo`, `mods=`, `noDatapacks`, `noVanilla`, `list`, `json`, `fullExport`.
- **`python3 modules/nixos/minecraft-server/opencode/tools/mob-combat.py`**
  (standalone CLI). Accepts a pack NAME (auto-resolved under the repo's
  modpacks/) or a path.
- `mc-pack.py <pack> mob-combat [flags]` — same engine via mc-pack.py.
- `mc-pack.py <pack> mob-combat-info <id> [--json]` — single-entity lookup.

### Flags

```
mob-combat.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                     [--json] [--list] [--info <entity>] [--full-export [file]]
  --mods          restrict the scan to listed mods
  --no-datapacks  skip the pack's datapacks
  --no-vanilla    omit the vanilla baseline
  --json          machine-readable JSON
  --list          entity ids, one per line
  --info <entity> detailed combat facts for one entity (fuzzy match)
  --full-export   write every entity's combat facts to a single JSON file
```

## Example (`--info minecraft:zombie`)

```
Entity: minecraft:zombie
  Source: vanilla_modified  (mod: minecraft)
  Combat data: full
  Hostile encounter: yes
  Hostility basis: spawn category
  Standard combat attributes:
    max_health: 20.0
    attack_damage: 3.0
    armor: 2.0
    ...
  Custom combat attributes present (confidence: partial):
    [epicfight] ['epicfight:armor_negation', 'epicfight:impact', ...]
  Spawn: categories=['monster'] weight 10-100 biomes=154 dimensions=['overworld']
```

## When to use

- Before mob tiering (`mc-mod-tier`) — get the underlying facts first.
- When diagnosing why a mob is hard/easy — which stat actually carries it.
- When a combat-overhaul mod (epicfight) is suspected of under-representing a
  mob's real difficulty — check `has_custom_combat` / `custom_attributes`.
- When deciding whether a mob spawns naturally at all (bosses/summons show
  `spawns_naturally: false`).

## Limitations

- Attribute values are the *base registry* values — apply-time modifiers (enchants,
  potions, biome/hard difficulty bonuses) are not represented.
- No-spawn modded entities (bosses, summons, minecolonies raiders) are genuinely
  ambiguous; only strong signals mark them hostile. A modded boss whose base
  registry entry underreports (e.g. iceandfire dragons read as young-stage) is
  flagged NOT reliably representable rather than guessed.
