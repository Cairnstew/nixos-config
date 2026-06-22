local myMod = ...

myMod:log("Setting up resource assets.")

--[[
  Example: Register a new resource
  See: docs/custom-classes.md

local myResource = {
    Name = "MY_CUSTOM_RESOURCE",
    DisplayName = "My Custom Resource",
    ResourceType = RESOURCE_TYPE.RAW,
    Prefab = "path/to/resource.prefab",
    StackSize = 50,
}

myMod:registerAsset(myResource)
]]
