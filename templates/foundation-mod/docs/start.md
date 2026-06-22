# Welcome to the Foundation Modding Wiki

**Warning**: Modding capabilities are very embryonic. Expect a lot of improvement and changes in the future.

- [Changelog](/foundation/modding/changelog)
- [Migration Notes](/foundation/modding/migration)
- [Community Guides](/foundation/modding/guides)

## More info on:

- [Data Types](/foundation/modding/data-types)
- [Enumerations](/foundation/modding/enumerations)
- [Annotations](/foundation/modding/annotations)
- [Example Mods](/foundation/modding/example-mods)
- [Game Texture Usage Policy](/foundation/modding/texture-usage-policy)
- [Debugging Mods](/foundation/modding/debugging-mods)
- [Foundation Library Functions](/foundation/modding/foundation-library-functions)
- [Mod Management Functions](/foundation/modding/mod-management-functions)
- [Version Library](/foundation/modding/version-library)
- [Mod IO Functions](/foundation/modding/mod-io-functions)
- [Mod Dependencies](/foundation/modding/dependencies)
- [Custom Classes](/foundation/modding/custom-classes)
- [Components](/foundation/modding/components)
- [Game Asset Override](/foundation/modding/asset-override)
- [Behavior Trees](/foundation/modding/behavior-trees)
- [Events](/foundation/modding/events)
- [Building Asset Processor](/foundation/modding/building-asset-processor)
- [Level Of Detail (LOD)](/foundation/modding/level-of-detail)
- [Create Workplaces](/foundation/modding/workplaces)
- [Create Monuments and Bridges](/foundation/modding/monuments)
- [Create Walls](/foundation/modding/walls)
- [Create Particle Effects](/foundation/modding/particle-effects)
- [Construction Steps](/foundation/modding/construction-steps)
- [Material Sets](/foundation/modding/material-sets)

## Where do I start?

- Create a new folder in `Documents\Polymorph Games\Foundation\mods`.
- Create a `mod.json` file and the main LUA script `mod.lua`.

## The mod.json file

```json
{
    "Name": "Simple Example Mod",
    "Author": "Leo",
    "Description": "A very simple mod example",
    "Version": "2.0.0",
    "MapList": [
        {
            "Id": "MY_MAP_ID_01",
            "Name": "My Custom Map",
            "Description": "This is a simple description of my map.",
            "PreviewImage": "metadata/my_map_preview.png"
        }
    ]
}
```

## metadata folder

For files that don't need to be loaded, add them to a `metadata` folder at the root of your mod.

## The mod.lua script

```lua
local myMod = foundation.createMod();
```

## Including other LUA files

```lua
myMod:dofile("anotherscript.lua")
```

## Enabling / Disabling a mod

Enable/disable from the `Mods` menu.

## Logging / Debugging

```lua
myMod:log("Hello World!")       -- INFO log
myMod:logWarning("Warning!")    -- WARNING log
myMod:logError("Error!")        -- ERROR log
myMod:msgBox("Hello there!")    -- blocking message box
```

## What is this generated_ids.lua file?

Stores the association between modding names and GUIDs. Distribute this file with your mod.

## Sharing a mod

Use mod.io: https://foundation.mod.io

## Quickly reload mods

Press `Ctrl + Shift + R` to reload.

start.txt · Last modified: 2026/02/23 16:51 by polymorphgames
