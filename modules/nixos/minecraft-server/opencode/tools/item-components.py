#!/usr/bin/env python3
"""Item Components CLI — read the cached item-components-dump.json and provide
an item-centric view of registered default DataComponents.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the cached
item-components-dump.json produced by the item-components-dump headless-server
mod (launched via attributes_dump.py --dump-mod item-components-dump, or
mc-pack item-components-regenerate).

Usage (manual):
  python3 item-components.py <pack> [--list] [--info <id>] [--json]
                                     [--full-export [outfile]] [--mods slug1,slug2]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --list            print just the item ids, one per line (fastest for
                    piping/scripts).
  --info <id>       full component profile for a single item (fuzzy match).
  --json            machine-readable JSON document (stable schema, see below).
  --full-export [f] write every item's component metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-item-components-full.json.
  --mods            restrict to items whose id namespace matches one of these
                    slugs (comma-separated). 'minecraft' selects vanilla.

The dump is item-centric (item-id → components). This tool renders the four
component families the impact scorer in item-tier.py consumes, plus the full
component_keys list for completeness:
  max_stack_size      — DataComponents.MAX_STACK_SIZE (default 64).
  attribute_modifiers — weapon/armor stat bonuses: attribute, amount,
                        operation, equipment slot. Summarized as
                        attack_damage / armor / magnitude totals for --info.
  enchantable         — Item.getEnchantmentValue() (no ENCHANTABLE DataComponent
                        exists in 1.21.1 — it is an Item method, not a component).
  tool                — mining stats: default_mining_speed, damage_per_block,
                        and rules (blocks holder-set/tag, speed, correctForDrops).
                        Summarized as a mining_level 0..4 derived from the
                        "incorrect_for_*_tool" rules (the 1.21.1 mining-tier signal).
  food                — nutrition, saturation.

Regeneration is SLOW (~30s server runtime plus Nix FOD builds): re-run only when
mods change, exactly like attributes-regenerate. The consumer itself is instant.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/item-components.py (scoped-exception
dir — direct RUN LOG edits are expected). Append dated fixes to the
// ## RUN LOG-style block at the end of THIS file.
"""

import json
import os
import sys
from pathlib import Path

from datapack_common import die, resolve_pack_dir, fuzzy_match

TOOL = "item-components.py"


def _load_dump(pack_dir: Path) -> dict:
    dump_path = pack_dir / "item-components-dump.json"
    if not dump_path.exists():
        die(
            f"item-components-dump.json not found in {pack_dir}\n"
            f"Run: python3 mc-pack.py {pack_dir.parent.name} item-components-regenerate "
            f"(or python3 attributes_dump.py {pack_dir} --dump-mod item-components-dump)"
        )
    with open(dump_path) as f:
        return json.load(f)


def _mining_level(rules: list) -> int:
    """Derive a mining tier 0..4 from Tool rules.

    In 1.21.1 the tier signal is a 'incorrect_for_<tier>_tool' rule:
      wood   -> minecraft:incorrect_for_wooden_tool
      stone  -> minecraft:incorrect_for_stone_tool
      iron   -> minecraft:incorrect_for_iron_tool
      diamond-> minecraft:incorrect_for_diamond_tool
    (netherite reuses diamond's). The rules list contains these as
    'blocks=tag|minecraft:incorrect_for_*_tool' with correct_for_drops=False.
    """
    tier = 0
    for r in rules or []:
        b = r.get("blocks") or ""
        if "incorrect_for_wooden_tool" in b:
            tier = max(tier, 1)
        elif "incorrect_for_stone_tool" in b:
            tier = max(tier, 2)
        elif "incorrect_for_iron_tool" in b:
            tier = max(tier, 3)
        elif "incorrect_for_diamond_tool" in b:
            tier = max(tier, 4)
        elif "mineable/" in b:
            tier = max(tier, max(tier, 1))  # mineable tag implies at least wood tier
    return tier


