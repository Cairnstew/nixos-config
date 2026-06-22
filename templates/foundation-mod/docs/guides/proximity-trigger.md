# Custom Component: Proximity Trigger

```lua
local COMP_PROXIMITY_TRIGGER = {
    TypeName = "COMP_PROXIMITY_TRIGGER",
    ParentType = "COMPONENT",
    Properties = {}
}

function COMP_PROXIMITY_TRIGGER:update()
    local pos1 = self:getOwner():getGlobalPosition()

    self:getLevel():getComponentManager("COMP_AGENT"):getAllComponent():forEach(
        function(comp)
            local pos2 = comp:getOwner():getGlobalPosition()
            local distance = math.sqrt(
                (pos1.x - pos2.x)^2 +
                (pos1.y - pos2.y)^2 +
                (pos1.z - pos2.z)^2
            )
            if distance < 4 then
                -- Do fancy stuff
            end
        end
    )
end
```

guides/proximity-trigger.txt · Last modified: 2021/02/23 12:05 by 127.0.0.1
