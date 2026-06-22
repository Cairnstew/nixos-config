# Mod Management Functions

All these functions are available on your mod object.

## dofile

Loads and runs a Lua script. Returns the file's return values.

`[...] myMod:dofile(scriptPath [, args...])`

## registerAsset

Register a new game asset. (Deprecated name: `register`)

`void myMod:registerAsset(assetData)`

## overrideAsset

Override an existing game asset. (Deprecated name: `override`)

`void myMod:overrideAsset(assetData)`

## registerBehaviorTree

Registers a new behavior tree.

`void myMod:registerBehaviorTree(behaviorTree)`

## registerBehaviorTreeNode

Registers a new behavior tree node.

`void myMod:registerBehaviorTreeNode(behaviorTreeNode)`

## registerClass

Registers a new data type, or a new type extending an existing one.

`void myMod:registerClass(classInfo)`

## registerAssetId

Assign an asset ID to an asset in the mod's directory.

`void myMod:registerAssetId(assetPath, assetId [, assetType])`

## registerPrefabChild

Registers a new child for a prefab.

`void myMod:registerPrefabChild(parentPrefabIdOrPath, id [, name] [, transform])`

## registerPrefabComponent

Registers a component to a prefab.

`void myMod:registerPrefabComponent(prefabIdOrPath, componentData)`

## registerAssetProcessor

Registers an asset processor to a file.

`void myMod:registerAssetProcessor(filePath, processorData)`

## registerEnumValue

Registers a new dynamic enumeration value.

`void myMod:registerEnumValue(enumeration, stringValue)`

## configurePrefabFlagList

Configure a prefab with a list of flags.

`void myMod:configurePrefabFlagList(prefabPath, flagArray)`

## overrideTexture

Overrides an existing core texture with another one.

`void myMod:overrideTexture(oldTexturePath, newTexturePath, blendMode)`

Blend modes: `REPLACE`, `ALPHA_BLEND`, `ADDITIVE`, `SUBTRACTIVE`

mod-management-functions.txt · Last modified: 2026/02/23 17:02 by polymorphgames
