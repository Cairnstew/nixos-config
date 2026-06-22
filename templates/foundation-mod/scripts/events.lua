local myMod = ...

myMod:log("Setting up event handlers.")

--[[
  Example: Register event handlers
  See: docs/events.md

function myMod:onGameStarted()
    myMod:log("Game started!")
end

function myMod:onResourceGained(args)
    myMod:log("Resource gained: " .. tostring(args.Resource) .. " x" .. tostring(args.Quantity))
end

myMod:registerEvent(EVENT.GAME_STARTED, "onGameStarted")
myMod:registerEvent(EVENT.RESOURCE_GAINED, "onResourceGained")
]]
