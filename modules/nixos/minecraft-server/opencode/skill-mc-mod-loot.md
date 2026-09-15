---
name: mc-mod-loot
description: Use when asked to review or inventory the loot tables a packwiz modpack in this repo adds — listing every loot table with its type (block/entity/chest/gameplay), pools, entries, items, conditions, the defining mod jar or datapack, vanilla override status, empty/produce-nothing tables, and unresolved items. Use packwiz-loot / the standalone loot.py to scan a pack before deciding whether a loot mod is working as intended or needs a config tweak.
---

# Mod Loot Table Review (packwiz)

Inventory and review every **loot table** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` will include. Sources scanned:

- **Vanilla baseline** — embedded table for the pack's MC version (1.21.1:
  ~30 common loot tables extracted from Mojang's data packs), so vanilla block
  drops/entity loot/chest loot are listed as the starting point.
- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too), pack-level `data/` directory (loot tables, recipes, item tags), and
  `defaultconfigs/` (Forge server-side configs).

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what loot tables does the pack
add/change, and are they sound" review step.

## Tools

- **`packwiz-loot`** (opencode tool) — the scan in a session. Packs the same
  flags as the CLI: `mods=`, `noDatapacks`, `noVanilla`, `list`, `json`.
  Also accepts `lootInfo` for single-loot-table lookup.
- **`python3 modules/nixos/minecraft-server/opencode/tools/loot.py`**
  (standalone CLI — use when outside opencode or when you want the raw
  machine-readable output). Accepts a pack NAME (auto-resolved under the
  repo's modpacks/) or a path. Both hit the same engine; `loot.py` is the
  source of truth, `packwiz-loot` and `mc-pack.py loot` delegate.
- `mc-pack.py <pack> loot-info <id> [--json]` — single-loot-table lookup via
  the same engine. Returns type, pools, entries, items, conditions, source,
  override status, raw JSON.

### Flags (CLI and opencode tool)

```
loot.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
               [--json] [--list]
  --mods          restrict the JAR scan to listed mods (datapacks still scan!)
  --no-datapacks  skip the pack's datapacks (config/paxi/datapacks/ + data/)
  --no-vanilla    omit the embedded vanilla loot tables baseline
  --json          machine-readable: {"pack":…, "sources":[…], "summary":{…}}
  --list          just loot table ids, one per line (pipe-friendly)
```

```
loot.py <pack> --info <id> [--json]
  --info <id>     look up a single loot table by ID; bare paths
                  (e.g. blocks/diamond_ore) default to minecraft: namespace
  --json          output the full lookup result as JSON
```

`--json` schema (stable): `pack` (name/dir/minecraft/loader/version),
`sources[]` each `{kind: vanilla|mod|datapack, name, jar?, loot_tables:
{ns:id:{type, pools, items, vanilla_override}}}`, and `summary` with
`total_tables`, `jars_downloaded`, `jars_from_cache`, `skipped_no_url`,
`skipped_datapacks`, `by_mod`, `by_type`, `vanilla_overrides`,
`unresolved_items`, `empty_tables`.

`--info` result fields: `id`, `type` (block/entity/chest/gameplay/etc.),
`pools[]` (each with `rolls`, `entries[]`, `conditions[]`), `items` (resolved
item references), `source` (kind + name + jar filename), `vanilla_override`
(true/false), `raw` (full parsed JSON). Unknown IDs get a fuzzy "did you mean"
suggestion.

## Reading `packwiz-loot` output

```
packwiz-loot AllTheTech
────────────────────────────
## vanilla 1.21.1 baseline (~30 loot tables)
  minecraft:blocks/diamond_ore     block    pools:1  items:minecraft:diamond
  minecraft:entities/zombie        entity   pools:2  items:minecraft:rotten_flesh
  minecraft:chests/simple_dungeon  chest    pools:3  items:minecraft:diamond,minecraft:iron_ingot
  …

## mod: ae2-1.21.1-19.29.11.jar
  ae2:blocks/certus_ore            block    pools:1  items:ae2:certus_quartz
  ae2:entities/skulk_spatial      entity   pools:1  items:ae2:charged_certus_quartz
  …

## mod: Create-6.0.4.jar
  create:blocks/zinc_ore           block    pools:1  items:create:raw_zinc
  create:chests/vault              chest    pools:2  items:create:brass_ingot,create:andesite_alloy
  …

## summary
  total loot tables: 834
  by type: block 456, entity 234, chest 89, gameplay 34, other 21
  by mod (top 10): ae2 98, create 87, thermal 76, mekanism 65, …
  vanilla overrides: 5
  empty/produce-nothing tables: 3
  unresolved items: 4 (loot tables referencing items not in the item registry)
