local myMod = ...

myMod:log("Setting up building assets.")

--[[
  Example: Register a new building
  See: docs/asset-override.md and docs/workplaces.md

local myBuilding = {
    Name = "MY_NEW_BUILDING",
    DisplayName = "My New Building",
    BuildingType = BUILDING_TYPE.GENERAL,
    Prefab = "path/to/prefab.prefab",
    BuildMenuConfig = BUILD_MENU_CONFIG.RESOURCES,
    Categories = { BUILDING_CATEGORY.PRODUCTION },
    ConstructionSteps = {
        {
            Materials = {
                { Resource = "WOOD", Quantity = 20 },
                { Resource = "STONE", Quantity = 10 },
            },
            WorkDuration = 10.0,
        },
    },
}

myMod:registerAsset(myBuilding)
]]
