# Defining Building's Worker Path

Checklist for worker path:

1) The building part name should contain "Part"
2) Path points should be named `PATH_x_y` where `x` is a letter and `y` a number
3) The worker goes through points from smaller number to greater number
4) The final orientation depends on the orientation of the last `PATH_x_y`
5) Processor

```lua
myMod:registerAssetProcessor("models/myFbxName.fbx", {
    DataType = "BUILDING_ASSET_PROCESSOR"
})
```

Notes:
- For a simple building, the game shows a green arrow on the first path
- For a monument, no green arrow is displayed

guides/checklist-for-worker-path.txt · Last modified: 2021/03/17 17:37 by 127.0.0.1
