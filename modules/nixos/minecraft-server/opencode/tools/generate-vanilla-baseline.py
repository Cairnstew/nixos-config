#!/usr/bin/env python3
"""Generate vanilla-attributes-baseline.json from an existing attributes-dump.json.

Prefers the "default_attributes" section from the dump (true per-entity vanilla
defaults read reflectively from DefaultAttributes.SUPPLIERS — e.g. cow has 10 HP,
not the generic 20 HP attribute default). Falls back to using the attribute's
base_value if the section isn't present (older dumps).

Input  (attributes-dump.json):
  {
    "attributes": { "attr_id": { "base_value": N, "entities": { "entity_id": N } } },
    "default_attributes": { "entity_id": { "attr_id": value, ... }, ... }  # optional
  }

Output (vanilla-attributes-baseline.json):
  { "entity_id": { "attr_id": value, ... }, ... }

Usage:
  python3 tools/generate-vanilla-baseline.py \
    modpacks/AllTheTech/attributes-dump.json \
    -o modpacks/AllTheTech/vanilla-attributes-baseline.json
"""

import argparse
import json
import sys
from pathlib import Path

# Import the vanilla entity set from mobs.py
sys.path.insert(0, str(Path(__file__).parent))
from mobs import VANILLA_BY_MC


def generate_baseline(dump_path: Path, mc_version: str = "1.21.1") -> dict:
    """Generate entity-centric baseline from an attributes dump.

    Prefers the "default_attributes" section from the dump (true vanilla defaults
    read reflectively from DefaultAttributes.SUPPLIERS — per-entity accurate values
    like cow having 10 HP, not the generic 20 HP attribute default).

    Falls back to using the attribute's base_value (generic registry default) if
    the "default_attributes" section is not present in the dump (older dumps).
    """
    with open(dump_path) as f:
        dump = json.load(f)

    # Get the vanilla entity set for this MC version
    # VANILLA_BY_MC structure: { "1.21.1": { "mobs": { "entity_id": {...} } } }
    version_table = VANILLA_BY_MC.get(mc_version)
    if version_table is None:
        available = sorted(VANILLA_BY_MC.keys())
        print(f"Error: no vanilla baseline table for MC {mc_version} (available: {', '.join(available)})")
        sys.exit(1)

    # Flatten all entity IDs from all sub-tables (e.g. "mobs", "biomes", etc.)
    vanilla_entities = set()
    for table_name, table in version_table.items():
        if isinstance(table, dict):
            vanilla_entities.update(table.keys())
        else:
            print(f"Warning: unexpected table type for {table_name}: {type(table)}")

    # Check for the new "default_attributes" section (true per-entity vanilla defaults)
    default_attrs = dump.get("default_attributes")
    if default_attrs is not None and isinstance(default_attrs, dict) and len(default_attrs) > 0:
        # Filter to only vanilla entities
        entity_attrs: dict[str, dict[str, float]] = {}
        for entity_id, attrs in default_attrs.items():
            if entity_id in vanilla_entities and isinstance(attrs, dict):
                entity_attrs[entity_id] = {k: float(v) for k, v in attrs.items() if isinstance(v, (int, float))}
        if entity_attrs:
            print(f"Using default_attributes section: {len(entity_attrs)} vanilla entities with true per-entity defaults")
            return {eid: dict(sorted(attrs.items())) for eid, attrs in sorted(entity_attrs.items())}
        else:
            print(f"Warning: default_attributes section present but empty for vanilla entities. Falling back to base_value approach.")

    # Fallback: use the attribute's base_value (generic registry default) as the
    # vanilla value for each attribute.
    print("Using attribute registry base_value as fallback for vanilla defaults")
    attr_base_values: dict[str, float] = {}
    for attr_id, attr_info in dump.get("attributes", {}).items():
        attr_base_values[attr_id] = attr_info.get("base_value", 0.0)

    # Build entity-centric baseline: for each vanilla entity, use the attribute's
    # base_value as the vanilla value (not the entity's actual value from the dump,
    # which may have been modified by mods).
    entity_attrs: dict[str, dict[str, float]] = {}

    for attr_id, attr_info in dump.get("attributes", {}).items():
        entities = attr_info.get("entities", {})
        base_val = attr_base_values[attr_id]
        for entity_id in entities.keys():
            if entity_id in vanilla_entities:
                if entity_id not in entity_attrs:
                    entity_attrs[entity_id] = {}
                entity_attrs[entity_id][attr_id] = base_val

    if not entity_attrs:
        print(f"Warning: no vanilla entities found in dump. Dump may be empty or use different entity IDs.")
        print(f"Vanilla table has {len(vanilla_entities)} entities for MC {mc_version}.")
        # Show a few entity IDs from the dump for debugging
        sample = list(dump.get("attributes", {}).values())[0].get("entities", {})
        print(f"Sample entity IDs in dump: {list(sample.keys())[:5]}")
        print(f"Sample vanilla IDs: {list(vanilla_entities)[:5]}")
        sys.exit(1)

    # Sort for deterministic output
    baseline = {eid: dict(sorted(attrs.items())) for eid, attrs in sorted(entity_attrs.items())}
    return baseline


def main():
    parser = argparse.ArgumentParser(description="Generate vanilla attribute baseline from existing dump")
    parser.add_argument("dump_json", help="Path to attributes-dump.json")
    parser.add_argument("-o", "--output", help="Output path (default: vanilla-attributes-baseline.json in same dir)")
    parser.add_argument("--mc-version", default="1.21.1", help="Minecraft version (default: 1.21.1)")
    args = parser.parse_args()

    dump_path = Path(args.dump_json)
    if not dump_path.exists():
        print(f"Error: dump file not found: {dump_path}")
        sys.exit(1)

    output_path = Path(args.output) if args.output else dump_path.parent / "vanilla-attributes-baseline.json"

    baseline = generate_baseline(dump_path, args.mc_version)

    with open(output_path, "w") as f:
        json.dump(baseline, f, indent=2)

    n_entities = len(baseline)
    n_attrs = sum(len(a) for a in baseline.values())
    print(f"Wrote {n_entities} vanilla entities ({n_attrs} attribute values) to {output_path}")


if __name__ == "__main__":
    main()
