#!/usr/bin/env python3
"""Attributes CLI — read the cached entity-attributes dump and provide an
entity-centric view with source classification.

Standalone, stdlib-only. Works against any packwiz pack dir (the repo's live
under modules/nixos/minecraft-server/modpacks/<name>/), reading the cached
attributes-dump.json produced by attributes_dump.py (or mc-pack attributes-regenerate).

Usage (manual):
  python3 attributes.py <pack> [--list] [--info <id>] [--json]
                               [--full-export [outfile]] [--no-vanilla]
  <pack>            pack name (auto-resolved under the repo's modpacks/) or a
                    path to a packwiz pack dir.
  --list            print just the entity ids, one per line (fastest for
                    piping/scripts); add --no-vanilla for only mod-added ones.
  --info <id>       full attribute profile for a single entity (fuzzy match).
  --json            machine-readable JSON document (stable schema, see below).
  --full-export [f] write every entity's full metadata to a single JSON file.
                    If f is omitted, defaults to <packname>-attributes-full.json.
  --no-vanilla      omit vanilla entities (only show modded-added).
  --attribute <name> filter --info to show only this attribute (can repeat).

The dump file is attribute-centric (attribute → entity → value). This tool
transposes it to entity-centric (entity → attribute → value) which is the
natural view for modpack debugging.

Source classification (3-way, requires vanilla-attributes-baseline.json):
  vanilla           Entity is vanilla AND its attributes match the vanilla
                    baseline exactly (no mod touched any attribute).
  vanilla_modified  Entity is vanilla but one or more attributes differ from
                    the vanilla baseline (a mod changed its stats).
  modded            Entity has no vanilla baseline entry at all — wholly new
                    entity type added by a mod.

Non-default detection uses the correct baseline per case:
  vanilla/vanilla_modified: compared against the entity's own vanilla baseline
    value (from vanilla-attributes-baseline.json).
  modded: compared against the attribute's registered base_value (the generic
    attribute default — no per-entity vanilla baseline exists).

If vanilla-attributes-baseline.json is absent, falls back to 2-way
classification (vanilla/modded) with attribute-registry-base comparison.

Note: the dump contains every registered attribute for every entity, including
inherited/resolved values from the NeoForge attribute system. Most entities
have 80-100 attributes, most of which are at their default value. The --info
view highlights non-default values to surface what's actually interesting.

Baseline generation: the dump mod now outputs a "default_attributes" section with
true per-entity vanilla defaults from DefaultAttributes.SUPPLIERS (read reflectively).
Contains values like cow having 10 HP (not the generic attribute default of 20 HP).
generate-vanilla-baseline.py prefers this section when present.

If the "default_attributes" section is absent (older dump without the reflection
patch), falls back to using the attribute's base_value (generic registry default),
which has the limitation that vanilla entities with naturally different values
(e.g. cow has 10 HP, not 20) will show as "vanilla_modified" without mod interference.

Self-improvement: this file lives in the repo at
modules/nixos/minecraft-server/opencode/tools/attributes.py (scoped-exception
dir — direct RUN LOG edits are expected). Append dated fixes to the
// ## RUN LOG-style block at the end of THIS file.
"""

import json
import os
import sys
from pathlib import Path

# ── Vanilla mobs baseline (imported from mobs.py) ──────────────────────────
# We only need the entity ID sets, not the full metadata.

def _load_vanilla_entities() -> set[str]:
    """Load vanilla entity IDs from mobs.py's VANILLA_BY_MC for MC 1.21.1."""
    try:
        import importlib.util
        mobs_path = Path(__file__).parent / "mobs.py"
        spec = importlib.util.spec_from_file_location("mobs", str(mobs_path))
        mobs = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mobs)
        ver_data = mobs.VANILLA_BY_MC.get("1.21.1")
        if not ver_data:
            return set()
        return set(ver_data.get("mobs", {}).keys())
    except Exception:
        return set()


VANILLA_ENTITIES = _load_vanilla_entities()


