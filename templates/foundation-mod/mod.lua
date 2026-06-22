local myMod = foundation.createMod()

myMod:log("Loading " .. myMod:getModName() .. " v" .. myMod:getModVersion())

myMod:dofile("scripts/init.lua")
myMod:dofile("scripts/building.lua")
myMod:dofile("scripts/resource.lua")
myMod:dofile("scripts/jobs.lua")
myMod:dofile("scripts/events.lua")

myMod:log("Mod loaded successfully.")
