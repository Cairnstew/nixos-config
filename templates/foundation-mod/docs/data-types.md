# Data Types

---

### boolean

local value = true

---

### integer and unsigned integer

Integer number. Cannot be negative for unsigned integers.

local value = 42

---

### float

Floating-point number with single precision

local value = 17.44

---

### double

Floating-point number with double precision

local value = -61.7267023355

---

### string

local value = "String value"

---

### guid

GUID are unique identifiers used to reference Assets or Game Objects. It can be interpreted from a string.

local value = "645318b0-021a-4e02-9f91-bd18300e491a"

---

### vec2i

2D integer vector

To initialize a `vec2i` with `x = 54` and `y = 97`:

local value = { 54, 97 }

[Full vec2i api](/foundation/modding/api/vec2i "api:vec2i").

---

### vec2f

2D float vector

To initialize a `vec2f` with `x = 73` and `y = 15.66`:

local value = { 73.0, 15.66 }

[Full vec2f api](/foundation/modding/api/vec2f "api:vec2f").

---

### vec3i

3D integer vector

To initialize a `vec3i` with `x = 19`, `y = 86` and `z = 45`:

local value = { 19, 86, 45 }

[Full vec3i api](/foundation/modding/api/vec3i "api:vec3i").

---

### vec3f

3D float vector.

To initialize a `vec3f` with `x = -15.71`, `y = -71` and `z = 93.03`:

local value = { -15.71, -71.0, 93.03 }

[Full vec3f api](/foundation/modding/api/vec3f "api:vec3f").

---

### quaternion

4D float vector representing a rotation

To initialize a `quaternion` with `x = 0.302268`, `y = 0.075567`, `z = 0.6347627` and `w = 0.7071068`:

local value = { 0.302268, 0.075567, 0.6347627, 0.7071068 }

Quaternion properties can also be set with a `vec3f` containing the euler angles in degrees.

---

### matrix

4×4 matrix representing a spatial transformation

Matrices can be initialized with an array of 16 float numbers.

local value = {
    1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
}

Matrices can also be initialized with a dictionary containing three fields: `Position` (`vec3f`), `Rotation` (`quaternion`) and `Scale` (`vec3f`). All those fields are optional.

local value = {
    Position = { 0, 0, 0 },
    Rotation = { 0, 0, 0 },
    Scale = { 1, 1, 1 } 
}

---

### color

A color is stored as four float numbers, representing the four channels. Each channel can have a value superior to 1, in case of HDR use.

To initialize a `color` with `R = 1`, `G = 0.549`, `B = 0` and `A = 0.9` (dark orange with 90% opacity; hex `FF8C00E6`):

local value = { 1, 0.549, 0, 0.9 }

---

### polygon

A 2D polygon is a list of 2D points (`vec2f`) defining a shape.

To initialize a square polygon with a side length of `4.5` and centered around the point `[1; 1]`:

local value = {
    { 5.5, 5.5 },
    { 5.5, -3.5 },
    { -3.5, -3.5 },
    { -3.5, 5.5 }
}

You can also create simple polygons with the following functions:

-   `polygon.**createRectangle**(*_size* [, *_offset*])`
    

Name | Type | Description
--- | --- | ---
*`_size`* | `vec2f` | Size of the rectangle
*`_offset`* | `vec2f` | Offset of the center of the rectange from \[0; 0\]

-   `polygon.**createCircle**(*_radius* [, *_offset* [, *_step*]])`
    

Name | Type | Description
--- | --- | ---
*`_radius`* | `float` | Radius of the circle
*`_offset`* | `vec2f` | Offset of the center of the circle from \[0; 0\]
*`_step`* | `integer` | Amount of sides of the circle

---

### bitfield

A bitfield is a dictionary with enumeration values of a specific type as keys, and boolean values as value.

When defining a new object, a enumeration value missing from a bitfield table will be considered as false. When [overriding existing data](/foundation/modding/asset-override "asset-override"), a missing enumeration value means the existing value will not be overriden.

To initialize a bitfield of [BUILDING_ZONE_TYPE](/foundation/modding/api/building_zone_type "api:building_zone_type") with the `DEFAULT` and `GRASS_CLEAR` values:

local bitfield = {
    DEFAULT = true,
    NAVIGABLE = false,
    GRASS_CLEAR = true
}

### component type

Type of a component, represented as a string

local componentType = "COMP_BUILDING_PART"

### list

A list is a collection of values of a specific type. This type can be used to create new properties for [custom classes](/foundation/modding/custom-classes "custom-classes"). The following example shows how to declare a `[float](/foundation/modding/data-types#float "data-types")` list property:

Properties = {
    ...
    {
        Name = "MyFloatListProperty", -- property name
        Type = "list<float>", -- type: list of float numbers
        Default = { 1.0, -4.0, 5.0 }, -- default value: list with three float numbers
    },
    ...
}
 
...
 
mod:log(tostring(#myClassInstance.MyFloatListProperty)) -- logs the size of the list
mod:log(tostring(myClassInstance.MyFloatListProperty[3])) -- logs the 3rd element of the list

### fixed_sized_array

A fixed sized array is a list containing a fixed number of values of a specific type. This type of property is specified with it's size (e.g. `float[5]`), and each value is accessible with the element's index (indexing is 1-based, like everything in lua). The following example shows how to declare and use a [custom class](/foundation/modding/custom-classes "custom-classes") array property containing 4 `[strings](/foundation/modding/data-types#string "data-types")`:

Properties = {
    ...
    {
        Name = "MyStringArrayProperty", -- property name
        Type = "string[4]", -- type: array of 4 strings
        Default = { "my", "custom", "default", "values" }, -- default value
    },
    ...
}
 
...
 
mod:log(myClassInstance.MyStringArrayProperty[2]) -- logs the 2nd element of the list

An example of use can be found in the [Example 02 mod](/foundation/modding/example-mods "example-mods"), in the script file `scripts/component/COMP_ANTENNA.lua`

### fixed_sized_map

A fixed sized map is very similar to a fixed sized array, except it can only take enumeration values as keys. For some properties, a maximum key value can be specified.

With a fixed sized map of [float](/foundation/modding/data-types#float "float") with [BUILDING_TYPE](/foundation/modding/api/building_type "api:building_type") keys, to set the value corresponding to the key `GENERAL`:

someType.MyMapProperty[BUILDING_TYPE.GENERAL] = 4.2
someType.MyMapProperty["GENERAL"] = 3.4 -- works only with the string version of the enum value
