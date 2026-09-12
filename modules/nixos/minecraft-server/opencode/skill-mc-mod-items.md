---
name: mc-mod-items
description: Use when asked to review or inventory the items a packwiz modpack in this repo adds — listing every item with its category (tool/weapon/armor/food/block/material/misc/spawn_egg/potion), stack size, the defining mod jar or datapack, vanilla override status, item tags, recipes producing/consuming it, loot tables dropping it, and which items are defined-but-unused or referenced-but-missing. Use packwiz-items / the standalone items.py to scan a pack before deciding whether an item mod is working as intended or needs a config tweak.
---

# Mod Item Review (packwiz)

Inventory and review every **item** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` will include. "Items" here
means all Minecraft items — tools, weapons, armor, food, blocks, materials,
spawn eggs, potions, and any other registry entry — defined via code
(registered in mod jars) or data (recipes, loot tables, item tags, item
modifiers). Sources scanned:

- **Vanilla baseline** — embedded table for the pack's MC version (1.21.1:
  ~200 common items extracted from Mojang's client jar), so vanilla diamonds/
  iron swords/bread are listed as the starting point.
- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too), pack-level `data/` directory (recipes, loot tables, item tags, item
  modifiers), and `defaultconfigs/` (Forge server-side configs).

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what items does the pack
add/change, and are they sound" review step.

## Tools

- **`packwiz-items`** (opencode tool) — the scan in a session. Packs the same
  flags as the CLI: `mods=`, `noDatapacks`, `noVanilla`, `list`, `json`.
  Also accepts `itemInfo` for single-item lookup.
- **`python3 modules/nixos/minecraft-server/opencode/tools/items.py`**
  (standalone CLI — use when outside opencode or when you want the raw
  machine-readable output). Accepts a pack NAME (auto-resolved under the
  repo's modpacks/) or a path. Both hit the same engine; `items.py` is the
  source of truth, `packwiz-items` and `mc-pack.py items` delegate.
- `mc-pack.py <pack> item-info <id> [--json]` — single-item lookup via the same
  engine. Returns source, category, stack size, tags, recipes, loot tables,
  and vanilla override status.

### Flags (CLI and opencode tool)

```
items.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                [--json] [--list]
  --mods          restrict the JAR scan to listed mods (datapacks still scan!)
  --no-datapacks  skip the pack's datapacks (config/paxi/datapacks/ + data/)
  --no-vanilla    omit the embedded vanilla items baseline
  --json          machine-readable: {"pack":…, "sources":[…], "summary":{…}}
  --list          just item ids, one per line (pipe-friendly)
```

```
items.py <pack> --info <id> [--json]
  --info <id>     look up a single item by ID; bare paths (e.g. diamond)
                  default to minecraft: namespace
  --json          output the full lookup result as JSON
```

`--json` schema (stable): `pack` (name/dir/minecraft/loader/version),
`sources[]` each `{kind: vanilla|mod|datapack, name, jar?, items:
{ns:id:{category, stack, tags[], in_recipes[], in_loot_tables[]}}}`, and
`summary` with `total_items`, `jars_downloaded`, `jars_from_cache`,
`skipped_no_url`, `skipped_datapacks`, `per_category`, `by_source`,
`defined_unused`, `referenced_missing`, `vanilla_overrides`.

`--info` result fields: `id`, `source` (kind + name + jar filename),
`category`, `stack` (max stack size), `in_recipes[]` (recipes referencing
this item), `in_loot_tables[]` (loot tables dropping it), `in_tags[]`
(item tags it belongs to), `in_advancements[]` (advancements referencing it),
`override` (true/false), `vanilla_override` (true/false),
`raw` (full parsed data). Unknown IDs get a fuzzy "did you mean" suggestion.

## Reading `packwiz-items` output

```
packwiz-items AllTheTech
─────────────────────────────
## vanilla 1.21.1 baseline (200 items)
  minecraft:diamond          tool/64
  minecraft:iron_ingot       material/64
  …

## mod: ae2-1.21.1-19.29.11.jar
  ae2:certus_quartz          material/64
  ae2:fluix_crystal          material/64
  …

## mod: Create-6.0.4.jar
  create:brass_ingot         material/64
  create:andesite_alloy      material/64
  …

