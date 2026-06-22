local myMod = ...

myMod:log("Setting up jobs and workplaces.")

--[[
  Example: Register a new job
  See: docs/workplaces.md

local myJob = {
    Name = "MY_CUSTOM_JOB",
    DisplayName = "My Custom Job",
    Behavior = "BEHAVIOR_PRODUCE_WITH_GATHER",
    OutputResources = {
        { Resource = "MY_CUSTOM_RESOURCE", Quantity = 1 },
    },
    InputResources = {
        { Resource = "WOOD", Quantity = 2 },
    },
}

myMod:registerAsset(myJob)
]]
