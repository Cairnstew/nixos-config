# Components

Components are small modules used to define the behavior of any game object. Game objects can have any number of components, but can have only one of each type.

Components can be added to any FBX node with the `mod:registerPrefabComponent` function.

```lua
mod:registerPrefabComponent("models/MithrilFactory.fbx/Prefab/MithrilFactory/ExtensionB/RootPart", {
    DataType = "COMP_DIRT_RECTANGLE",
    Size = {8, 8}
})
```

See mod Example 02 for more examples.

components.txt · Last modified: 2020/07/08 10:21 by 127.0.0.1
