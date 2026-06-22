# Adding Platform Collider to a Building

Checklist for platform collider:

1) Processor

```lua
myMod:registerAssetProcessor("models/myFbxName.fbx", {
    DataType = "BUILDING_ASSET_PROCESSOR"
})
```

2) Mesh named `COLLIDER` (in upper case) in the fbx file, under the mesh of the building part (should contain "Part")

3) Flag PLATFORM

```lua
myMod:configurePrefabFlagList("models/myFbxName.fbx/Prefab/myBuildingPart", { "PLATFORM" })
```

Notes:
- The builder may not climb the COLLIDER (not built yet when builder comes)
- A villager can climb vertical faces of a COLLIDER
- To check, temporarily set a texture on the COLLIDER

guides/checklist-for-platform-collider.txt · Last modified: 2021/02/23 11:55 by 127.0.0.1
