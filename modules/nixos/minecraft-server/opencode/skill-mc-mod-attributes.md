---
name: mc-mod-attributes
description: Use when asked to review entity attributes (combat stats, movement speed, armor, etc.) a packwiz modpack defines — listing every entity's registered attributes with source classification (vanilla vs modded), non-default values highlighted, and the full attribute profile for individual entities. Use packwiz-attributes / the standalone attributes.py to check combat balance, find stat overrides, or verify attribute changes after mod updates. Note: the attribute dump regenerates via an isolated NeoForge server (~190s total cold / ~35s cached — dominated by the nix packwiz build, ~30s of JVM; see RUN LOG for the stdout-pipe fix); the consumer tool reads the cached JSON instantly.
---

# Mod Entity Attributes Review (packwiz)

Inventory and review every **entity attribute** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` resolves. Attributes are
the NeoForge registered stat system — things like `minecraft:generic.max_health`,
`minecraft:generic.movement_speed`, `apothic_attributes:crit_chance`, etc.

This is a two-phase system:
1. **Regenerate** — launches an isolated NeoForge server with the pack's real mods,
   dumps every registered attribute for every entity to `attributes-dump.json`.
   ~190s total cold (~30s JVM JarJar+modload; ~157s nix packwiz-mod build), ~35s when
   the packwiz FODs are cached. Re-run after mod list changes.
2. **Read** (instant) — reads the cached JSON, transposes from attribute-centric
   to entity-centric view, classifies entities as vanilla/modded.

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what attributes does the
pack set on each entity, and are they balanced" review step.

## Tools

- **`packwiz-attributes`** (opencode tool) — the consumer in a session. Accepts
  `entityInfo` for single-entity lookup, `list`/`json` for scanning.
  Also accepts `attributesRegenerate=true` for the slow-path dump.
- **`python3 modules/nixos/minecraft-server/opencode/tools/attributes.py`**
  (standalone CLI — use when outside opencode or when you want the raw
  machine-readable output). Accepts a pack NAME (auto-resolved under the
  repo's modpacks/) or a path. Both hit the same engine; `attributes.py` is
  the source of truth, `packwiz-attributes` and `mc-pack.py attributes`
  delegate.
- `mc-pack.py <pack> attributes-info <entity-id>` — single-entity lookup via
  the same engine.
- `mc-pack.py <pack> attributes-regenerate` — re-run the slow-path dump.

### Flags (CLI and opencode tool — consumer)

```
attributes.py <pack> [--no-vanilla] [--json] [--list] [--show-all]
  --no-vanilla    omit vanilla entities (only show modded-added)
  --json          machine-readable: {"modpack":…, "entities":{…}}
  --list          just entity ids, one per line (pipe-friendly)
  --show-all      show all attributes including defaults
```

```
attributes.py <pack> --info <entity-id> [--show-all] [--attribute <name>]
  --info <id>     look up a single entity by ID (fuzzy match on miss)
  --show-all      show all attributes (default: non-default only)
  --attribute     filter to specific attribute(s) by substring (repeatable)
```

### Flags (CLI and opencode tool — regenerate)

```
attributes_dump.py <modpack-dir> [--dry-run] [--timeout N] [--exclude-mods slug1 slug2]
  --dry-run       print what would be done without doing it
  --timeout       server timeout in seconds (default 600)
  --exclude-mods  mod slugs to exclude from the server
```

## Reading the output

Default human output:

```
Entity Attributes — AllTheTech
  MC 1.21.1 / NeoForge 21.1.249
  Generated: 2026-09-08T00:42:57Z
  Entities: 77 vanilla + 241 modded = 318 total
  Attributes: 88

── Vanilla entities (77) ──
  minecraft:blaze  (5 non-default)
  minecraft:zombie  (5 non-default)
  ...

── Modded entities (241) ──
  [artifacts] (1):
    artifacts:mimic
  [iceandfire] (28):
    iceandfire:fire_dragon  (4 non-default)
    iceandfire:ice_dragon  (4 non-default)
    ...