## summary
  total items: 1847
  by category: tool 123, weapon 87, armor 65, food 42, block 890, material 312, misc 298, spawn_egg 30
  vanilla overrides: 12
  defined-but-unused: 23 (items registered but never referenced by recipes/loot/tags)
  referenced-but-missing: 5 (items named in recipes/loot/tags that don't resolve)
```

The per-source breakdown shows which mod jar (or datapack) defines each item.
Category and stack size are shown for each item. The cross-source summary
flags potential issues: vanilla overrides (mods redefining vanilla items),
defined-but-unused (registered but never referenced), and referenced-but-
missing (items named in recipes/loot/tags that can't be found).

## Review workflow

1. **Scan the whole pack** — `packwiz-items P` (or
   `python3 items.py P` outside opencode). For a targeted review, restrict
   to specific mods: `packwiz-items P mods=ae2,still-life` or read the
   datapack lines.

2. **Look up a single item** — `packwiz-items P itemInfo=minecraft:diamond`
   or `mc-pack.py P item-info minecraft:diamond`. Returns category, stack,
   tags, recipes, loot tables, vanilla override status, and raw data.

3. **Cross-reference with structure/mob data** — if a structure mod adds
   loot chest items, `packwiz-structures P` shows which structures reference
   those items, and `packwiz-mobs P` shows which mobs drop them.

4. **Identify issues** — the summary flags:
   - **Vanilla overrides** — mods redefining `minecraft:` items. Useful when
     a mod changes a vanilla item's behavior; may be intentional or a conflict.
   - **Defined-but-unused** — items registered but never referenced by any
     recipe, loot table, or tag. May indicate a broken mod integration or
     an item that needs a recipe added.
   - **Referenced-but-missing** — items named in recipes/loot/tags that don't
     resolve to any registered item. Often a broken mod dependency or a
     datapack targeting an item ID from a different mod version.

## Common tasks

### "What items does mod X add?"
```
packwiz-items AllTheTech mods=create
```

### "Does the pack override any vanilla items?"
Look at the `vanilla overrides` line in the summary, or filter the scan to
only `minecraft:` IDs in the cross-source view.

### "What recipe uses item X?"
```
packwiz-items AllTheTech itemInfo=minecraft:diamond --json
```
The `in_recipes` field lists every recipe referencing the item.

### "What drops item X from a loot table?"
```
packwiz-items AllTheTech itemInfo=minecraft:ender_pearl --json
```
The `in_loot_tables` field lists every loot table dropping the item.

## Full export

Dump every item's full metadata to a single JSON file — one scan pass, one
write, deterministic ID-sorted output. The `entries` map is keyed by item ID;
each value matches the `--info` detail shape (source, category, stack, tags,
recipes, loot tables, override status, raw data).

```
# CLI — defaults to <packname>-items-full.json
python3 tools/items.py AllTheTech --full-export
python3 tools/items.py AllTheTech --full-export /tmp/all-items.json

# Scoped exports
python3 tools/items.py AllTheTech --full-export --mods create,ae2
python3 tools/items.py AllTheTech --full-export --no-vanilla
python3 tools/items.py AllTheTech --full-export --no-datapacks

# Via mc-pack.py
python3 tools/mc-pack.py AllTheTech items-full-export
python3 tools/mc-pack.py AllTheTech items-full-export /tmp/items.json
python3 tools/mc-pack.py AllTheTech items-full-export --mods ae2
```

**Size estimates (AllTheTech):** ~16,500 items → ~8 MB JSON (~2.5s total).

**Output shape:**
```json
{
  "pack": "AllTheTech", "tool": "items.py", "version": "1.0",
  "sources": [{"kind": "mod", "name": "...", "jar": "...", "items": {"ae2:certus_quartz": {...}}}],
  "summary": {"total_items": 16525, ...},
  "entries": {
    "ae2:certus_quartz": {"id": "ae2:certus_quartz", "source": {...}, "category": "material", ...},
    "minecraft:diamond": {"id": "minecraft:diamond", "source": {...}, "category": "material", ...}
  }
}
```

## Tips

- **Always scan the pinned jars.** `packwiz-items` reads `checksums.json`
  so it reviews exactly what players get — not what packwiz lists in
  `index.toml` (which can lag behind after `update --all` without checksums).
- **Jar caching is by checksum.** First scan downloads jars; re-scans are
  instant. Changing mods triggers fresh downloads only for changed jars.
- **Cross-check with mobs/structures.** Items often matter because of what
  uses them — a mob's loot table drops items, a structure's loot chests
  contain them. Use `packwiz-mobs` and `packwiz-structures` together.
- **Vanilla items are always present** unless `--no-vanilla` is passed.
  They're the baseline; the summary shows which mods override them.

## RUN LOG

### 2026-09-07
Created as the item review skill — mirrors `skill-mc-mod-mobs.md` and
`skill-mc-mod-structures.md`. Covers `packwiz-items` / `items.py` for
full-pack item scanning and `itemInfo` / `item-info` for single-item
lookup. Workflow: scan → identify vanilla overrides / defined-unused /
referenced-missing → cross-reference with mob/structure tools → ship fixes.
