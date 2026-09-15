---
name: mc-item-components
description: Use when asked about the registered default DataComponents a packwiz modpack's items carry — attribute modifiers (weapon/armor stat bonuses), enchantability, tool mining data, food nutrition/saturation, max stack size. Use packwiz-item-components / the standalone item-components.py to inspect what components an item actually registers (real reflected values from an isolated NeoForge server dump), before deciding impact for RarityCore, verifying a mod's item stats, or planning item-tier impact scoring. Note: the component dump regenerates via the same isolated NeoForge server harness as attributes-regenerate (~30s server runtime + Nix FOD builds); the consumer tool reads the cached JSON instantly.
---

# Mod Item Components Review (packwiz)

Inventory and review the default **DataComponents** a packwiz modpack under
`modules/nixos/minecraft-server/modpacks/<name>/` registers on every item.
These are the vanilla/NeoForge component values each item ships with:
`minecraft:max_stack_size`, `minecraft:attribute_modifiers`,
`minecraft:tool`, `minecraft:food`, plus a complete `component_keys` list.

This is a two-phase system:
1. **Regenerate** (`item-components-regenerate`) — launches an isolated NeoForge
   server with the pack's real mods via the **same launch/heap/logging harness as
   the attributes dump** (`attributes_dump.py --dump-mod item-components-dump`).
   The Java dump mod (`source-patches/item-components-dump/ItemComponentsDump.java`)
   reflects each `Item.components()` map on `FMLLoadCompleteEvent` and writes
   `item-components-dump.json`. ~30s server runtime + Nix FOD builds, cached after
   the first run. Re-run after mod list changes.
2. **Read** (instant) — reads the cached JSON and renders the four component
   families plus a mining-level summary.

For broad pack work (adding/removing/updating mods, datapacks) load the
`mc-modpack` skill instead. This skill is the "what components does each item
actually register, and what does that imply for impact" review step. It is also
the data source behind `item-tier.py`'s `impact_score`.

## Tools

- **`packwiz-item-components`** (opencode tool) — the consumer in a session.
  Accepts `itemInfo` for single-item lookup, `mods=`, `list`, `json`,
  `fullExport`. Also accepts `itemComponentsRegenerate=true` for the slow-path
  dump (with `dryRun`).
- **`python3 modules/nixos/minecraft-server/opencode/tools/item-components.py`**
  (standalone CLI). Accepts a pack NAME (auto-resolved under the repo's
  modpacks/) or a path.
- `mc-pack.py <pack> item-components [flags]` / `item-components-info <id>` /
  `item-components-full-export` — same engine via mc-pack.py.
- The Java dump mod: `modules/nixos/minecraft-server/modpacks/<name>/source-patches/item-components-dump/`.

## Flags (CLI and opencode tool)

```
item-components.py <pack> [--list] [--info <id>] [--json] [--full-export [file]] [--mods slug1,slug2]
  --list           print item IDs one per line
  --info <id>      detailed component profile for one item (fuzzy match)
  --json           machine-readable JSON
  --full-export    write every item's component summary to a JSON file
  --mods           restrict to item-id namespaces (e.g. 'artifacts,relics' or 'minecraft')
```

## What the dump reflects

For each registered item (`BuiltInRegistries.ITEM.entrySet()`) we dump the
default `item.components()` map (the pristine per-type values, before any stack
patching):

| Signal | Source | Notes |
|--------|--------|-------|
| `max_stack_size` | `DataComponents.MAX_STACK_SIZE` | default 64; stack-size-1 items are disproportionately unique/significant |
| `attribute_modifiers` | `DataComponents.ATTRIBUTE_MODIFIERS` (type `ItemAttributeModifiers`) | each `Entry`: attribute holder id, `AttributeModifier.amount()`, `operation()` (ADD_VALUE/…), `EquipmentSlotGroup.getSerializedName()` |
| `enchantable` | `Item.getEnchantmentValue()` | **1.21.1 has no `ENCHANTABLE` DataComponent** — enchantability is an Item method, not a component |
| `tool` | `DataComponents.TOOL` (type `Tool`) | `defaultMiningSpeed()`, `damagePerBlock()`, each `Rule.blocks()`/`speed()`/`correctForDrops()`; mining_level 0–4 derived from `incorrect_for_*_tool` rules |
| `food` | `DataComponents.FOOD` (type `FoodProperties`) | `nutrition()`, `saturation()` |
| `component_keys` | `DataComponentMap.keySet()` | every component present (for completeness / future signals) |

