# Material Sets

A monument can have material sets. Each material (base and replacement) must be listed in the monument asset property `MaterialSetList`.

For each material set, all materials must be listed in the same order as their replacement:

```lua
mod:register({
    DataType = "MONUMENT",
    ...
    MaterialSetList = {
        {
            SetName = "DEFAULT",
            MaterialList = {
                "MAIN_MATERIAL",
                "SECONDARY_MATERIAL",
                "TERTIARY_MATERIAL"
            }
        },
        {
            SetName = "ALTERNATIVE",
            MaterialList = {
                "MAIN_MATERIAL_ALT",
                "SECONDARY_MATERIAL_ALT",
                "TERTIARY_MATERIAL_ALT"
            }
        }
    }
})
```

When importing an FBX file, materials are imported alongside the model. You can find those materials in a virtual directory `Materials` inside the FBX file.

```lua
mod:registerAssetId("models/YourMonumentModel.fbx/Materials/MainMaterial", "MAIN_MATERIAL")
```

If a material is not used on the model, it will not be imported. To circumvent this, create a dummy object that will not be used in the mod, to apply your material on.

material-sets.txt · Last modified: 2020/04/28 18:36 by 127.0.0.1
