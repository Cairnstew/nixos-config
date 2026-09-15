---
name: mc-mod-mobs
description: Use when asked to review or inventory the mob entities a packwiz modpack in this repo adds — listing every mob with its category (monster/creature/ambient/etc.), the defining mod jar or datapack, vanilla override status, entity tags, loot tables, spawn modifiers, and which mobs have datapack spawn modifications. Use packwiz-mobs / the standalone mobs.py to scan a pack before deciding whether a mob mod is working as intended or needs a config tweak.
---

# Mod Mob Review (packwiz)

Inventory and review every **mob entity** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` will include. "Mobs" here
means all living entities — monsters, passive creatures, ambient mobs, water
mobs, axolotls, and any other `LivingEntity` subclass — defined via code
(registered in mod jars) or data (loot tables, biome modifiers, entity tags,
spawn eggs). Sources scanned:

- **Vanilla baseline** — embedded table for the pack's MC version (1.21.1:
  ~80 mobs extracted from Mojang's client jar), so vanilla zombies/creepers/
  villagers are listed as the starting point.
- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too), pack-level `data/` directory (loot tables, biome modifiers, entity
  tags), and `defaultconfigs/` (Forge server-side configs).

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what mobs does the pack
add/change, and are they sound" review step.

## Tools

- **`packwiz-mobs`** (opencode tool) — the scan in a session. Packs the same
  flags as the CLI: `mods=`, `noDatapacks`, `noVanilla`, `list`, `json`.
  Also accepts `mobInfo` for single-mob lookup.
- **`python3 modules/nixos/minecraft-server/opencode/tools/mobs.py`**
  (standalone CLI — use when outside opencode or when you want the raw
  machine-readable output). Accepts a pack NAME (auto-resolved under the
  repo's modpacks/) or a path. Both hit the same engine; `mobs.py` is the
  source of truth, `packwiz-mobs` and `mc-pack.py mobs` delegate.
- `mc-pack.py <pack> mob-info <id> [--json]` — single-mob lookup via the same
  engine. Returns source, category, tags, loot table, spawn egg, vanilla
  override status, and spawn modifiers.

### Flags (CLI and opencode tool)

```
mobs.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
               [--json] [--list]
  --mods          restrict the JAR scan to listed mods (datapacks still scan!)
  --no-datapacks  skip the pack's datapacks (config/paxi/datapacks/ + data/)
  --no-vanilla    omit the embedded vanilla mobs baseline
  --json          machine-readable: {"pack":…, "sources":[…], "summary":{…}}
  --list          just mob ids, one per line (pipe-friendly)
```

```
mobs.py <pack> --info <id> [--json]
  --info <id>     look up a single mob by ID; bare paths (e.g. zombie)
                  default to minecraft: namespace
  --json          output the full lookup result as JSON
```

`--json` schema (stable): `pack` (name/dir/minecraft/loader/version),
`sources[]` each `{kind: vanilla|mod|datapack, name, jar?, mobs:
{ns:id:{category, has_loot_table, has_spawn_egg, loot_table, tags[],
override, datapack_overrides[]}}}`, and `summary` with `total_mobs`,
`total_with_loot_tables`, `total_with_spawn_eggs`, `total_overrides`,
`total_datapack_modified`, `jars_downloaded`, `jars_from_cache`,
`skipped_no_url`, `per_category`, `by_source`.

`--info` result fields: `id`, `source` (kind + name + jar filename),
`category` (monster/creature/ambient/water_creature/water_ambient/
underground_water_creature/axolotl/misc/unknown), `has_loot_table`,
`has_spawn_egg`, `loot_table` (path if found), `tags[]` (entity tags),
`override` (true/false), `datapack_overrides[]` (list of datapacks that
modify this mob), `spawn_modifiers[]` (biome modifiers that affect it).
Unknown IDs get a fuzzy "did you mean" suggestion.

## Reading `packwiz-mobs` output

```
  ## source: vanilla 1.21.1 baseline
    mob  minecraft:zombie        (category=monster, loot_table=minecraft:entities/zombie)
    mob  minecraft:villager      (category=creature, loot_table=minecraft:entities/villager)
  ## source: mod: applied energistics 2 (appliedenergistics2-19.2.17.jar)
    mob  ae2:quantum_bully       (category=monster, loot_table=entities/quantum_bully)
  ## source: datapack: config/paxi/datapacks/my-tweaks/
    mob  minecraft:zombie        (category=monster)  [OVERRIDES VANILLA — modifies spawn]

