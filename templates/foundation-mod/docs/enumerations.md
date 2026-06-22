# Enumerations

An enumeration (or enum) is a data type containing a set of constant values.

See the [list of all available enumerations](/foundation/modding/api#enumerations "api").

---

Previously, you could only refer to enum elements as strings. For example, to define the [building type of a building](/foundation/modding/api/building#buildingtype "api:building"), you used `BuildingType = "GENERAL"`.

Now, all enum values are stored in their enum type's table. This allows for a more clear syntax: `BuildingType = BUILDING_TYPE.GENERAL`.

The conversion to string is still available with the function `toString`. You can also convert the enum value to an integer and vice versa with the functions `toNumber` and `fromNumber`. These functions are available in the `enum` table, and directly on the enum tables and enum values.

```lua
local stringValue = BUILDING_TYPE.MONUMENT:toString()
-- same as enum.toString(BUILDING_TYPE.MONUMENT)
print(stringValue) -- prints "MONUMENT"
 
local intValue = BUILDING_TYPE.DECORATION:toNumber()
-- same as enum.toNumber(BUILDING_TYPE.DECORATION)
print(intValue) -- prints "2"
 
local enumValue = BUILDING_TYPE:fromNumber(intValue)
-- same as enum.fromNumber(BUILDING_TYPE, intValue)
print (enumValue == BUILDING_TYPE.DECORATION) -- prints ("true")
```

These functions are useful, for example, to use enum values for bitwise operations. When you want to use [the raycast method](/foundation/modding/api/level#raycast "api:level"), the `*flag*` argument is used as a bit field containing the different [object flags](/foundation/modding/api/object_flag "api:object_flag") you want your ray cast to collide with. This means you have to create your flag using bitwise operations. To do this, you can use the [BitOp module](http://bitop.luajit.org/api.html "http://bitop.luajit.org/api.html"), the functions of which are available in the `bit` table.

```lua
local raycastResult = {}
 
-- C equivalent: (1 << OBJECT_FLAG.TERRAIN) | (1 << OBJECT_FLAG.WATER) | (1 << OBJECT_FLAG.PLATFORM)
local flag = bit.bor(
	bit.lshift(1, OBJECT_FLAG.TERRAIN:toNumber()),
	bit.lshift(1, OBJECT_FLAG.WATER:toNumber()),
	bit.lshift(1, OBJECT_FLAG.PLATFORM:toNumber())
)
 
-- Raycast from the screen position [400; 300], forward
-- for a distance of 1000, only on objects with a TERRAIN,
-- WATER or PLATFORM flag
level:rayCast({ 400, 300 }, 1000, raycastResult, flag)
```

## Dynamic enumerations

For enumerations tagged as dynamic, you can add new values with the function `registerEnumValue`. Multiple mods can register the same new enum value, which is then shared.

You can find more information on the `registerEnumValue` on the [mod management function page](/foundation/modding/mod-management-functions#registerenumvalue "mod-management-functions").
