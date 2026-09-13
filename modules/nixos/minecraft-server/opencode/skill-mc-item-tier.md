---
name: mc-item-tier
description: Use when asked to review or assign rarity tiers to items in a packwiz modpack in this repo — computing deterministic 0-7 rarity scores based on acquisition difficulty. Use packwiz-item-tier / the standalone item-tier.py to scan a pack before deciding item rarity, loot table balance, or progression gating.
---

# Item Tier Review (packwiz)

Compute deterministic **0-7 rarity tiers** for every item in a pack based on
acquisition difficulty. Uses item-acquisition.py data to score items from
their acquisition paths.

## Tier scale

| Tier | Name | Examples |
|------|------|----------|
| 0 | World-generated blocks | dirt, stone, sand, gravel, wood |
| 1 | Common resources | coal, iron, copper, flint, leather |
| 2 | Uncommon resources | gold, lapis, redstone, string, bones |
| 3 | Rare resources | diamonds, emeralds, ender pearls, blaze rods |
| 4 | Crafted items | iron tools, basic machines, bread, torches |
| 5 | Advanced crafted items | diamond tools, enchanted gear, potions |
| 6 | Endgame items | netherite gear, max enchanted, elytra |
| 7 | Ultra-rare / admin | command blocks, bedrock, barriers |

## Scoring rules

- **Multi-path items** resolve to EASIEST path (min tier)
- **Recipe tier** = `max(ingredient_base_tier) + 0.1 * log2(distinct_ingredient_count)`
- **Tags are NOT scored** — they are metadata about what categories an item
  belongs to, not acquisition paths. Items whose only path is a tag get
  `tier: null` (see below).
- **No category fallback** — if no path can compute a score, tier is `null`
  with a reason. There is deliberately no "mod items = tier 4" guess
  (`_compute_category_tier` exists but is UNUSED).
- **Curated overrides** via `tier-overrides.toml` applied post-computation

## Three lenses (acquisition / impact / combined)

The tool reports **three separate scores** (same pattern as mob-tier's
combat/context/combined), so a reader always knows which one they're looking at:

- **`acquisition_tier`** — 0-7 rarity from acquisition difficulty (the original
  tier, previously called just `tier`).
