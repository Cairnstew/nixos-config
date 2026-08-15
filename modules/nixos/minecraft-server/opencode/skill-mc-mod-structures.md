---
name: mc-mod-structures
description: Use when asked to review or inventory the worldgen structures a packwiz modpack in this repo adds — listing every structure and structure set that ships in the pinned mod jars and the pack's own datapacks, what each structure spawns where, which sets reference missing structures, and which structures overlap/redefine vanilla. Use packwiz-structures to scan a pack before deciding whether a structure mod/datapack is worth keeping or needs a config tweak.
---

# Mod Structure Review (packwiz)

Inventory and review every **worldgen structure** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` will generate. "Structures"
here means Minecraft worldgen structures — generated buildings/features —
defined as `data/<ns>/worldgen/structure/*.json` files, grouped into
`data/<ns>/worldgen/structure_set/*.json` sets that register them to biomes.
Sources scanned:

- **Mod jars** — the pack's **pinned** jars (from `checksums.json`), so what
  you review is exactly what players get. Full-pack scans cache downloaded
  jars by checksum, so re-runs are instant.
- **The pack's own datapacks** — `config/paxi/datapacks/` (Paxi, server-side
  too) and any pack-level `data/` directory.

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what structures does the pack
add, and are they sound" review step.

## Tools

- `packwiz-structures <pack> [mods=slug1,slug2] [noDatapacks]` — **the scan.**
  Reports per-source (per mod, per datapack) every structure and structure set
  it ships, then a cross-source summary:
  - total structures / total structure sets
  - structures defined but NOT referenced by any set (these never spawn via a
    set — many mods register sets in code instead; usually fine)
  - sets that reference **missing** structures (a real bug — the set spawns a
    structure that isn't defined anywhere in the pack)
  - `minecraft:`-namespace structures the pack/mods **redefine** (they
    override/replace the vanilla one — confirm that's intended)
  - `minecraft:`-namespace **set names** redefined (flagged inline on the set
    line — overrides the vanilla set's placement).
  - `--mods` restricts the jar scan to specific mods; `--no-datapacks` skips
    the datapack scan.
- `packwiz-config-show <pack> <mod>` / `packwiz-config-diff` — when a structure
  mod has a config to disable/tune its structures (the `mc-mod-config` skill
  covers this workflow).
- `packwiz-datapack-add` / `-remove` — when the review leads to shipping or
  removing a custom datapack that adds structures.

## Reading `packwiz-structures` output

```
  ## mod: applied energistics 2 (appliedenergistics2-19.2.17.jar)
    structure  ae2:meteorite  (type=ae2:ae2mtrt, biomes=#ae2:has_meteorites)
    set        ae2:meteorite  ->  ae2:meteorite
  ## datapack: config/paxi/datapacks/my-tweaks/
    structure  minecraft:village  (type=minecraft:jigsaw, biomes=#minecraft:is_…)  [OVERLAPS VANILLA — replaces the vanilla one]

## summary (12 jars downloaded, rest from cache)
  total structures:     365
  total structure sets: 104
  structures NOT in any set (never spawn via sets — likely fine, set-driven via code): 29
  vanilla-overlapping structures (pack/mods redefine them): 14
    - minecraft:stronghold
    - minecraft:village_taiga
```

- `structure <id> (type=…, biomes=…)` — one generated structure. `type` is the
  placement type (`minecraft:jigsaw` for template-pool structures,
  mod-specific types for code-driven ones). `biomes` may be a `#tag` (any biome
  in the tag) or a biome name.
- `set <id> -> a, b` — one structure set: which structures it spawns. A set
  with `(empty)` members is inert. `[VANILLA SET NAME — …]` on a set line means
  the set shares a name with a vanilla set (e.g. `minecraft:villages`).
- `[OVERLAPS VANILLA — …]` on a structure means the pack (mod or datapack)
  ships a `minecraft:`-namespace structure, replacing the vanilla definition.
- Summary notes: missing-references and vanilla-overlap lists are the things to
  actually act on. Everything else is an inventory.
- Full-pack runs download each jar once (cached in
  `$TMPDIR/mc-pack-jars/` by checksum); only the first run for a checksum
  downloads, reported as `N jars downloaded`.

## Workflow: review the structures the pack adds

1. **Scan the whole pack** — `packwiz-structures P`.
2. **If a specific mod/datapack is the subject**, restrict:
   `packwiz-structures P mods=ae2,still-life` or read the datapack lines.
3. **Act on the cross-source summary:**
   - *Missing references* — a set points at a structure no source defines. The
     structure may come from a removed mod, a name typo, or a structure defined
     in code (a custom `type`). Investigate before calling it broken: a
     code-defined structure referenced by a JSON set is legitimate.
   - *Vanilla overlaps* — the pack redefines vanilla structures. For each, note
     the overriding source (mod vs datapack) and whether that's intended (many
     mods intentionally replace e.g. `minecraft:village_taiga`). If a datapack
     override is accidental, `packwiz-datapack-remove`.
   - *Structures NOT in any set* — informational; the mod registers its set in
     Java. Only flag as a problem if the mod itself can't spawn them.
4. **Tune rather than remove** — if a structure mod spawns too much or too
   little, prefer its config (see `mc-mod-config`) or a custom datapack tweak
   over dropping the mod. The modpack owner wants mods kept (see `mc-modpack`
   gotchas).
5. **Report** consistently:
   - Inventory: structures + sets by source (mod jar / datapack), with the
     pinned jar filenames for mods (proves which version was reviewed).
   - Findings: missing references, vanilla overlaps, set-name collisions — with
     the offending source.
   - Recommendation only if asked: keep / config-tune / datapack-override /
   remove (removal last resort).

## Accuracy rules

- **Always scan the pinned jars.** `packwiz-structures` reads `checksums.json`
  — the exact URLs packwiz2nix builds. Never describe a mod's structures from
  Modrinth's latest release unless the pack pins that version.
- **Don't fabricate structure presence/absence.** If the tool says a structure
  isn't in the pack, that's the answer for this pinned set — don't guess from
  the mod's docs.
- **"Not in any set" ≠ "doesn't spawn".** Structure sets are the data-driven
  path; many mods register sets (and even structures) in code. Only
  referenced-but-missing is a hard signal.
- A structure's `type` being a mod id (e.g. `ae2:ae2mtrt`) means it's
  code-driven; its real placement rules live in the mod, not in the JSON.

## Gotchas

- **First full scan downloads a lot.** A 250-mod pack downloads most jars once
  (~1–2 GB depending on mods) and caches them; later runs are fast. Don't
  interpret the download step as a failure.
- **Datapack dirs are re-zipped in memory** for the scan; zip and dir datapacks
  report identically. A datapack with no worldgen files is silently omitted
  from output (nothing to show).
- **CurseForge-mode mods** (no download URL) are skipped with a `SKIP` line —
  convert them first (`mc-modpack` skill) or accept the gap and say so.
- `structure_set` and `structure` JSONs are per-namespace; a set in one namespace
  may reference structures in another (e.g. `minecraft:villages` referencing a
  mod's `foo:village_taiga`). The summary's reference check is cross-namespace.
- **RoadWeaver = the "trails/roads" mod.** When a user says "make the trails mod
  go to other structures", they mean RoadWeaver (road networks between
  structures). Its own structures (bridges, roadside decor) show up as "NOT in
  any set" — expected, they're code-placed along roads, not spawned via sets.
  RoadWeaver's *which structures get linked* is NOT in its structure JSONs: it's
  `structurePrediction.structureWhitelist` in `config/roadweaver/roadweaver.json`
  (default `["#minecraft:village"]`; supports `#tag`, `ns:*`, `ns/*`, exact ids;
  overworld-only discovery). To link roads to the pack's other structures, ship
  an expanded whitelist via `packwiz-config-add` (see `mc-mod-config-set`).
- Output can be large (hundreds of lines for a big pack). Summarize rather than
  pasting verbatim; drill into a mod with `mods=` when a detail matters.

## Example

```
user: what structures does DragonTech add, and does anything override vanilla?

1. packwiz-structures DragonTech
   → per-mod + per-datapack inventory (365 structures, 104 sets across the pack)
   → summary flags 14 vanilla-overlapping structures (minecraft:stronghold,
     minecraft:village_taiga, …) and 29 set-less structures
2. Drill into the vanilla overrides: packwiz-structures DragonTech
   → identify the owning mod/datapack for each overlap
3. report: pack-wide inventory summary, the vanilla redefinitions and their
   sources, missing references (none), and that set-less structures are
   code-registered so are expected.
```

## RUN LOG

### 2026-08-14 — RoadWeaver = "the trails mod"; its linking is a JSON whitelist
- Lesson: user asked to "make the trails mod go to other structures" — there is
  no mod literally named trails; the roads/trails mod is RoadWeaver, and its
  structure-linking is NOT in its structure JSONs but in
  `structurePrediction.structureWhitelist` in `config/roadweaver/roadweaver.json`.
- Fix: added the RoadWeaver gotcha above, pointing to the whitelist config and
  the `mc-mod-config-set` write path for shipping an expanded default.

### 2026-08-14
2026-08-14 — investigate ocean-crossing roads (user report)
Lesson: RoadWeaver issue #68 — roads pave through water in modded/untagged water biomes; check which whitelisted structure mods spawn structures in/near ocean so roads get forced across water.
Fix: none yet; scan to find ocean-spawning structures in the whitelist.

### 2026-08-14
placeholder-scan

### 2026-08-15
investigate ocean/coastal structures for RoadWeaver road-end-in-sea compatibility