def _summary(item_id: str, comp: dict) -> dict:
    """Build a compact per-item record suitable for tier/impact scoring."""
    ams = comp.get("attribute_modifiers", []) or []
    attack = sum(abs(m.get("amount", 0)) for m in ams
                 if m.get("attribute") == "minecraft:generic.attack_damage")
    attack_speed = sum(abs(m.get("amount", 0)) for m in ams
                       if m.get("attribute") == "minecraft:generic.attack_speed")
    armor = sum(abs(m.get("amount", 0)) for m in ams
                if "armor" in (m.get("attribute") or ""))
    magnitude = sum(
        abs(m.get("amount", 0)) for m in ams
        if m.get("operation") == "ADD_VALUE"
    )
    tool = comp.get("tool") or {}
    food = comp.get("food") or {}
    return {
        "id": item_id,
        "max_stack_size": comp.get("max_stack_size", 64),
        "attribute_modifiers": ams,
        "attack_damage": round(attack, 3),
        "attack_speed": round(attack_speed, 3),
        "armor": round(armor, 3),
        "modifier_magnitude": round(magnitude, 3),
        "enchantable": comp.get("enchantable", 0),
        "tool": {
            "default_mining_speed": tool.get("default_mining_speed"),
            "damage_per_block": tool.get("damage_per_block"),
            "mining_level": _mining_level(tool.get("rules", [])),
            "rules": tool.get("rules", []),
        },
        "food": food,
        "component_keys": comp.get("component_keys", []),
    }


def _iter_items(dump: dict, want_mods=None):
    items = dump.get("items", {})
    if not want_mods:
        return items
    filtered = {}
    for iid, comp in items.items():
        ns = iid.split(":", 1)[0]
        if "minecraft" in want_mods or ns in want_mods:
            filtered[iid] = comp
    return filtered


# ── CLI ───────────────────────────────────────────────────────────────────────

def cmd_list(items: dict):
    for iid in sorted(items.keys()):
        print(iid)


def cmd_info(items: dict, target: str, as_json=False):
    if target in items:
        comp = items[target]
    else:
        matches = fuzzy_match(target, list(items.keys()))
        if not matches:
            die(f"No item found matching '{target}'")
        if len(matches) > 1:
            die(f"Ambiguous '{target}'; did you mean: {', '.join(matches[:5])}")
        comp = items[matches[0]]
        target = matches[0]

    sumr = _summary(target, comp)
    if as_json:
        print(json.dumps(sumr, indent=2))
        return

    print(f"Item: {sumr['id']}")
    print(f"  Max stack size: {sumr['max_stack_size']}")
    print(f"  Enchantable: {sumr['enchantable']}")
    ams = sumr["attribute_modifiers"]
    if ams:
        print(f"  Attribute modifiers ({len(ams)}):")
        for m in ams:
            print(f"    {m['attribute']} {m['amount']:+.1f} ({m['operation']}) slot={m.get('slot')}")
        print(f"    attack_damage={sumr['attack_damage']} attack_speed={sumr['attack_speed']} "
              f"armor={sumr['armor']} magnitude={sumr['modifier_magnitude']}")
    else:
        print(f"  Attribute modifiers: (none)")
    tool = sumr["tool"]
    if tool.get("rules"):
        print(f"  Tool: mining_level={tool['mining_level']} "
              f"speed={tool['default_mining_speed']} dmg/block={tool['damage_per_block']}")
        for r in tool["rules"]:
            print(f"    rule: blocks={r.get('blocks')} speed={r.get('speed')} "
                  f"correct={r.get('correct_for_drops')}")
    else:
        print(f"  Tool: (none)")
    if sumr["food"]:
        f = sumr["food"]
        print(f"  Food: nutrition={f.get('nutrition')} saturation={f.get('saturation')}")
    else:
        print(f"  Food: (none)")
    print(f"  Component keys ({len(sumr['component_keys'])}): "
          f"{', '.join(sumr['component_keys'])}")


def cmd_json(items: dict):
    out = {iid: _summary(iid, comp) for iid, comp in sorted(items.items())}
    print(json.dumps(out, indent=2))


