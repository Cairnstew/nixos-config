# Monuments

Monuments are complex buildings that let the player assemble different building parts.

```lua
mod:register({
    DataType = "MONUMENT",
    Id = "MITHRIL_FACTORY_MONUMENT",
    Name = "MITHRIL_FACTORY_NAME",
    Description = "MITHRIL_FACTORY_DESC",
    BuildingType = "MONUMENT",
    BuildingPartList = {
        "MITHRIL_FACTORY_CORE_ROOT_PART",
        "MITHRIL_FACTORY_EXTENSION_A_ROOT_PART",
        "MITHRIL_FACTORY_EXTENSION_B_ROOT_PART",
        "MITHRIL_FACTORY_DOOR_A_PART",
        "MITHRIL_FACTORY_DOOR_B_PART",
        "MITHRIL_FACTORY_DECORATION_A_PART",
        "MITHRIL_FACTORY_DECORATION_B_PART"
    },
    RequiredPartList = {
        { Category = "CORE", Quantity = 1 },
        { Category = "EXTENSION", Quantity = 2 },
        { Category = "DOOR", Quantity = 1 }
    }
})
```

monuments.txt · Last modified: 2019/09/26 17:08 by 127.0.0.1