## summary (0 jars downloaded, 250 from cache)
  total mobs:          247
  with loot tables:    240
  with spawn eggs:     218
  vanilla overrides:   3
  datapack-modified:   5
  by source:
    vanilla baseline:  82
    mod jars:          163
    datapacks:         2
  per category:
    monster:           87
    creature:          94
    ambient:           12
    water_creature:    18
    water_ambient:     22
    underground_water: 7
    axolotl:           5
    misc:              2
```

- `mob <id> (category=…, loot_table=…)` — one mob entity. `category` is the
  Minecraft mob category (determines spawn rules). `loot_table` is the path
  if a loot table was found in the scanned sources.
- `[OVERRIDES VANILLA — …]` on a mob line means a mod or datapack redefines
  a vanilla mob's loot table or spawn behavior.
- Summary notes:
  - `vanilla_overrides` — mobs the pack redefines from vanilla. Confirm each
    is intentional (some mods intentionally replace e.g. `minecraft:villager`
    behavior).
  - `datapack_modified` — mobs with datapack spawn modifier changes (biome
    modifier files that add/remove spawn rules). These are data-driven and
    override the vanilla or mod defaults.
  - `per_category` — breakdown by mob category. Useful for balancing: too many
    monsters vs. passive creatures, or unusual category counts.
- Full-pack runs download each jar once (cached in `$TMPDIR/mc-pack-jars/` by
  checksum); only the first run for a checksum downloads, reported as
  `N jars downloaded`. Output is sorted and deterministic — identical inputs
  produce byte-identical output, so you can diff runs.

## Workflow: review the mobs the pack adds

1. **Scan the whole pack** — `packwiz-mobs P` (or
   `python3 …/tools/mobs.py P` outside opencode).
2. **If a specific mod/datapack is the subject**, restrict:
   `packwiz-mobs P mods=ae2,still-life` or read the datapack lines.
3. **Look up individual mobs** when the scan flags something interesting:
   `python3 …/mobs.py P --info minecraft:zombie` — returns the defining
   source (mod jar or datapack), category, tags, loot table, spawn egg,
   vanilla override status, and spawn modifiers. The opencode tool accepts
   `mobInfo` for the same lookup.
4. **Act on the cross-source summary:**
   - *Vanilla overrides* — the pack redefines vanilla mobs. For each, note
     the overriding source (mod vs datapack) and whether that's intended.
     If a datapack override is accidental, `packwiz-datapack-remove`.
   - *Datapack-modified mobs* — mobs with spawn modifier changes. Check if
     the modifications are intentional (e.g. disabling a spawn in certain
     biomes) or accidental.
   - *Defined-but-unused* — mobs with loot tables but no spawn rules. These
     exist in data but can't naturally spawn. Usually intentional (summoned
     via commands), but worth noting.
   - *Referenced-but-missing* — spawn modifiers or loot tables reference a
     mob ID no source defines. Investigate before calling it broken.
5. **Report** consistently:
   - Inventory: mobs by source (vanilla baseline / mod jar / datapack), with
     the pinned jar filenames for mods (proves which version was reviewed).
   - Findings: vanilla overrides, datapack modifications, missing references,
     category balance.
   - Recommendation only if asked: keep / config-tune / datapack-override /
     remove (removal last resort).

## Accuracy rules

- **Always scan the pinned jars.** `packwiz-mobs` reads `checksums.json`
  — the exact URLs packwiz2nix builds. Never describe a mod's mobs from
  Modrinth's latest release unless the pack pins that version.
- **Don't fabricate mob presence/absence.** If the tool says a mob isn't in
  the pack, that's the answer for this pinned set — don't guess from the
  mod's docs.
- **"Not in any loot table" ≠ "doesn't exist".** Some mobs are code-only
  (registered in Java) with no JSON loot table. Only loot-table presence is
  checked; code-registered mobs without loot tables are still valid.
- A mob's `category` being a mod-specific category (if any) means it's
  code-driven; its real spawn rules live in the mod, not in the JSON.
- The vanilla baseline is authoritative for its MC version and offline (baked
  into `mobs.py`). A pack on a version with no embedded table still scans
  mods/datapacks and prints a stderr notice that the baseline is omitted —
  never pretend vanilla was scanned.

## Gotchas

- **First full scan downloads a lot.** A 250-mod pack downloads most jars once
  (~1–2 GB depending on mods) and caches them; later runs are fast. Don't
  interpret the download step as a failure.
- **`mods=` is a partial scan — expect "missing" noise.** Restricting the JAR
  scan does not restrict the datapack scan: datapacks may reference mobs from
  non-scanned mods, so `referenced_missing` fills with plausible ids. That
  is the tool being honest, not broken — for a clean missing-check run the
  whole pack (or add `noDatapacks` when the datapacks aren't the subject).
- **CurseForge-mode mods** (no download URL) are skipped with a `SKIP` line
  (visible in `skipped_no_url` in `--json`) — convert them first (`mc-modpack`
  skill) or accept the gap and say so.
- **Mobs may appear in multiple sources** (e.g. a mod AND a datapack define
  the same mob ID) — each source's version is the effective one for its
  datapack layer. The summary union treats the id as defined.
- Output can be large (hundreds of lines for a big pack). Summarize rather
  than pasting verbatim; drill into a mod with `mods=` when a detail matters,
  or use `list`/`json` for exactly the ids or a stable data structure.

## Full export

Dump every mob's full metadata to a single JSON file — one scan pass, one
write, deterministic ID-sorted output. The `entries` map is keyed by mob ID;
each value matches the `--info` detail shape (source, category, tags, loot
table, spawn egg, vanilla override status, spawn modifiers).

```
# CLI — defaults to <packname>-mobs-full.json
python3 tools/mobs.py AllTheTech --full-export
python3 tools/mobs.py AllTheTech --full-export /tmp/all-mobs.json