## Example output (`--info minecraft:diamond_pickaxe`)

```
Item: minecraft:diamond_pickaxe
  Max stack size: 1
  Enchantable: 10
  Attribute modifiers (2):
    minecraft:generic.attack_damage +4.0 (ADD_VALUE) slot=mainhand
    minecraft:generic.attack_speed -2.8 (ADD_VALUE) slot=mainhand
    attack_damage=4.0 attack_speed=2.8 armor=0 magnitude=6.8
  Tool: mining_level=4 speed=1.0 dmg/block=1
    rule: blocks=tag|minecraft:incorrect_for_diamond_tool speed=None correct=False
    rule: blocks=tag|minecraft:mineable/pickaxe speed=8.0 correct=True
  Food: (none)
  Component keys (9): ...
```

> `incorrect_for_diamond_tool` is the 1.21.1 mining-tier signal (the inverted
> "needs diamond" tag): a pickaxe marked `incorrect_for_diamond_tool` is a
> diamond-tier tool → `mining_level=4`. Plain blocks (e.g. `minecraft:stone`)
> show just the generic always-present components (max_stack_size/lore/
> enchantments/repair_cost/attribute_modifiers/rarity) and no tool/food —
> that emptiness is itself the signal for "low-impact decorative item".

## Regenerating after mod changes

```
mc-pack.py <pack> item-components-regenerate
# or the opencode tool: packwiz-item-components itemComponentsRegenerate=true
```

Flags: `--dry-run` (print plan only), `--timeout N` (server timeout, default
1800s), `--keep-on-failure`. Reuses `attributes_dump.py` — see
`skill-mc-mod-attributes.md` for the launch/harness RUN LOG history.

## When to use

- **Before deciding impact for RarityCore** — an endgame weapon shows up via
  attribute magnitude + enchantability, a food via nutrition/saturation, a
  decorative block via near-empty components.
- **Verifying a mod's item stats** — confirm attack damage / armor / food values
  actually shipped by the pinned jar (real reflected values, not docs).
- **Feeding item-tier's impact axis** — item-tier.py consumes this dump for its
  `impact_score`.

## Limitations / Gotchas

- The dump is **per-type default components**, not per-stack. Enchantments a
  player adds, damage applied, etc. are stack components and NOT reflected here.
- `mod_list_hash` is `unavailable` when the pack's `index.toml` isn't visible to
  the sandboxed server (credentials/osirion config can mask the packwiz dir) —
  the values themselves are still real.
- ~22200 items → 8.5MB JSON; insta-loads in the consumer.
- Regeneration is SLOW: it builds the dump-mod FOD once (Gradle+MDG in the Nix
  FOD, first run ~2 min) and then runs the server with all 280+ pack mods
  (~30s JVM). Only re-run after mod list changes.

## RUN LOG

### 2026-09-13 — created (ItemComponentsDump.java + consumer + item-tier impact axis)
- Added `source-patches/item-components-dump/` — mirrors the attributes-dump mod
  but reflects each `Item.components()` map on FMLLoadCompleteEvent and writes
  `item-components-dump.json`. Compiled against the verified 1.21.1 official API
  (item `components()` field, `DataComponents.{MAX_STACK_SIZE,ATTRIBUTE_MODIFIERS,FOOD,TOOL}`,
  `ItemAttributeModifiers.Entry.attribute/modifier/slot`, `Tool.Rule.blocks()`
  HolderSet, no `ENCHANTABLE` DataComponent — it's `Item.getEnchantmentValue()`).
- `attributes_dump.py` gained `--dump-mod` (default `attributes-dump`) so the
  item-components dump reuses the exact launch/heap/logging harness — no copy-paste.
- Consumer: `item-components.py` (4-part shape) + `mc-pack.py`
  item-components-regenerate/item-components/item-components-info/
  item-components-full-export + `packwiz-item-components.ts`.
- Verified real reflected values on AllTheTech: diamond_sword (%6.0/-2.4,
  enchantable 10, stack 1), diamond_pickaxe (mining_level=4 via
  `incorrect_for_diamond_tool`), apple (nutrition=4/saturation=2.4), stone
  (no meaningful components). 22202 items, 8.5MB dump.