- **`impact_score`** — 0-7 gameplay significance, a **p=2 general mean
  (root-sum-square)** of two sub-signals:
  1. **recipe-graph centrality** (primary; no scanner needed — reuses recipes.py's
     full graph): `direct_dependents` = recipes using the item as an ingredient;
     `downstream_dependents` = transitive closure of items unlockable through it
     (capped + log-scaled so iron ingot doesn't blow up).
  2. **component magnitude** (consumes `item-components-dump.json` from the
     **item-components-dump** headless dump — run `item-components-regenerate`
     after mod changes): attack/armor magnitude, enchantability, tool mining
     level (0-4), food nutrition/saturation, and the stack-size-1 uniqueness
     signal.
- **`combined_tier`** — headline 0-7 = p=2 mean of acquisition × impact.

Why root-sum-square and not a strict product (geometric mean)? A single strong
axis must be able to produce high impact — iron ingot (huge recipe centrality,
no components) and an endgame weapon (strong components, tiny centrality) must
both rank high; a product would collapse both to ~0. RMS keeps the dominant
axis leading while still rewarding both being present. (This is the p=2 member
of the same general-mean family mob-tier's `sqrt(a*b)` uses at p=2.)

**Null semantics differ from acquisition:** impact_score is a REAL low number
(≈0) for items with nothing on either axis (decorative/leaf items) — because for
impact, "no signal" itself means "probably not significant". Null is reserved
for a true data gap: the item id isn't found at all.

## Impact overrides (the "easy agent append" mechanism)

For items whose real impact isn't captured by recipe centrality or components
(e.g. a quest item, a key/lore item, an artifact whose utility is narrative —
something a mod doesn't encode mechanically), append **one line** to
`impact-overrides.toml` in the pack dir:

```toml
# Format: item_id = score (0-7)   # optional inline reason
relics:chorus_staff = 6   # unique teleport utility; rare loot only, no recipe path
```

**No code changes needed.** The override is the final value, but the computed
score is ALWAYS still shown alongside it for transparency (e.g.
`Impact override: 6 (computed=0.555)`).

The acquisition axis still uses `tier-overrides.toml` (existing mechanism).

## Tools

- **`packwiz-item-tier`** (opencode tool) — the scan in a session.
  Accepts `itemInfo` for single-item lookup, `mods=`, `noDatapacks`,
  `noVanilla`, `list`, `json`, `fullExport`.
- **`python3 modules/nixos/minecraft-server/opencode/tools/item-tier.py`**
  (standalone CLI). Accepts a pack NAME (auto-resolved under the repo's
  modpacks/) or a path.
- `mc-pack.py <pack> item-tier [flags]` — same engine via mc-pack.py.
- `mc-pack.py <pack> item-tier-info <id> [--json]` — single-item lookup.

### Flags (CLI and opencode tool)

```
item-tier.py <pack> [--mods slug1,slug2] [--no-datapacks] [--no-vanilla]
                    [--json] [--list] [--info <item>]
                    [--full-export [outfile]]
  --mods          restrict the JAR scan to listed mods (datapacks still scan!)
  --no-datapacks  skip the pack's datapacks (config/paxi/datapacks/ + data/)
  --no-vanilla    omit the embedded vanilla baseline
  --json          machine-readable JSON
  --list          print item_id=tier pairs
  --info <item>   detailed tier info for one item (fuzzy match on miss)
  --full-export   write every item's tier record to a single JSON file
```

## Output format

### Default (human-readable)

```
Item Tier — AllTheTech
  Items: 22225
  Tier distribution:
    Tier 0: 462 items
    Tier 1: 1373 items
    Tier 2: 14604 items
    Tier 3: 815 items
    Tier 4: 1064 items
    Tier 5: 79 items
    Tier 6: 30 items
    Tier 7: 10 items
    Tier null: 3788 items
```
(Note the tier-2 bulk: most mod items resolve to the loot `unknown` context
2.8 → tier 2. Tier numbers reflect acquisition difficulty, not curated rarity.)

### Single item (`--info`)

```
Item: minecraft:iron_ingot
  Category: material
  acquisition_tier: 1   (rarity, 0-7)
  impact_score:     5.631   (significance, 0-7)
  combined_tier:    6   (acquisition 1 × impact 5.631 (p=2))
  Acquire reason: vanilla base tier
  Impact reason:  recipe-centrality × component-magnitude (p=2)
  Paths: crafting, loot, smelting
  Impact factors:
    centrality: score=5.631 (direct=119, downstream=1487)
    components: score=0.0 (attack=0.0 ench=0.0 tool=0.0 mining_lvl=0 food=0.0 stack1=False)
```

### JSON (`--json`)

```json
{
  "id": "minecraft:iron_ingot",
  "category": "material",
  "acquisition_tier": 1,
  "impact_score": 5.631,
  "combined_tier": 6,
  "tier": 1,
  "computed_tier": 1,
  "override_tier": null,
  "reason": "vanilla base tier",
  "impact_computed": 5.631,
  "impact_override_tier": null,
  "impact_reason": "recipe-centrality × component-magnitude (p=2)",
  "paths": ["crafting", "loot", "smelting"],
  "impact_factors": {
    "centrality": {"direct_dependents": 119, "downstream_dependents": 1487, "score": 5.631},
    "components": {...},
    "component_score": 0.0
  }
}
```

(`tier`/`computed_tier`/`override_tier` are kept as back-compat aliases of the
acquisition axis.)

## Curated overrides

Create `tier-overrides.toml` in the pack directory to override computed
**acquisition** tiers:

```toml
# Format: item_id = tier (0-7)
minecraft:diamond = 4
some-mod:ultra-rare-item = 7
```

Create `impact-overrides.toml` to override computed **impact** scores (see the
"easy agent append" section above). Both show the override next to the computed
value for transparency — never hidden.

## When to use

- **When balancing loot tables** — verify items have appropriate rarity
- **When designing progression** — check tier distribution across the pack
- **When adding new items** — see how they compare to existing items
- **When debugging rarity** — check if items are over/under-valued
- **When assessing item significance** (RarityCore-style) — use the
  `impact_score` lens: high recipe centrality (foundational materials) or high
  component magnitude (endgame gear) both point to significant items; a
  decorative block gets a real low score, not null.

## Limitations

- **Computed tiers are acquisition-difficulty, not curated rarity.** The
  curated `ITEM_TIERS.json` → `allthetech_tiers.json` mapping for RarityCore is
  a rarity×impact judgment; the tool's loot-context signal (`unknown` weight
  0.4 → 2.8 → tier 2) flattens loot-only mod items (e.g. Artifacts) to a
  near-uniform tier-2 and leaves Relics **null** (their loot tables don't
  surface as datapack paths). Do NOT use computed tiers as the sole driver of
  RarityCore — keep the curated mapping as source of truth, and use
  `impact-overrides.toml` for loot artifacts whose impact the mechanics can't see.
- **Impact is only as good as its sub-signals.** Verified on AllTheTech: iron
  ingot impact 5.63 (recipe centrality), netherite_sword 3.83 (component
  magnitude: attack 6.0 vs centrality 0.97), decorative white_banner 0.55 (real
  low, not null). But loot-only artifacts (Artifacts/Relics) compute near-flat
  ~0.55 impact because they have no craft path and no attack/armor/food
  components — the override file exists precisely for those. Regenerating
  `item-components-dump.json` (slow) sharpens the component side; the recipe
  graph is always available.
- Most mod items default to acquisition tier 2 (loot `unknown` context) or null
  (no acquisition path); recipe ingredient resolution only works for items with
  explicit tier cache.
- Items with only tag paths get `tier: null` — that is honest, not a fallback.
- No cross-reference with mob drop loot tables yet.
- `--mods` filters resolve via prefix-preferred slugs; a bare substring that
  matches several mods still dies loudly (pass the exact slug).

## RUN LOG

### 2026-09-13 — impact dimension (three lenses) + impact-overrides + item-components dump
- Added the **impact_score** lens to item-tier.py: p=2 general mean (RMS) of
  recipe-graph centrality (direct + downstream dependents, reusing recipes.py's
  full export — no new scanner) and component magnitude (attack/armor/enchant/
  mining level/food/stack-1, from the NEW item-components-dump.json headless dump).
  Records now carry acquisition_tier / impact_score / combined_tier separately
  (mob-tier's combat/context/combined pattern). `tier` kept as back-compat alias.
- Added **impact-overrides.toml** — the "easy agent append": one line
  `item_id = score` (+ optional `# reason`); override wins but computed shown
  alongside. Loaded in scan_tiers, applied per-item.
- New dump: `source-patches/item-components-dump/ItemComponentsDump.java`
  (reflects `Item.components()` for all registered items) driven by the SAME
  `attributes_dump.py --dump-mod item-components-dump` harness (no boot-process
  reinvention). Consumer `item-components.py` + mc-pack commands +
  `packwiz-item-components.ts` + skill-mc-item-components.md.
- Verified on AllTheTech (22225 items, 24.6s full export): iron_ingot impact
  5.631 via downstream=1487; netherite_sword 3.826 via component attack 6.0
  (centrality only 0.97); white_banner 0.546 (real low, not null);
  reliquified override works (impact 6.0, computed=0.555 shown). Honest gap:
  loot-only Artifacts/Relics still compute near-flat impact (~0.555) — override
  file is the documented escape hatch for those.

### 2026-09-13 — accuracy audit vs curated RarityCore config + --mods resolver fixes
- Lesson: item-tier.py's computed tiers must NOT be used to drive the RarityCore
  config. Comparing against `config/raritycore/FinalRarityConfig/allthetech_tiers.json`
  (which is derived from the curated ITEM_TIERS.json S–F→1–7 mapping), every
  Artifacts item computed to tier 2 (loot context `unknown`, 0.4×7=2.8 → int → 2)
  while curated values span 1–7; every Relics item computed to null (no acquisition
  paths — their loot tables don't surface as datapack paths); SmallShips tiered by
  recipe depth (1–4) not rarity. Doc claims contradicted code: skill said "category
  fallback (mod items = tier 4)" and "tag weak signal" but the code has NO category
  fallback (`_compute_category_tier` is UNUSED) and tags are never scored.
- Fix: corrected the skill doc (no category fallback; tags not scored; honest
  limitations; refreshed the stale example summary). Also fixed the `--mods`
  resolver: `--mods reliquified_artifacts` died as "ambiguous" (matched both
  `artifacts` and `reliquified_artifacts-1.21.1-1.0.8`) and then silently hollowed
  out the whole scan (every sub-scanner returned {}); `resolve_mod` in
  datapack_common.py / items.py / mobs.py / structures.py / mc-pack.py now prefers
  a target-prefixed key. mobspawn.py had a duplicated resolver, a wrong
  `fuzzy_match(mod_specs, mod_filter)` call, and no comma-split of `--mods` — all
  fixed; restricted scans now return artifacts/relics/smallships rows.