def _load_vanilla_baseline(pack_dir: Path) -> dict[str, dict[str, float]] | None:
    """Load vanilla-attributes-baseline.json if it exists.

    Returns entity-centric view: { "entity:id": { "attr:name": value, ... } }
    or None if the baseline file doesn't exist.
    """
    baseline_path = pack_dir / "vanilla-attributes-baseline.json"
    if not baseline_path.exists():
        return None
    try:
        with open(baseline_path) as f:
            data = json.load(f)
        # Detect format: attribute-centric has an "attributes" key, entity-centric has entity IDs as keys
        if "attributes" in data:
            return transpose_to_entity_centric(data)
        else:
            # Already entity-centric (generated by generate-vanilla-baseline.py)
            return data
    except Exception:
        return None


# ── Helpers ─────────────────────────────────────────────────────────────────

def die(msg: str) -> None:
    print(f"attributes: {msg}", file=sys.stderr)
    sys.exit(1)


def resolve_pack(path_or_name: str) -> Path:
    """Resolve a pack name or path to the packwiz pack directory."""
    p = Path(path_or_name).resolve()
    if (p / "pack.toml").exists():
        return p
    # Try under repo modpacks/
    try:
        import subprocess
        out = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL, text=True
        ).strip()
        repo = Path(out)
    except Exception:
        repo = Path(__file__).resolve().parent.parent.parent.parent
    pack = repo / "modules/nixos/minecraft-server/modpacks" / path_or_name
    if (pack / "pack.toml").exists():
        return pack
    die(f"pack not found: {path_or_name}")


def load_dump(pack_dir: Path) -> dict:
    """Load the cached attributes-dump.json from the pack directory."""
    dump_path = pack_dir / "attributes-dump.json"
    if not dump_path.exists():
        die(
            f"attributes-dump.json not found in {pack_dir}\n"
            f"Run: python3 mc-pack.py {pack_dir.parent.name} attributes-regenerate"
        )
    with open(dump_path) as f:
        return json.load(f)


def transpose_to_entity_centric(dump: dict) -> dict[str, dict[str, float]]:
    """Transpose the attribute-centric dump to entity-centric view.

    Input:  { "attributes": { "attr:name": { "base_value": 0.0, "entities": { "entity:id": value } } } }
    Output: { "entity:id": { "attr:name": value, ... }, ... }
    """
    entities: dict[str, dict[str, float]] = {}
    for attr_name, attr_info in dump.get("attributes", {}).items():
        base = attr_info.get("base_value", 0.0)
        for entity_id, value in attr_info.get("entities", {}).items():
            if entity_id not in entities:
                entities[entity_id] = {}
            entities[entity_id][attr_name] = value
    return entities


def classify_entity(
    entity_id: str,
    pack_attrs: dict[str, float] | None = None,
    vanilla_baseline: dict[str, dict[str, float]] | None = None,
) -> str:
    """Classify an entity as vanilla, vanilla_modified, or modded.

    Classification:
      vanilla — entity is in VANILLA_ENTITIES AND (no baseline exists, OR all
                baseline attributes match the baseline exactly AND no extra
                mod-added attributes are present on the entity).
      vanilla_modified — entity is in VANILLA_ENTITIES and baseline exists and
                         one or more attributes differ from the baseline, OR
                         one or more custom mod-added attributes are present
                         on the entity that don't exist in the baseline at all.
                         Even a single extra custom attribute (e.g.
                         epicfight:impact = 1.0 on a zombie) means the entity
                         has been modified — its vanilla stat block is no
                         longer pure.
      modded — entity is not in VANILLA_ENTITIES at all.

    Rationale for the broad (custom-attrib-counts) check: a mod that layers
    new mechanics on a vanilla entity (effectively adding new stats to its
    combat profile) has modified it just as meaningfully as one that tweaks
    a vanilla stat. A zombie with epicfight:impact=1.0 and
    apothic_attributes:crit_chance=0.05 is different from vanilla, and the
    classification should reflect that.
    """
    if entity_id not in VANILLA_ENTITIES:
        return "modded"
    if vanilla_baseline is None or pack_attrs is None:
        return "vanilla"
    baseline_attrs = vanilla_baseline.get(entity_id)
    if baseline_attrs is None:
        # Vanilla entity not in baseline (shouldn't happen if baseline is complete)
        return "vanilla"
    # Broad check: any attribute present on the entity but NOT in the baseline
    # counts as a modification (custom mod-added attributes).
    for attr_name in pack_attrs:
        if attr_name not in baseline_attrs:
            return "vanilla_modified"
    # Narrow check: any baseline attribute whose value differs.
    for attr_name, pack_value in pack_attrs.items():
        baseline_value = baseline_attrs.get(attr_name)
        if baseline_value is not None and pack_value != baseline_value:
            return "vanilla_modified"
    return "vanilla"


