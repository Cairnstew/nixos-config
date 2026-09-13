---
name: mc-mod-recipes
description: Use when asked to review or inventory the recipes a packwiz modpack in this repo adds — listing every recipe with its type (shaped/shapeless/smelting/blasting/stonecutting/smithing/custom), ingredients, output, the defining mod jar or datapack, vanilla override status, recipe conflicts, and zero-recipe vanilla items. Use packwiz-recipes / the standalone recipes.py to scan a pack before deciding whether a recipe mod is working as intended or needs a config tweak.
---

# Mod Recipe Review (packwiz)

Inventory and review every **recipe** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` will include. Sources scanned:

- **Vanilla baseline** — embedded table for the pack's MC version (1.21.1:
  ~50 common recipes extracted from Mojang's data packs), so vanilla crafting/
  smelting recipes are listed as the starting point.
- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too), pack-level `data/` directory (recipes, loot tables, item tags), and
  `defaultconfigs/` (Forge server-side configs).

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what recipes does the pack
add/change, and are they sound" review step.

## Tools

- **`packwiz-recipes`** (opencode tool) — the scan in a session. Packs the same
  flags as the CLI: `mods=`, `noDatapacks`, `noVanilla`, `list`, `json`.
  Also accepts `recipeInfo` for single-recipe lookup.
- **`python3 modules/nixos/minecraft-server/opencode/tools/recipes.py`**
  (standalone CLI — use when outside opencode or when you want the raw
  machine-readable output). Accepts a pack NAME (auto-resolved under the
  repo's modpacks/) or a path. Both hit the same engine; `recipes.py` is the
  source of truth, `packwiz-recipes` and `mc-pack.py recipes` delegate.
- `mc-pack.py <pack> recipe-info <id> [--json]` — single-recipe lookup via the same
  engine. Returns type, ingredients, output, source, override status, raw JSON.

### Flags (CLI and opencode tool)

```
recipes.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                  [--json] [--list]
  --mods          restrict the JAR scan to listed mods (datapacks still scan!)
  --no-datapacks  skip the pack's datapacks (config/paxi/datapacks/ + data/)
  --no-vanilla    omit the embedded vanilla recipes baseline
  --json          machine-readable: {"pack":…, "sources":[…], "summary":{…}}
  --list          just recipe ids, one per line (pipe-friendly)
```

```
recipes.py <pack> --info <id> [--json]
  --info <id>     look up a single recipe by ID; bare paths (e.g. crafting_table)
                  default to minecraft: namespace
  --json          output the full lookup result as JSON
```

`--json` schema (stable): `pack` (name/dir/minecraft/loader/version),
`sources[]` each `{kind: vanilla|mod|datapack, name, jar?, recipes:
{ns:id:{type, items, data}}}`, and `summary` with `total_recipes`,
`jars_downloaded`, `jars_from_cache`, `skipped_no_url`, `skipped_datapacks`,
`by_mod`, `by_type`, `vanilla_overrides`, `unresolved_outputs`,
`recipe_conflicts`, `zero_recipe_vanilla_items`.

`--info` result fields: `id`, `type` (shaped/shapeless/smelting/etc.),
`ingredients` (list of ingredient specs), `output` (item + count),
`source` (kind + name + jar filename), `vanilla_override` (true/false),
`raw` (full parsed JSON). Unknown IDs get a fuzzy "did you mean" suggestion.

## Reading `packwiz-recipes` output

```
packwiz-recipes AllTheTech
─────────────────────────────
## vanilla 1.21.1 baseline (~50 recipes)
  minecraft:crafting_table       shaped  4x oak_planks → crafting_table
  minecraft:chest                shaped  8x oak_planks → chest
  minecraft:diamond_pickaxe      shaped  3x diamond + 2x stick → diamond_pickaxe
  …

## mod: ae2-1.21.1-19.29.11.jar
  ae2:inscriber                  shaped  4x iron + 1x redstone → inscriber
  ae2:charger                    shaped  4x iron + 1x redstone → charger
  …

## mod: Create-6.0.4.jar
  create:andesite_alloy          shaped  1x andesite + 1x iron → andesite_alloy
  create:brass_ingot             smelting  zinc_ore → brass_ingot
  …

## summary
  total recipes: 1247
  by type: shaped 654, shapeless 123, smelting 234, blasting 87, stonecutting 45, smithing 23, custom 81
  by mod (top 10): ae2 145, create 134, thermal 98, mekanism 87, …
  vanilla overrides: 8
  recipe conflicts: 3 (multiple recipes producing the same output)
  zero-recipe vanilla items: 12 (vanilla items with no recipe in the pack)
  unresolved outputs: 2 (recipes producing items not in the item registry)
