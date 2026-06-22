# Building Asset Processor

You can register a BUILDING_ASSET_PROCESSOR on any FBX to partially automatize the configuration of your building or monument building part nodes.

```lua
mod:registerAssetProcessor("models/MithrilFactory.fbx", {
    DataType = "BUILDING_ASSET_PROCESSOR"
})
```

## Automatic part detection

Automatically adds COMP_BUILDING_PART to each node containing "Part" in their name.

## Automatic construction step link

Assigns ConstructionVisual if another node with the same name exists in a root node called `ConstructionSteps`.

## Automatic attach node detection and configuration

Adds COMP_BUILDING_ATTACH_NODE to nodes containing "Attach" in their name. ATTACH_NODE_TYPE values in the name determine the type; defaults to MINOR.

Note: Objects containing "Visual" in their name are currently ignored.

## Automatic path detection

Nodes with names starting with `PATH_` are interpreted as paths for the parent part. PATH nodes must be direct children of their parent part.

Paths are identified by a letter (e.g., `PATH_A_1`, `PATH_A_2`). Nodes can be shared between paths (e.g., `PATH_AB_1`).

Note: Automatic path setup doesn't allow setting a path's type. Paths need to be set up manually in COMP_BUILDING_PART.PathList.

building-asset-processor.txt · Last modified: 2025/06/27 12:15 by mathieu