# Scoped exports
python3 tools/mobs.py AllTheTech --full-export --mods create,ae2
python3 tools/mobs.py AllTheTech --full-export --no-vanilla

# Via mc-pack.py
python3 tools/mc-pack.py AllTheTech mobs-full-export
python3 tools/mc-pack.py AllTheTech mobs-full-export /tmp/mobs.json
```

**Size estimates (AllTheTech):** ~93 mobs → ~84 KB JSON (~2.2s total).

**Output shape:**
```json
{
  "pack": "AllTheTech", "tool": "mobs.py", "version": "1.0",
  "sources": [{"kind": "mod", "name": "...", "jar": "...", "mobs": {"ae2:quantum_bully": {...}}}],
  "summary": {"total_mobs": 93, ...},
  "entries": {
    "ae2:quantum_bully": {"id": "ae2:quantum_bully", "source": {...}, "category": "monster", ...},
    "minecraft:zombie": {"id": "minecraft:zombie", "source": {...}, "category": "monster", ...}
  }
}
```

## Example

```
user: what mobs does AllTheTech add, and does anything override vanilla?

1. packwiz-mobs AllTheTech
   → per-source inventory incl. the vanilla 1.21.1 baseline
   → summary: 247 mobs across the pack
   → flags 3 vanilla mobs the pack redefines and 5 datapack-modified mobs
2. Drill into the vanilla overrides: packwiz-mobs AllTheTech
   → identify the owning mod/datapack for each override
3. report: pack-wide inventory summary, the vanilla redefinitions and their
   sources, category balance, and any missing references (none).
```

```
user: is ae2:quantum_bully in the pack, and what does it do?

1. python3 …/mobs.py AllTheTech --info ae2:quantum_bully
   → source: mod jar (appliedenergistics2-19.2.17.jar)
   → category: monster, has_loot_table: true, has_spawn_egg: true
   → tags: [ae2:quantum_bully]
2. report: ae2:quantum_bully — from "Applied Energistics 2", monster category,
   has loot table and spawn egg, defined by the pinned mod jar.
```

```
user: what mobs have datapack spawn modifications?

1. packwiz-mobs AllTheTech
   → summary shows 5 datapack-modified mobs
2. Read the datapack source lines for each modified mob
   → identify which datapack changes spawn rules and what changes
3. report: the 5 mobs with datapack spawn modifications, which datapacks
   change them, and what the modifications are.
```

## RUN LOG
