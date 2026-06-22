# Foundation Library Functions

## createMod

Creates and returns a new mod

`void foundation.createMod()`

---

## isModEnabled

Checks if a mod is enabled. Returns `true` if found and enabled, `false` otherwise.

`boolean foundation.isModEnabled(modId)`

---

## isModLoaded

Checks if a mod is already loaded, for soft dependencies purposes.

`boolean foundation.isModLoaded(modId)`

---

## getModVersion

Retrieves the version of a mod.

`string foundation.getModVersion(modId)`

---

## getGameVersion

Retrieves the game's version.

`string foundation.getGameVersion()`

---

## createData

Creates a new instance of a data type.

`void myMod:createData(instanceData)`

---

## findAsset

Finds an asset by its name.

`ASSET foundation.findAsset(assetName)`

---

## findGameObject

Finds a GameObject by its name.

`GAME_OBJECT foundation.findGameObject(objectName)`

foundation-library-functions.txt · Last modified: 2026/02/23 16:53 by polymorphgames
