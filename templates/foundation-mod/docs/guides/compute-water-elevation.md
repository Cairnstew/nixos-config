# Custom Component: Computing Ground or Water Elevation

```lua
function MY_CUSTOM_COMPONENT:computeWaterElevation(_globalPosition)
    local raycastResult = {}
    local FromPosition = { _globalPosition[1], _globalPosition[2]+1000, _globalPosition[3] }
    local ToPosition = { _globalPosition[1], _globalPosition[2]-1000, _globalPosition[3] }
    if not self:getLevel():rayCast(FromPosition,
                                   ToPosition,
                                   raycastResult,
                                   2 ^ OBJECT_FLAG.WATER:toNumber())
    then
        MyMod:logWarning("Water not found on the vertical of " .. tostring(_globalPosition))
        return _globalPosition[2]
    else
        return raycastResult["Position"][2]
    end
end
```

Replace `OBJECT_FLAG.WATER` with `OBJECT_FLAG.GROUND` for ground elevation.

Note: Water doesn't have the same elevation at all points on a vanilla map.

guides/compute-water-elevation.txt · Last modified: 2021/02/23 11:52 by 127.0.0.1
