# Asset Override

All game assets (and other mods assets) can be override by mods, partially or totally.

The `mod:override` function should be used for that purpose.

## Overriding specific values

```lua
myMod:override({
    Id = "DEFAULT_BALANCING",
    InitialFamilyCount = 1,
    MinimumHappinessForLeaving = 30
})
```

## List OVERRIDE / APPEND

By default, overriding a property of type List will completely replace the list:

```lua
myMod:override({
    Id = "VILLAGE_LIST_DEFAULT",
    TradingVillageList = {
        "VILLAGE_AVIGNON"
    }
})
```

You can append values:

```lua
myMod:override({
    Id = "VILLAGE_LIST_DEFAULT",
    TradingVillageList = {
        Action = "APPEND",
        "VILLAGE_AVIGNON"
    }
})
```

## FBX asset override

You can override materials generated from textures when importing a 3D model:

```lua
mod:registerAssetId("models/fountain.fbx/Materials/FountainColor", "FOUNTAIN_COLOR_MATERIAL")
mod:override({
    Id = "FOUNTAIN_COLOR_MATERIAL",
    HasAlphaTest = true
})
```

## Related features not yet implemented

- Removing specific items from a list

asset-override.txt · Last modified: 2019/09/26 17:09 by 127.0.0.1
