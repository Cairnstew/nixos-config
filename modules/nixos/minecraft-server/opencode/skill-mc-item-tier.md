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
- **Tag paths** use weak signal: `3.0 + 0.5 * log2(tag_count)` (capped at 5.0)
- **Category fallback** for items with no paths (e.g., mod items = tier 4)
- **Curated overrides** via `tier-overrides.toml` applied post-computation

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
  Items: 16525
  Tier distribution:
    Tier 0: 14 items
    Tier 1: 19 items
    Tier 2: 66 items
    Tier 3: 15888 items
    Tier 4: 392 items
    Tier 5: 12 items
    Tier 6: 13 items
    Tier 7: 8 items
```

### Single item (`--info`)

```
Item: minecraft:diamond
  Category: material
  Tier: 3
  Computed: 3
  Reason: vanilla base tier
  Paths: crafting
```

### JSON (`--json`)

```json
{
  "id": "minecraft:diamond",
  "category": "material",
  "lang_name": null,
  "tier": 3,
  "computed_tier": 3,
  "override_tier": null,
  "reason": "vanilla base tier",
  "paths": ["crafting"]
}
```

## Curated overrides

Create `tier-overrides.toml` in the pack directory to override computed tiers:

```toml
# Format: item_id = tier (0-7)
minecraft:diamond = 4
some-mod:ultra-rare-item = 7
```

Override values shown alongside computed values for transparency.

## When to use

- **When balancing loot tables** — verify items have appropriate rarity
- **When designing progression** — check tier distribution across the pack
- **When adding new items** — see how they compare to existing items
- **When debugging rarity** — check if items are over/under-valued

## Limitations

- Most mod items default to tier 3-4 (tag path signal is weak)
- Recipe ingredient resolution only works for items with explicit tier cache
- No cross-reference with mob drop loot tables yet
- Category fallback is rough (all mod "unknown" category = tier 4)

## RUN LOG

### 2026-09-07
- Created skill doc for item-tier.py tool.
- Tools: packwiz-item-tier (opencode), item-tier.py (standalone CLI), mc-pack.py item-tier.
- Tier scale: 0-7 (world-generated → ultra-rare/admin).
- Scoring: multi-path min, recipe tier = max(ingredient) + log bonus, tag weak signal, category fallback.
- Curated overrides via tier-overrides.toml.