```

The per-source breakdown shows which mod jar (or datapack) defines each loot
table. The cross-source summary flags potential issues: vanilla overrides (mods
redefining vanilla loot tables), empty tables, and unresolved items.

## Review workflow

1. **Scan the whole pack** — `packwiz-loot P` (or
   `python3 loot.py P` outside opencode). For a targeted review, restrict
   to specific mods: `packwiz-loot P mods=ae2,still-life` or read the
   datapack lines.

2. **Look up a single loot table** — `packwiz-loot P lootInfo=minecraft:blocks/diamond_ore`
   or `mc-pack.py P loot-info minecraft:blocks/diamond_ore`. Returns type,
   pools, entries, items, conditions, source, override status, and raw JSON.

3. **Cross-reference with item/mob data** — if a loot table drops an item,
   `packwiz-items P itemInfo=<id>` shows which items are defined-but-unused
   or referenced-but-missing. If a mob's loot table is referenced,
   `packwiz-mobs P mobInfo=<id>` shows the mob's full metadata.

4. **Identify issues** — the summary flags:
   - **Vanilla overrides** — mods redefining `minecraft:` loot tables. Useful
     when a mod changes what a vanilla block drops; may be intentional or a
     conflict.
   - **Empty/produce-nothing tables** — loot tables with no pools or all pools
     have no entries. May indicate a broken mod or an intentional empty drop.
   - **Unresolved items** — loot tables referencing items not in the item
     registry. Often a broken mod dependency or a datapack targeting an item
     ID from a different mod version.

## Common tasks

### "What loot tables does mod X add?"
```
packwiz-loot AllTheTech mods=create
```

### "Does the pack override any vanilla loot tables?"
Look at the `vanilla overrides` line in the summary, or filter the scan to
only `minecraft:` IDs in the cross-source view.

### "What drops item X from a loot table?"
```
packwiz-loot AllTheTech lootInfo=minecraft:blocks/diamond_ore --json
```
The `items` field lists everything the loot table can drop.

### "Are there empty loot tables?"
Check the `empty/produce-nothing tables` line in the summary. Each empty table
is listed by ID.

## Full export

Dump every loot table's full metadata to a single JSON file — one scan pass,
one write, deterministic ID-sorted output. The `entries` map is keyed by loot
table ID; each value matches the `--info` detail shape (type, pools, entries,
items, conditions, source, override status, raw JSON).

```
# CLI — defaults to <packname>-loot-full.json
python3 tools/loot.py AllTheTech --full-export
python3 tools/loot.py AllTheTech --full-export /tmp/all-loot.json

# Scoped exports
python3 tools/loot.py AllTheTech --full-export --mods create,ae2
python3 tools/loot.py AllTheTech --full-export --no-vanilla

# Via mc-pack.py
python3 tools/mc-pack.py AllTheTech loot-full-export
python3 tools/mc-pack.py AllTheTech loot-full-export /tmp/loot.json
```

**Size estimates (AllTheTech):** ~117 loot tables → ~453 KB JSON (~1.1s total).

**Output shape:**
```json
{
  "pack": "AllTheTech", "tool": "loot.py", "version": "1.0",
  "sources": [{"kind": "mod", "name": "...", "jar": "...", "loot_tables": {"ae2:blocks/certus_ore": {...}}}],
  "summary": {"total_tables": 117, ...},
  "entries": {
    "ae2:blocks/certus_ore": {"id": "ae2:blocks/certus_ore", "type": "block", "pools": [...], "items": [...], ...},
    "minecraft:blocks/diamond_ore": {"id": "minecraft:blocks/diamond_ore", "type": "block", ...}
  }
}
```

## Tips

- **Always scan the pinned jars.** `packwiz-loot` reads `checksums.json`
  so it reviews exactly what players get — not what packwiz lists in
  `index.toml` (which can lag behind after `update --all` without checksums).
- **Jar caching is by checksum.** First scan downloads jars; re-scans are
  instant. Changing mods triggers fresh downloads only for changed jars.
- **Cross-check with items/mobs.** Loot tables are the bridge between items
  and mobs/blocks. A loot table drops items; mobs and blocks have loot tables.
  Use `packwiz-items` and `packwiz-mobs` together.
- **Vanilla loot tables are always present** unless `--no-vanilla` is passed.
  They're the baseline; the summary shows which mods override them.

## RUN LOG

### 2026-09-07
Created as the loot table review skill — mirrors `skill-mc-mod-items.md` and
`skill-mc-mod-structures.md`. Covers `packwiz-loot` / `loot.py` for
full-pack loot table scanning and `lootInfo` / `loot-info` for single-loot-
table lookup. Workflow: scan → identify vanilla overrides / empty tables /
unresolved items → cross-reference with item/mob tools → ship fixes.
