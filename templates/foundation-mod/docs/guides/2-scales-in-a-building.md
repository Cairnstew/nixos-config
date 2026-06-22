# Having 2 Scales on the same Building

```lua
-- Register the primary root part
myMod:register({
    DataType = "BUILDING_PART",
    Id = "MY_PRIMARY_ROOT_PART",
    Mover = { DataType = "BUILDING_PART_MOVER_INSTANCE" },
    ConstructorData = {
        DataType = "BUILDING_CONSTRUCTOR_SCALER",
        CoreObjectPrefab = "MY_PRIMARY_ROOT_PREFAB",
        EndPart = "MY_SECONDARY_ROOT_PART",
        FillerList = {
            "MY_PRIMARY_TILING3_PART",
            "MY_PRIMARY_TILING2_PART"
        },
        BasementFillerList = {
            "MY_PRIMARY_TILING1_PART"
        },
        MinimumScale = 1,
        BasementScale = 1
    }
})

-- Register the secondary root part
myMod:register({
    DataType = "BUILDING_PART",
    Id = "MY_SECONDARY_ROOT_PART",
    Mover = { DataType = "BUILDING_PART_MOVER_BRIDGE" },
    ConstructorData = {
        DataType = "BUILDING_CONSTRUCTOR_SCALER",
        CoreObjectPrefab = "MY_SECONDARY_ROOT_PREFAB",
        EndPart = "MY_SECONDARY_ROOT_TOP_PART",
        FillerList = {
            "MY_SECONDARY_ROOT_TILING3_PART",
            "MY_SECONDARY_ROOT_TILING2_PART"
        },
        MinimumScale = 0,
        BasementScale = 0
    }
})
```

Notes:
- `MY_PRIMARY` is the basis scale, `MY_SECONDARY` is the upper scale
- 2 green arrows appear

guides/2-scales-in-a-building.txt · Last modified: 2021/02/23 11:55 by 127.0.0.1