def cmd_full_export(items: dict, info, outfile, dump_meta: dict):
    out = {
        "tool": TOOL,
        "pack": info,
        "version": "1",
        "mod_list_hash": dump_meta.get("mod_list_hash"),
        "neoforge_version": dump_meta.get("neoforge_version"),
        "mc_version": dump_meta.get("mc_version"),
        "generated_at": dump_meta.get("generated_at"),
        "summary": {"item_count": len(items)},
        "entries": {iid: _summary(iid, comp) for iid, comp in sorted(items.items())},
    }
    with open(outfile, "w") as f:
        json.dump(out, f, indent=2, sort_keys=True)
        f.write("\n")
    size_kb = os.path.getsize(outfile) / 1024
    print(f"full-export: {len(items)} items → {outfile} ({size_kb:.0f} KB)", file=sys.stderr)


def main():
    pack = None
    as_list = False
    as_json = False
    info_target = None
    full_export = None
    want_mods = None
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        a = args[i]
        if a in ("--help", "-h"):
            print(__doc__)
            sys.exit(0)
        elif a == "--list":
            as_list = True
        elif a == "--json":
            as_json = True
        elif a == "--info":
            i += 1
            info_target = args[i]
        elif a == "--full-export":
            if i + 1 < len(args) and not args[i + 1].startswith("--"):
                i += 1
                full_export = args[i]
            else:
                full_export = True
        elif a == "--mods":
            i += 1
            want_mods = [m.strip().lower() for m in args[i].split(",")]
        elif not a.startswith("-"):
            pack = a
        else:
            die(f"Unknown option: {a}")
        i += 1

    if not pack:
        die("Usage: item-components.py <pack> [--list] [--info <id>] [--json] "
            "[--full-export [file]] [--mods slug1,slug2]")
    pack_dir = Path(resolve_pack_dir(pack))
    dump = _load_dump(pack_dir)
    items = _iter_items(dump, want_mods)
    info = {"name": os.path.basename(str(pack_dir).rstrip("/"))}

    if full_export is not None:
        outfile = full_export if isinstance(full_export, str) \
            else f"{info['name']}-item-components-full.json"
        cmd_full_export(items, info, outfile, dump)
    elif as_list:
        cmd_list(items)
    elif info_target:
        cmd_info(items, info_target, as_json)
    elif as_json:
        cmd_json(items)
    else:
        # default human-readable summary
        print(f"Item Components — {info['name']}")
        print(f"  Items: {len(items)}")
        stack1 = sum(1 for c in items.values() if c.get("max_stack_size") == 1)
        with_attr = sum(1 for c in items.values() if c.get("attribute_modifiers"))
        with_tool = sum(1 for c in items.values() if c.get("tool"))
        with_food = sum(1 for c in items.values() if c.get("food"))
        print(f"  Stack-size-1 items: {stack1}")
        print(f"  With attribute modifiers: {with_attr}")
        print(f"  With tool data: {with_tool}")
        print(f"  With food data: {with_food}")


if __name__ == "__main__":
    main()

# ## RUN LOG# ### 2026-09-13 — created with the item-components-dump headless mod
# Consumer for item-components-dump.json (ItemComponentsDump.java, launched via
# attributes_dump.py --dump-mod item-components-dump). Four-part shape
# (--list/--info/--json/--full-export) matching attributes.py. Summarizes each
# item's default DataComponents: max_stack_size, attribute modifiers
# (ItemAttributeModifiers.Entry -> attribute/amount/operation/slot), enchantable
# (Item.getEnchantmentValue — 1.21.1 has no ENCHANTABLE DataComponent), tool
# (mining_level 0-4 derived from 'incorrect_for_*_tool' rules, speed,
# damage_per_block), food nutrition/saturation, component_keys list.
# Verified on AllTheTech: 22202 items; diamond_sword attack 6/-2.4 + enchant 10;
# diamond_pickaxe mining_level 4; apple food 4/2.4; stone no meaningful components.
# item-tier.py consumes this dump for its impact_score component-magnitude axis.