def entity_source_mod(entity_id: str) -> str | None:
    """Extract the mod namespace from an entity ID."""
    if ":" in entity_id:
        return entity_id.split(":")[0]
    return None


def _baseline_value(
    entity_id: str,
    attr_name: str,
    pack_attrs: dict[str, float],
    vanilla_baseline: dict[str, dict[str, float]] | None,
    attr_bases: dict[str, float],
) -> float:
    """Return the correct baseline value for comparison.

    For vanilla/vanilla_modified entities: use the entity's own vanilla baseline
    if the attribute exists in it; otherwise fall back to the attribute registry
    base (for custom mod-added attributes that were never in vanilla at all).
    For modded entities (or missing baseline): use the attribute's registry base.
    """
    if vanilla_baseline is not None:
        baseline_attrs = vanilla_baseline.get(entity_id)
        if baseline_attrs is not None and attr_name in baseline_attrs:
            return baseline_attrs[attr_name]
    return attr_bases.get(attr_name, 0.0)


def _baseline_label(
    entity_id: str,
    attr_name: str,
    source: str,
    vanilla_baseline: dict[str, dict[str, float]] | None,
) -> str:
    """Return a human-readable label for what the baseline is.

    Per-attribute precision: if the attribute exists in the entity's vanilla
    baseline entry, label it "vanilla baseline". Otherwise it's a custom
    mod-added attribute and the best reference is the "attribute default".
    """
    if source in ("vanilla", "vanilla_modified") and vanilla_baseline is not None:
        baseline_attrs = vanilla_baseline.get(entity_id)
        if baseline_attrs is not None and attr_name in baseline_attrs:
            return "vanilla baseline"
    return "attribute default"


# ── Formatting ──────────────────────────────────────────────────────────────

def format_attribute_value(name: str, value: float, base: float, label: str = "base") -> str:
    """Format an attribute value, highlighting non-defaults."""
    if value == base:
        return f"  {name}: {value}"
    return f"  {name}: {value}  ({label}: {base})"


def print_entity_info(
    entity_id: str,
    attributes: dict[str, float],
    attr_bases: dict[str, float],
    vanilla_baseline: dict[str, dict[str, float]] | None = None,
    show_all: bool = False,
    filter_attrs: list[str] | None = None,
) -> None:
    """Print detailed attribute info for a single entity."""
    source = classify_entity(entity_id, attributes, vanilla_baseline)
    mod = entity_source_mod(entity_id)
    mod_label = f" [{mod}]" if mod else ""

    print(f"Entity: {entity_id}{mod_label}")
    print(f"  Source: {source}")
    print()

    # Count custom mod attributes (present on entity but not in baseline)
    custom_attrs = []
    if vanilla_baseline is not None:
        baseline_attrs = vanilla_baseline.get(entity_id, {})
        for name in attributes:
            if name not in baseline_attrs:
                custom_attrs.append(name)
    if custom_attrs:
        print(f"  Custom mod attributes ({len(custom_attrs)}): "
              f"{', '.join(sorted(custom_attrs)[:8])}{'...' if len(custom_attrs) > 8 else ''}")
        print()

    # Filter attributes if requested
    items = sorted(attributes.items())
    if filter_attrs:
        items = [(k, v) for k, v in items if any(f in k for f in filter_attrs)]

    if show_all:
        print(f"  All attributes ({len(items)}):")
        for name, value in items:
            base = _baseline_value(entity_id, name, attributes, vanilla_baseline, attr_bases)
            lbl = _baseline_label(entity_id, name, source, vanilla_baseline)
            print(format_attribute_value(name, value, base, label=lbl))
    else:
        # Show non-default attributes (value != baseline)
        non_default = []
        for name, value in items:
            base = _baseline_value(entity_id, name, attributes, vanilla_baseline, attr_bases)
            if value != base:
                non_default.append((name, value, base))

        if non_default:
            print(f"  Non-default attributes ({len(non_default)}):")
            for name, value, base in non_default:
                lbl = _baseline_label(entity_id, name, source, vanilla_baseline)
                print(format_attribute_value(name, value, base, label=lbl))
        else:
            print("  All baseline attributes match — differences are from custom mod-added attributes only.")

        remaining = len(items) - len(non_default)
        if remaining > 0:
            print(f"\n  ({remaining} attributes at baseline — use --show-all to view)")


