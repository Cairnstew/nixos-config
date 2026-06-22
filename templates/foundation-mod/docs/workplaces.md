# Workplaces

A workplace is a building containing a BUILDING_FUNCTION_WORKPLACE.

## Example of declaring a workplace building function

```lua
mod:register({
    DataType = "BUILDING_PART",
    Id = "MITHRIL_FACTORY_EXTENSION_B_ROOT_PART",
    BuildingFunction = {
        DataType = "BUILDING_FUNCTION_WORKPLACE",
        WorkerCapacity = 1,
        RelatedJob = { Job = "MITHRIL_ARTISAN", Behavior = "WORK_BEHAVIOR" },
        InputInventoryCapacity = {{ Resource = "MITHRIL_ORE", Quantity = 30 }},
        ResourceListNeeded = {{ Resource = "MITHRIL_ORE", Quantity = 5 }},
        ResourceProduced = {{ Resource = "MITHRIL_NECKLACE", Quantity = 1 }}
    },
})
```

workplaces.txt · Last modified: 2019/09/26 17:08 by 127.0.0.1