```

The per-source breakdown shows which mod jar (or datapack) defines each recipe.
The cross-source summary flags potential issues: vanilla overrides (mods
redefining vanilla recipes), recipe conflicts, zero-recipe vanilla items, and
unresolved outputs.

## Review workflow

1. **Scan the whole pack** — `packwiz-recipes P` (or
   `python3 recipes.py P` outside opencode). For a targeted review, restrict
   to specific mods: `packwiz-recipes P mods=ae2,still-life` or read the
   datapack lines.

2. **Look up a single recipe** — `packwiz-recipes P recipeInfo=minecraft:crafting_table`
   or `mc-pack.py P recipe-info minecraft:crafting_table`. Returns type,
   ingredients, output, source, override status, and raw JSON.

3. **Cross-reference with item data** — if a recipe outputs an item,
   `packwiz-items P itemInfo=<id>` shows which items are defined-but-unused
   or referenced-but-missing.

4. **Identify issues** — the summary flags:
   - **Vanilla overrides** — mods redefining `minecraft:` recipes. Useful when
     a mod changes a vanilla crafting recipe; may be intentional or a conflict.
   - **Recipe conflicts** — multiple recipes producing the same output. Only one
     will be used (the last loaded wins). May indicate a mod conflict.
   - **Zero-recipe vanilla items** — vanilla items with no recipe in the pack.
     May be intentional (creative-only items) or indicate a missing recipe.
   - **Unresolved outputs** — recipes producing items not in the item registry.
     Often a broken mod dependency or a datapack targeting an item ID from a
     different mod version.

## Common tasks

### "What recipes does mod X add?"
```
packwiz-recipes AllTheTech mods=create
```

### "Does the pack override any vanilla recipes?"
Look at the `vanilla overrides` line in the summary, or filter the scan to
only `minecraft:` IDs in the cross-source view.

### "What recipe produces item X?"
```
packwiz-recipes AllTheTech recipeInfo=minecraft:diamond_pickaxe --json
```
The `ingredients` and `output` fields show the full recipe.

### "Are there recipe conflicts?"
Check the `recipe conflicts` line in the summary. Each conflict shows the
output item and how many recipes produce it.

## Full export

Dump every recipe's full metadata to a single JSON file — one scan pass, one
write, deterministic ID-sorted output. The `entries` map is keyed by recipe ID;
each value matches the `--info` detail shape (type, ingredients, output, source,
override status, raw JSON).

```
# CLI — defaults to <packname>-recipes-full.json
python3 tools/recipes.py AllTheTech --full-export
python3 tools/recipes.py AllTheTech --full-export /tmp/all-recipes.json

# Scoped exports
python3 tools/recipes.py AllTheTech --full-export --mods create,ae2
python3 tools/recipes.py AllTheTech --full-export --no-vanilla

# Via mc-pack.py
python3 tools/mc-pack.py AllTheTech recipes-full-export
python3 tools/mc-pack.py AllTheTech recipes-full-export /tmp/recipes.json
```

**Size estimates (AllTheTech):** ~85 recipes → ~92 KB JSON (~1.3s total).

**Output shape:**
```json
{
  "pack": "AllTheTech", "tool": "recipes.py", "version": "1.0",
  "sources": [{"kind": "mod", "name": "...", "jar": "...", "recipes": {"ae2:inscriber": {...}}}],
  "summary": {"total_recipes": 85, ...},
  "entries": {
    "ae2:inscriber": {"id": "ae2:inscriber", "type": "shaped", "ingredients": [...], "output": {...}, ...},
    "minecraft:crafting_table": {"id": "minecraft:crafting_table", "type": "shaped", ...}
  }
}
```

## Tips

- **Always scan the pinned jars.** `packwiz-recipes` reads `checksums.json`
  so it reviews exactly what players get — not what packwiz lists in
  `index.toml` (which can lag behind after `update --all` without checksums).
- **Jar caching is by checksum.** First scan downloads jars; re-scans are
  instant. Changing mods triggers fresh downloads only for changed jars.
- **Cross-check with items.** Recipes and items are two sides of the same
  coin. A recipe's output is an item; an item may have recipes. Use
  `packwiz-items` to check item registry completeness.
- **Vanilla recipes are always present** unless `--no-vanilla` is passed.
  They're the baseline; the summary shows which mods override them.

## RUN LOG

### 2026-09-07
Created as the recipe review skill — mirrors `skill-mc-mod-items.md` and
`skill-mc-mod-structures.md`. Covers `packwiz-recipes` / `recipes.py` for
full-pack recipe scanning and `recipeInfo` / `recipe-info` for single-recipe
lookup. Workflow: scan → identify vanilla overrides / recipe conflicts /
unresolved outputs → cross-reference with item tools → ship fixes.
