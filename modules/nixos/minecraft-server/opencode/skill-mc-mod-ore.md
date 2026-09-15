---
name: mc-mod-ore
description: Use when asked to review or inventory the ore features a packwiz modpack in this repo adds — listing every ore with its Y-range, vein size, biomes, and dimension, tracking contested placements (same ore defined by multiple sources), and flagging ores with no known item drop. Use packwiz-ore to scan a pack before deciding whether an ore mod/datapack is worth keeping or needs a config tweak.
---

# Mod Ore Review (packwiz)

Inventory and review every **ore feature** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` will generate. "Ores" here
means Minecraft worldgen ore features — `worldgen/configured_feature` and
`worldgen/placed_feature` files that define ore blocks, vein sizes, Y-ranges,
and biome placement. Sources scanned:

- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too) and any pack-level `data/` directory.
- **Vanilla baseline** — embedded ore data for the pack's Minecraft version
  (currently 1.21), so vanilla ores are always visible and can be compared
  against mod-added ones.

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what ores does the pack
add, and are they sound" review step.

## Tools

- `packwiz-ore <pack> [mods=slug1,slug2] [noDatapacks] [noVanilla]` — **the scan.**
  Reports per-source (per mod, per datapack) every ore feature it ships, then a
  cross-source summary:
  - total configured features / total placed features
  - contested placements (same ore defined by multiple sources)
  - ores with no known item drop (missing loot table)
  - vanilla ores removed (if --no-vanilla)
  - `--mods` restricts the jar scan to specific mods; `--no-datapacks` skips
    the datapack scan; `--no-vanilla` omits the vanilla baseline.
- `packwiz-ore <pack> info=<ore-id>` — show details for one ore (e.g.
  `minecraft:ore_diamond`): block, vein size, Y-range, biomes, dimension,
  resolution source, contested status.
- `packwiz-ore <pack> list` — list all ore IDs with a one-line summary.
- `packwiz-ore <pack> fullExport [path]` — full JSON dump of every ore's
  metadata to a file (or stdout if no path).
- `packwiz-config-show <pack> <mod>` / `packwiz-config-diff` — when an ore
  mod has a config to disable/tune its ores (the `mc-mod-config` skill
  covers this workflow).

## Reading `packwiz-ore` output

```
  ## mod: mekanism (mekanism-1.21.1-10.7.12.242.jar)
    configured  mekanism:ore_osmium  (block=mekanism:osmium_ore, vein=?)
    placed      mekanism:ore_osmium_middle  (Y=dynamic, count=uniform(0-0))
  ## vanilla 1.21.1 baseline
    configured  minecraft:ore_diamond  (block=minecraft:diamond_ore, vein=7)
    placed      minecraft:ore_diamond  (Y=-64..16, count=8)

## summary (337 jars cached)
  configured features:  110
  placed features:      108
  contested placements: 9
  missing drops:        42
```

- `configured <id> (block=…, vein=…)` — one ore configured feature: what block
  it places and the vein size. `vein=?` means the vein size is runtime-
  configurable (e.g. Mekanism).
- `placed <id> (Y=min..max, count=N)` — one ore placed feature: the Y-range,
  spawn count per chunk, and biome filter. `Y=dynamic` means the height range
  is set by config, not hardcoded.
- `[CONTESTED]` on a placed feature means the same ore file is defined by
  multiple sources (vanilla + mod, or mod + datapack). The tool reports all
  definitions side-by-side and flags the resolution source.
- `[MISSING DROP]` on a configured feature means the ore block has no loot
  table mapping (the block doesn't drop an item when mined). This is common
  for vanilla ores (the tool can't yet resolve all loot tables) but should be
  checked for mod ores.
- Summary notes: contested placements and missing drops are the things to
  actually act on. Everything else is an inventory.
- Full-pack runs download each jar once (cached in
  `$TMPDIR/mc-pack-jars/` by checksum); only the first run for a checksum
  downloads, reported as `N jars downloaded`.

## Workflow: review the ores the pack adds

1. **Scan the whole pack** — `packwiz-ore P`.
2. **If a specific mod/datapack is the subject**, restrict:
   `packwiz-ore P mods=mekanism,create` or read the datapack lines.
3. **Act on the cross-source summary:**
   - *Contested placements* — same ore defined by multiple sources. This is
     normal when a mod overrides a vanilla ore (e.g. Amplified Nether overrides
     nether ores). Verify the override is intentional. If a datapack override
     is accidental, `packwiz-datapack-remove`.
   - *Missing drops* — the ore block has no loot table. For mod ores, this
     may mean the mod handles drops in code (common for modded ores). For
     vanilla ores, the tool can't yet resolve all loot tables — ignore unless
     you're writing a datapack.
   - *Y-range/vein size* — if an ore spawns too high/low or too large/small,
     check the mod's config (see `mc-mod-config`).
4. **Tune rather than remove** — if an ore mod spawns too much or too
   little, prefer its config (see `mc-mod-config`) or a custom datapack tweak
   over dropping the mod. The modpack owner wants mods kept (see `mc-modpack`
   gotchas).
5. **Report** consistently:
   - "ore mod X adds Y ores with Z contested placements"
   - "ore X has no item drop — confirmed mod handles drops in code" or
     "ore X has no item drop — needs loot table datapack"
   - "ore X Y-range overridden by datapack — intended?"

## Contested placement detection

The tool flags **contested placements** when the same `worldgen/placed_feature`
or `worldgen/configured_feature` file is defined by multiple sources (vanilla
baseline + mod jar, or mod jar + datapack). This is the critical feature for
modpack authors — it answers "which source actually defines this ore at
runtime?"

Each source in the contested list includes a `source_type` field:
- `"mod"` — from a mod jar (pinned in checksums.json)
- `"datapack"` — from a pack datapack (config/paxi/datapacks/ or data/)
- `"vanilla"` — from the embedded vanilla baseline

This lets you distinguish **mod-vs-mod conflicts** (two mods overriding the
same vanilla ore) from **mod-vs-datapack conflicts** (a manual patch overriding
a mod's ore). In AllTheTech, all 9 contested placements are vanilla-vs-mod
(amplified nether overriding vanilla nether ores).

Resolution follows Minecraft's load-order rules:
1. **Mod jars** are loaded in dependency order (later mods win).
2. **Datapacks** load after mods (later datapacks win).
3. **Vanilla baseline** is always overridden by any mod/datapack definition.

The tool reports all definitions side-by-side and flags which one wins. Never
assume vanilla is "the real one" — if a mod overrides `minecraft:ore_diamond`,
the mod's definition is what players get.

## Gotchas

- **Mekanism ores use configurable height ranges** — `Y=dynamic` means the
  height range is set by the mod's config at runtime, not hardcoded in the
  placed feature JSON. Check Mekanism's config for the actual range.
- **Some ores have no item drop** — modded ores often handle drops in Java
  code (e.g. Mekanism's ore processing chain). The `missing drops` list is
  informational, not necessarily a bug.
- **Ore names can be misleading** — `minecraft:ore_diamond` is a placed
  feature, not a configured feature. The tool resolves the feature reference
  to show the actual block and vein size.
- **Vanilla ores are always present** — unless you pass `--no-vanilla`, the
  vanilla baseline is included so you can see what mod ores replace or
  supplement.
