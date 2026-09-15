---
name: mc-item-acquisition
description: Use when asked to review how items can be obtained in a packwiz modpack in this repo — showing acquisition paths (crafting, smelting, loot, ore, tags) for each item with full details (ingredients, loot table contexts, ore placements). Use packwiz-item-acquisition / the standalone item-acquisition.py to scan a pack before deciding how to obtain items or what paths are available.
---

# Item Acquisition Review (packwiz)

Cross-reference **items/recipes/loot/ore/mobspawn** to build per-item
acquisition records showing HOW each item can be obtained. No scoring —
pure factual consolidation of acquisition paths.

Sources scanned (via subprocess `--full-export` from each scanner):

- **items.py** — full item list with categories, stack sizes, cross-refs
- **recipes.py** — all recipes with ingredients (crafting, smelting, etc.)
- **loot.py** — all loot tables with drop contexts (mob_drop, structure_chest, fishing, block_drop)
- **ore.py** — ore placements with Y ranges
- **mobspawn.py** — mob spawn entries by biome

## Tools

- **`packwiz-item-acquisition`** (opencode tool) — the scan in a session.
  Accepts `itemInfo` for single-item lookup, `mods=`, `noDatapacks`,
  `noVanilla`, `json`, `fullExport`.
- **`python3 modules/nixos/minecraft-server/opencode/tools/item-acquisition.py`**
  (standalone CLI). Accepts a pack NAME (auto-resolved under the repo's
  modpacks/) or a path.
- `mc-pack.py <pack> item-acquisition [flags]` — same engine via mc-pack.py.
- `mc-pack.py <pack> item-acquisition-info <id> [--json]` — single-item lookup.

### Flags (CLI and opencode tool)

```
item-acquisition.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                           [--json] [--list] [--info <item>]
                           [--full-export [outfile]]
  --mods          restrict the JAR scan to listed mods (datapacks still scan!)
  --no-datapacks  skip the pack's datapacks (config/paxi/datapacks/ + data/)
  --no-vanilla    omit the embedded vanilla baseline
  --json          machine-readable JSON
  --list          print item_id=category pairs
  --info <item>   detailed acquisition info for one item (fuzzy match on miss)
  --full-export   write every item's acquisition record to a single JSON file
```

## Output format

### Default (human-readable)

```
Item: minecraft:diamond
  Category: material
  Source: vanilla 1.21.1 baseline (vanilla)

  Acquisition paths:

    Crafting (1 recipe(s)):
      minecraft:diamond (minecraft:crafting_shapeless)
        Ingredients: (unknown)
        Source: vanilla 1.21.1 baseline
```

### JSON (`--json`)

```json
{
  "id": "createhorsepower:horse_crank",
  "category": "unknown",
  "lang_name": "Horse Crank",
  "source_kind": "mod",
  "source_name": "create horse power",
  "paths": {
    "crafting": [
      {
        "recipe_id": "createhorsepower:horse_crank",
        "recipe_type": "minecraft:crafting_shaped",
        "ingredients": ["create:cogwheel", "minecraft:oak_fence", "minecraft:stone"],
        "source_name": "create horse power"
      }
    ],
    "loot": [
      {
        "table_id": "createhorsepower:blocks/horse_crank",
        "context": "unknown",
        "source_name": "create horse power"
      }
    ]
  }
}
```

## Acquisition path types

| Path | Description |
|------|-------------|
| `crafting` | Recipe with ingredients (crafting table, smithing, etc.) |
| `smelting` | Furnace/blast furnace/smoker recipe |
| `loot` | Loot table drop (context: mob_drop, structure_chest, fishing, block_drop) |
| `ore` | Ore placement in world (with Y range) |
| `tag` | Item appears in tag(s) (informational, not an acquisition method) |

## When to use

- **Before adding a new item mod** — check what acquisition paths items have
- **When balancing loot tables** — see which items drop from which sources
- **When reviewing recipe difficulty** — check ingredient complexity
- **When debugging missing items** — verify items have acquisition paths

## Limitations

- Vanilla recipes show `(unknown)` ingredients (parsed from loot table `items[]` field, not recipe JSON)
- Tag references in recipes (e.g., `#minecraft:planks`) are skipped
- Mob drop cross-referencing not yet implemented (loot tables exist but mob→item linking is partial)

## RUN LOG

### 2026-09-07
- Created skill doc for item-acquisition.py tool.
- Tools: packwiz-item-acquisition (opencode), item-acquisition.py (standalone CLI), mc-pack.py item-acquisition.
- Acquisition paths: crafting, smelting, loot, ore, tag.
- Loot contexts: mob_drop, structure_chest, fishing, block_drop, piglin_barter, gameplay, unknown.
