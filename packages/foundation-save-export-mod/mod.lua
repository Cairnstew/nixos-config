local myMod = foundation.createMod()

myMod:log("Loading " .. myMod:getModName() .. " v" .. myMod:getModVersion())

myMod:dofile("scripts/export.lua")

myMod:log("Mod loaded successfully.")
