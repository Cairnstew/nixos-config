# How to Randomly set Doors and Windows on a Building

Example using BUILDING_CONSTRUCTOR_ASSEMBLAGE with random parts:

```lua
myMod:register({
    DataType = "BUILDING_PART",
    Id = "MY_BUILDING_PART",
    Mover = { DataType = "BUILDING_PART_MOVER_INSTANCE" },
    ConstructorData = {
        DataType = "BUILDING_CONSTRUCTOR_ASSEMBLAGE",
        CoreRandomBuildingPartList = { "MY_BUILDING_PREFAB" },
        MandatoryBuildingPartList = {
            { BuildingPart = "MY_DOOR_PART" },
            { BuildingPart = "MY_WINDOW_PART", Probability = 0.5 },
            { BuildingPart = "MY_WINDOW_PART", Probability = 0.5 },
            { BuildingPart = "MY_WINDOW_PART", Probability = 0.5 },
            { BuildingPart = "MY_WINDOW_PART", Probability = 0.5 }
        }
    }
})
```

Door parts use BUILDING_CONSTRUCTOR_RANDOM_PART to select from multiple models. Window parts work the same way.

guides/random_doors_and_windows.txt · Last modified: 2021/02/23 11:56 by 127.0.0.1