```

`--info` output for a single entity:

```
Entity: minecraft:zombie [minecraft]
  Source: vanilla

  Non-default attributes (5):
  epicfight:impact: 1.0  (base: 0.5)
  minecraft:generic.armor: 2.0  (base: 0.0)
  minecraft:generic.attack_damage: 3.0  (base: 2.0)
  minecraft:generic.follow_range: 35.0  (base: 32.0)
  minecraft:generic.movement_speed: 0.23000000417232513  (base: 0.7)

  (63 attributes at default — use --show-all to view)
```

- `(N non-default)` on entity list lines — count of attributes whose resolved
  value differs from the base default. A non-default count of 0 means the
  entity has all default attributes (common for modded entities with only
  NeoForge-inherited stats).
- `Source: vanilla` — entity is in the vanilla baseline for MC 1.21.1.
  `Source: modded` — entity was added by a mod (not in vanilla).
- `base:` in the non-default list shows what the attribute's default value is,
  so you can see the magnitude of the change.

## Workflow: review entity attributes

1. **Check if dump exists** — `attributes.py <pack> --list` will error with a
   helpful message if the dump is missing.
2. **Regenerate if needed** — `mc-pack.py <pack> attributes-regenerate` or
   `packwiz-attributes modpack=AllTheTech attributesRegenerate=true`.
   Takes ~190s cold (~30s JVM); re-run after any mod add/remove/update.
3. **Scan the whole pack** — `attributes.py <pack>` or
   `packwiz-attributes modpack=AllTheTech`.
4. **Look up specific entities** when something looks off:
   `attributes.py <pack> --info minecraft:zombie --show-all` to see the full
   attribute profile.
5. **Filter to specific attributes** when hunting for a stat:
   `attributes.py <pack> --info minecraft:zombie --attribute damage`
6. **Export for analysis** — `attributes.py <pack> --full-export` dumps
   everything to JSON.

## Use cases

- **Combat balance review** — check `minecraft:generic.attack_damage`,
  `minecraft:generic.max_health`, `minecraft:generic.armor` across entities.
- **Mod attribute audit** — verify apothic_attributes, epicfight, or other
  mod-specific attributes are being applied correctly.
- **Post-update validation** — after updating a mod, re-regenerate and compare
  non-default counts to see if attribute values changed.
- **Missing entity check** — if a mod's entity isn't showing attributes, check
  if the dump includes it (the dump covers everything NeoForge registers).

## Accuracy rules

- **The dump reflects the live NeoForge registry.** All attributes for all
  entities are shown, including inherited/resolved values. This is the
  authoritative source for what the server actually uses.
- **Source classification is binary** (vanilla vs modded). We cross-reference
  against mobs.py's vanilla baseline. We don't currently track vanilla
  attribute modifications (whether a mod changed a vanilla entity's stats)
  because vanilla attribute defaults aren't available offline.
- **Don't fabricate attribute values.** If the tool shows an attribute at its
  default, that's what the registry resolved — don't guess from the mod's docs.
- The dump is regenerated by launching a real NeoForge server, so it captures
  everything including code-registered attributes and mod interactions.

## Gotchas

- **Regenerate is ~190s cold (~35s cached).** It builds Nix derivations, copies the
  server, launches a JVM (~30s JarJar+modload+dump), and extracts the JSON. The bulk
  of the cold cost is the nix packwiz-mod linkFarm build (157s); with FODs cached it
  is ~5s, so a cached regenerate is ~35s. The consumer reads the cached JSON
  instantly — don't regenerate unless the mod list changed.
- **The dump is attribute-centric, the tool is entity-centric.** The raw JSON
  is `{attribute → {base_value, entities: {entity → value}}}`. The tool
  transposes this to `{entity → {attribute → value}}` which is more useful for
  debugging.
- **All entities have all attributes.** NeoForge populates every registered
  attribute for every entity (with default values). Most attributes are at
  their default for most entities. The `--info` view highlights non-defaults
  to cut through the noise.
- **Vanilla entities may have non-default attributes.** Mods can override
  vanilla entity stats (e.g. epicfight changes zombie movement speed). This is
  expected — check if the override is intentional.

## Full export

Dump every entity's full attribute data to a single JSON file — one read pass,
one write, deterministic ID-sorted output.

```
# CLI — defaults to <packname>-attributes-full.json
python3 tools/attributes.py AllTheTech --full-export
python3 tools/attributes.py AllTheTech --full-export /tmp/all-attrs.json