def print_list(
    entity_centric: dict[str, dict[str, float]],
    no_vanilla: bool = False,
    vanilla_baseline: dict[str, dict[str, float]] | None = None,
    attr_bases: dict[str, float] | None = None,
) -> None:
    """Print entity IDs, one per line."""
    for entity_id in sorted(entity_centric.keys()):
        source = classify_entity(entity_id, entity_centric.get(entity_id), vanilla_baseline)
        if no_vanilla and source in ("vanilla", "vanilla_modified"):
            continue
        print(entity_id)


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Read the cached entity-attributes dump and provide an entity-centric view"
    )
    parser.add_argument("pack", help="Pack name or path")
    parser.add_argument("--list", action="store_true", help="Print entity IDs only")
    parser.add_argument("--info", metavar="ID", help="Show full attribute profile for an entity")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--full-export", nargs="?", const=True, default=False,
                        metavar="FILE", help="Export full entity data to JSON file")
    parser.add_argument("--no-vanilla", action="store_true", help="Exclude vanilla entities")
    parser.add_argument("--attribute", action="append", dest="filter_attrs", default=[],
                        help="Filter --info to specific attribute(s) (substring match)")
    parser.add_argument("--show-all", action="store_true",
                        help="Show all attributes including defaults in --info")
    args = parser.parse_args()

    pack_dir = resolve_pack(args.pack)
    dump = load_dump(pack_dir)
    entity_centric = transpose_to_entity_centric(dump)

    # Load vanilla baseline for 3-way classification
    vanilla_baseline = _load_vanilla_baseline(pack_dir)
    if vanilla_baseline is not None:
        print(f"Loaded vanilla baseline: {len(vanilla_baseline)} entities", file=sys.stderr)
    else:
        print(f"No vanilla-attributes-baseline.json — using 2-way classification", file=sys.stderr)

    # Build attribute base values (from any entity — they're consistent per attribute)
    attr_bases: dict[str, float] = {}
    for attr_name, attr_info in dump.get("attributes", {}).items():
        attr_bases[attr_name] = attr_info.get("base_value", 0.0)

    # ── --list ────────────────────────────────────────────────────────────
    if args.list:
        print_list(entity_centric, no_vanilla=args.no_vanilla,
                   vanilla_baseline=vanilla_baseline, attr_bases=attr_bases)
        return

    # ── --info ────────────────────────────────────────────────────────────
    if args.info:
        # Fuzzy match on entity ID
        target = args.info
        if target in entity_centric:
            match = target
        else:
            # Try substring match
            candidates = [e for e in entity_centric if target in e]
            if len(candidates) == 1:
                match = candidates[0]
            elif len(candidates) > 1:
                die(f"ambiguous entity '{target}': {', '.join(sorted(candidates)[:5])}")
            else:
                die(f"entity '{target}' not found in dump")

        print_entity_info(
            match,
            entity_centric[match],
            attr_bases,
            vanilla_baseline=vanilla_baseline,
            show_all=args.show_all,
            filter_attrs=args.filter_attrs,
        )
        return

    # ── --full-export ─────────────────────────────────────────────────────
    if args.full_export is not False:
        export_data = {
            "modpack": pack_dir.name,
            "mc_version": dump.get("mc_version"),
            "neoforge_version": dump.get("neoforge_version"),
            "generated_at": dump.get("generated_at"),
            "entity_count": len(entity_centric),
            "attribute_count": len(attr_bases),
            "has_vanilla_baseline": vanilla_baseline is not None,
            "entities": {},
        }
        for entity_id in sorted(entity_centric.keys()):
            attrs = entity_centric[entity_id]
            source = classify_entity(entity_id, attrs, vanilla_baseline)
            if args.no_vanilla and source in ("vanilla", "vanilla_modified"):
                continue
            non_default = {
                k: v for k, v in sorted(attrs.items())
                if v != _baseline_value(entity_id, k, attrs, vanilla_baseline, attr_bases)
            }
            export_data["entities"][entity_id] = {
                "source": source,
                "mod": entity_source_mod(entity_id),
                "attribute_count": len(attrs),
                "non_default_count": len(non_default),
                "attributes": {k: v for k, v in sorted(attrs.items())},
                "non_default": non_default,
            }

        outfile = args.full_export if isinstance(args.full_export, str) else None
        if not outfile:
            outfile = f"{pack_dir.name}-attributes-full.json"
        outpath = pack_dir / outfile if not os.path.isabs(outfile) else Path(outfile)
        with open(outpath, "w") as f:
            json.dump(export_data, f, indent=2)
        print(f"Wrote {outpath} ({len(export_data['entities'])} entities)")
        return

    # ── --json (default human output) ─────────────────────────────────────
    if args.json:
        out = {
            "modpack": pack_dir.name,
            "mc_version": dump.get("mc_version"),
            "neoforge_version": dump.get("neoforge_version"),
            "generated_at": dump.get("generated_at"),
            "entity_count": len(entity_centric),
            "attribute_count": len(attr_bases),
            "has_vanilla_baseline": vanilla_baseline is not None,
            "entities": {},
        }
        for entity_id in sorted(entity_centric.keys()):
            attrs = entity_centric[entity_id]
            source = classify_entity(entity_id, attrs, vanilla_baseline)
            if args.no_vanilla and source in ("vanilla", "vanilla_modified"):
                continue
            non_default = {
                k: v for k, v in sorted(attrs.items())
                if v != _baseline_value(entity_id, k, attrs, vanilla_baseline, attr_bases)
            }
            out["entities"][entity_id] = {
                "source": source,
                "mod": entity_source_mod(entity_id),
                "non_default_count": len(non_default),
                "non_default": non_default,
            }
        json.dump(out, sys.stdout, indent=2)
        print()
        return

    # ── Default human output ──────────────────────────────────────────────
    vanilla = []
    vanilla_modified = []
    modded = []
    for entity_id in sorted(entity_centric.keys()):
        attrs = entity_centric[entity_id]
        source = classify_entity(entity_id, attrs, vanilla_baseline)
        if source == "vanilla":
            vanilla.append(entity_id)
        elif source == "vanilla_modified":
            vanilla_modified.append(entity_id)
        else:
            modded.append(entity_id)

    print(f"Entity Attributes — {pack_dir.name}")
    print(f"  MC {dump.get('mc_version')} / NeoForge {dump.get('neoforge_version')}")
    print(f"  Generated: {dump.get('generated_at')}")
    print(f"  Entities: {len(vanilla)} vanilla + {len(vanilla_modified)} vanilla_modified + {len(modded)} modded = {len(vanilla) + len(vanilla_modified) + len(modded)} total")
    print(f"  Attributes: {len(attr_bases)}")
    if vanilla_baseline is not None:
        print(f"  Vanilla baseline: loaded ({len(vanilla_baseline)} entities)")
    print()

    if vanilla and not args.no_vanilla:
        print(f"── Vanilla entities ({len(vanilla)}) ──")
        for eid in vanilla:
            attrs = entity_centric[eid]
            non_default = sum(
                1 for k, v in attrs.items()
                if v != _baseline_value(eid, k, attrs, vanilla_baseline, attr_bases)
            )
            label = f"  {non_default} non-default" if non_default else ""
            print(f"  {eid}{label}")
        print()

    if vanilla_modified and not args.no_vanilla:
        print(f"── Vanilla modified ({len(vanilla_modified)}) ──")
        for eid in vanilla_modified:
            attrs = entity_centric[eid]
            non_default = sum(
                1 for k, v in attrs.items()
                if v != _baseline_value(eid, k, attrs, vanilla_baseline, attr_bases)
            )
            label = f"  {non_default} non-default" if non_default else ""
            print(f"  {eid}{label}")
        print()

    print(f"── Modded entities ({len(modded)}) ──")
    # Group by mod
    by_mod: dict[str, list[str]] = {}
    for eid in modded:
        mod = entity_source_mod(eid) or "unknown"
        by_mod.setdefault(mod, []).append(eid)
    for mod in sorted(by_mod):
        entities = by_mod[mod]
        print(f"  [{mod}] ({len(entities)}):")
        for eid in sorted(entities):
            attrs = entity_centric[eid]
            non_default = sum(
                1 for k, v in attrs.items()
                if v != _baseline_value(eid, k, attrs, vanilla_baseline, attr_bases)
            )
            label = f"  ({non_default} non-default)" if non_default else ""
            print(f"    {eid}{label}")
    print()


if __name__ == "__main__":
    main()
