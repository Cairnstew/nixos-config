---
name: mc-mod-mobspawn
description: Use when asked to review or inventory the mob spawn entries a packwiz modpack in this repo adds — listing every biome's spawner categories (monster, creature, ambient, etc.) with effective weights and group sizes, tracking contested placements (same biome file defined by multiple sources), and flagging vanilla spawns removed. Use packwiz-mobspawn to scan a pack before deciding whether a mob mod/datapack is worth keeping or needs a config tweak.
---

# Mod Mob Spawn Review (packwiz)

Inventory and review every **mob spawn entry** across all biomes a packwiz
modpack under `modules/nixos/minecraft-server/modpacks/<name>/` will generate.
"Mob spawns" here means the `spawners` section of `worldgen/biome` files —
each biome's lists of `monster`, `creature`, `ambient`, `water_creature`,
`water_ambient`, `underground_water_creature`, and `axolotls` categories,
with their `type`, `weight`, `minCount`, and `maxCount`. Sources scanned:

- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too) and any pack-level `data/` directory.
- **Vanilla baseline** — the vanilla 1.21 biome files extracted from the
  client jar, so vanilla spawns are always visible and can be compared against
  mod-added ones.

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what mob spawns does the pack
add, and are they sound" review step.

## Tools

- `packwiz-mobspawn <pack> [mods=slug1,slug2] [noDatapacks] [noVanilla]` — **the scan.**
  Reports per-source (per mod, per datapack) every biome's spawn entries, then a
  cross-source summary:
  - total biomes with spawn data
  - total spawn entries
  - contested biome files (same biome defined by multiple sources)
  - vanilla biomes overridden
  - `--mods` restricts the jar scan to specific mods; `--no-datapacks` skips
    the datapack scan; `--no-vanilla` omits the vanilla baseline.
- `packwiz-mobspawn <pack> info=<biome-id>` — show spawn details for one biome
  (e.g. `minecraft:plains`): all categories, mob types, weights, group sizes,
  resolution source, contested status.
- `packwiz-mobspawn <pack> list` — list all biome IDs with spawn data.
- `packwiz-mobspawn <pack> fullExport [path]` — full JSON dump of every biome's
  spawn data to a file (or stdout if no path).
- `packwiz-config-show <pack> <mod>` / `packwiz-config-diff` — when a mob
  mod has a config to disable/tune its spawns (the `mc-mod-config` skill
  covers this workflow).

## Reading `packwiz-mobspawn` output

```
  ## mod: ice and fire (iceandfire-2.1.13-1.21.1.jar)
    biome  iceandfire:ice_dragon_cave  (monster=1, creature=0, ambient=0)
    biome  iceandfire:fire_dragon_cave (monster=1, creature=0, ambient=0)
  ## vanilla 1.21.1 baseline
    biome  minecraft:plains  (monster=8, creature=6, ambient=1)

## summary (337 jars cached)
  biomes:          196
  spawn entries:   2544
  contested files: 134
  vanilla overrides: 0
```

- `biome <id> (monster=N, creature=M, ambient=O)` — one biome with spawn data.
  The numbers are total entries per category. Each entry has:
  - `type` — the mob entity ID (e.g. `minecraft:zombie`)
  - `weight` — spawn weight relative to other entries in the category
  - `minCount` / `maxCount` — group size range
- `[CONTESTED]` on a biome means the same `worldgen/biome/<id>.json` file is
  defined by multiple sources (vanilla + mod, or mod + datapack). The tool
  reports all definitions side-by-side and flags the resolution source.
- `[VANILLA OVERRIDDEN]` on a biome means the pack redefines a vanilla biome's
  spawn list. This is normal for biome mods but should be intentional.
- Summary notes: contested files and vanilla overrides are the things to
  actually act on. Everything else is an inventory.
- Full-pack runs download each jar once (cached in
  `$TMPDIR/mc-pack-jars/` by checksum); only the first run for a checksum
  downloads, reported as `N jars downloaded`.

## Workflow: review the mob spawns the pack adds

1. **Scan the whole pack** — `packwiz-mobspawn P`.
2. **If a specific mod/datapack is the subject**, restrict:
   `packwiz-mobspawn P mods=iceandfire,betternether` or read the datapack lines.
3. **Act on the cross-source summary:**
   - *Contested files* — same biome defined by multiple sources. This is
     normal when a mod overrides a vanilla biome (e.g. biome mods). Verify
     the override is intentional. If a datapack override is accidental,
     `packwiz-datapack-remove`.
   - *Vanilla overrides* — the pack redefines vanilla biome spawns. For each,
     note the overriding source (mod vs datapack) and whether that's intended
     (many mods intentionally replace e.g. `minecraft:plains` spawns).
   - *Weight changes* — if a mob spawns too much or too little, check the
     mod's config (see `mc-mod-config`) or a custom datapack tweak.
4. **Tune rather than remove** — if a mob mod's spawns are too aggressive,
   prefer its config (see `mc-mod-config`) or a custom datapack tweak over
   dropping the mod. The modpack owner wants mods kept (see `mc-modpack`
   gotchas).
5. **Report** consistently:
   - "mob mod X adds Y spawn entries across Z biomes"
   - "biome Y has contested spawn list — mod overrides vanilla, confirmed
     intended" or "biome Y contested — needs review"
   - "mob X weight 99 in biome Z — may dominate spawns"

## Contested placement detection

The tool flags **contested biome files** when the same `worldgen/biome/<id>.json`
file is defined by multiple sources (vanilla baseline + mod jar, or mod jar +
datapack). This is the critical feature for modpack authors — it answers "which
source actually defines this biome's spawns at runtime?"

Each source in the contested list includes a `source_type` field:
- `"mod"` — from a mod jar (pinned in checksums.json)
- `"datapack"` — from a pack datapack (config/paxi/datapacks/ or data/)
- `"vanilla"` — from the embedded vanilla baseline

This lets you distinguish **mod-vs-mod conflicts** (two mods overriding the
same biome) from **mod-vs-datapack conflicts** (a manual patch overriding a
mod's biome). In AllTheTech, the 2 contested biomes are vanilla-vs-mod
(still life overriding dripstone_caves and lush_caves).

Resolution follows Minecraft's load-order rules:
1. **Mod jars** are loaded in dependency order (later mods win).
2. **Datapacks** load after mods (later datapacks win).
3. **Vanilla baseline** is always overridden by any mod/datapack definition.

The tool reports all definitions side-by-side and flags which one wins. Never
assume vanilla is "the real one" — if a mod overrides `minecraft:plains`, the
mod's spawn list is what players get.

## Gotchas

- **Biome modifications are additive** — `worldgen/biome_modifier` files
  (used by some mods) add entries to existing biomes rather than replacing
  them. These are not contested — they merge with the biome's existing spawns.
- **Some mobs handle spawns in code** — modded mobs (e.g. Mekanism's
  entertainment robots) may register their spawns via Java, not JSON biome
  files. The scan won't see these. Check the mod's documentation.
- **Weight 99 means dominant** — a mob with weight 99 in a category will
  spawn far more often than others. This is usually intentional for mod
  showcase mobs but may be worth tuning.
- **Vanilla spawns are always present** — unless you pass `--no-vanilla`, the
  vanilla baseline is included so you can see what mod spawns replace or
  supplement.
- **Vanilla baseline uses client.jar** — the vanilla 1.21 biome data is
  extracted from the client jar, not the server jar (the server jar lacks
  worldgen data). This is a one-time download cached for future runs.