# Vanilla-only export
python3 tools/attributes.py AllTheTech --full-export --no-vanilla

# Via mc-pack.py
python3 tools/mc-pack.py AllTheTech attributes-full-export
python3 tools/mc-pack.py AllTheTech attributes-full-export /tmp/attrs.json
```

**Size estimates (AllTheTech):** 318 entities × 88 attributes → ~180 KB JSON.

**Output shape:**
```json
{
  "modpack": "AllTheTech",
  "mc_version": "1.21.1",
  "neoforge_version": "21.1.249",
  "generated_at": "2026-09-08T00:42:57Z",
  "entity_count": 318,
  "attribute_count": 88,
  "entities": {
    "minecraft:zombie": {
      "source": "vanilla",
      "mod": "minecraft",
      "attribute_count": 68,
      "non_default_count": 5,
      "attributes": {"minecraft:generic.max_health": 20.0, ...},
      "non_default": {"minecraft:generic.attack_damage": 3.0, ...}
    }
  }
}
```

## Example

```
user: what are the combat stats for iceandfire dragons?

1. python3 …/attributes.py AllTheTech --info iceandfire:fire_dragon
   → Source: modded
   → Non-default attributes (4):
     minecraft:generic.armor: 4.0  (base: 0.0)
     minecraft:generic.attack_damage: 1.0  (base: 2.0)
     minecraft:generic.follow_range: 128.0  (base: 32.0)
     minecraft:generic.movement_speed: 0.3  (base: 0.7)
2. report: fire dragon has 4 armor, 1 attack damage, 128 follow range,
   0.3 movement speed — notable changes from defaults.
```

```
user: does anything have suspiciously high health?

1. python3 …/attributes.py AllTheTech --json | jq '.entities | to_entries | map(select(.value.non_default["minecraft:generic.max_health"])) | sort_by(-.value.non_default["minecraft:generic.max_health"]) | .[0:5]'
   → top 5 entities by max_health override
2. report: the 5 entities with the highest health overrides.
```

## RUN LOG

### 2026-09-12
log4j2 RollingFile appender never flushed its buffer (100MB size threshold vs 63KB actual file). The JVM ran 598s but only 2s of log was written to disk — all post-mod-discovery output was lost. Fix: added `immediateFlush="true"` to both RollingFile appenders in `attributes_dump.py`. Also confirmed: AttributesDump hooks `FMLLoadCompleteEvent` (before world gen), so the entire ~541s is mod loading time, not world gen.

### 2026-09-12 — flush hypothesis DISPROVED, timeout corrected
Reverted `immediateFlush="true"` → server still did NOT complete in 900s. The flush is NOT the cause. Without it, the COMPLETE marker stays in a log buffer and never reaches disk, so the script times out even if the server actually completed. With it, the 1759s run DID produce the dump successfully. Root cause: the server genuinely takes ~30 minutes (1759s) for JarJar dependency resolution with 363 mods (282 top-level + 81 JarJar nested). The original 541s run was likely with a different mod configuration or caching state. Default timeout set to 1800s. Kept `immediateFlush="true"`.

### 2026-09-12 — REAL ROOT CAUSE: undrained stdout=PIPE deadlock (the 1759s/30min JarJar theory is wrong)
Both the 1759s and the "timeout during stall" observations were the same deadlock, not slow JarJar: `attributes_dump.py` opened `Popen(stdout=PIPE)` but never drained `proc.stdout`, while `log4j2.xml`'s `<Console target="SYSTEM_OUT">` mirror-appender wrote every log line to that pipe. Once console output exceeds the 64KB pipe buffer, java's `main` blocks in `OutputStreamManager.flush` forever — no JarJar progress, RollingFile logs freeze at ~64KB, near-zero CPU delta across minutes (verified). Fix: route Popen stdout to `logs/console.log` (the tailer only reads RollingFile logs + dump JSON). After the fix the **entire JVM phase (JarJar + mod load + dump) is ~30s of server runtime**; a full `mc-pack attributes-regenerate` is ~190s wall, dominated by the nix packwiz linkFarm build (157s, ~5s when cached) rather than the JVM. The eula.txt crash is a separate failure mode, not the cause of the long/stalled runs. The `~30min` regenerate estimate above is superseded — use ~190s total for a cold packwiz build, ~35s when cached.
