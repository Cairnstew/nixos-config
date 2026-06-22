# Annotations

### Type annotations

#### Single-property type

A type with this annotation contains only a single [serialized](/foundation/modding/annotations#serialized "annotations") property. Thus, to make the syntax lighter, instantiation for this type can be done by simply providing the value of the single property.

```lua
foundation.createData({
	DataType = "BUILDING_PART_COST",
	ResourceNeededList = { -- list of RESOURCE_COLLECTION_VALUE
 
		-- Can be serialized in full, like any other type
		{
			Collection = {
				{ Resource = "WOOD", Quantity = 20 },
				{ Resource = "STONE", Quantity = 10 },
			}
		},
 
		-- Or serialized directly like its only property, a list of RESOURCE_QUANTITY_PAIR
		{
			{ Resource = "WOOD", Quantity = 20 },
			{ Resource = "STONE", Quantity = 10 },
		}
	}
})
```

#### Lazy-init

By default, components are always initialized (call of `init` function) right after being created. For components flagged as *lazy-init* though, if the component is disabled on creation, the initialization is delayed until the component is enabled for the first time.

```lua
local standardComp = nil
local lazyInitComp = nil
 
level:createObject(function(_newObject)
    standardComp = _newObject:addComponent("STANDARD_COMPONENT")
    standardComp:setEnabled(false)
 
    lazyInitComp = _newObject:addComponent("LAZY_INIT_COMPONENT")
    lazyInitComp:setEnabled(false)
end)
-- at the end of createObject, only standardComp is initialized because it is disabled, but not lazy-init
 
-- when enabling lazyInitComp, since it's enabled for the first time, it is initialized at the same time
lazyInitComp:setEnabled(true)
```

#### Cloneable

Instance of types flagged as `Cloneable` can be duplicated using the `clone` function. This creates a new instance with the same properties, that can be used by other systems. This feature is necessary internally for some systems, but you can call this function in your scripts if need be.

When extending a cloneable type, this new type will also be cloneable. All properties of the parent type will be cloned by default, but you'll have to implement the `finalizeClone` function to define how to clone this type's specific properties.

```lua
local MY_CUSTOM_MANDATE = {
    TypeName = "MY_CUSTOM_MANDATE",
    ParentType = "MANDATE",
    Properties = {
	{ Name = "MyFloat", Type = "float", Default = 1.0 },
	{ Name = "MyString", Type = "string" },
	{ Name = "MyBuildingProgress", Type = "BUILDING_PROGRESS" } -- This has to be a CLONEABLE type too
    }
}
 
function MY_CUSTOM_MANDATE:finalizeClone(_source)
    self.MyFloat = _source.MyFloat
    self.MyString = _source.MyString
    self.MyBuildingProgress = _source.MyBuildingProgress:clone()
end
 
mod:registerClass(MY_CUSTOM_MANDATE)
```

---

### Property annotations

#### Serialized

This property is used to configure the data of assets or prefab components. For components and their data, it is saved in the savegame file, unless the component is owned by an object instantiated by a prefab, in which case it also needs to be tagged as *Savegame* to be saved.

#### Savegame

The value of this property is always saved in the savegame file.

#### Runtime only

This property is not used to configure an asset/component/data, but can be read and set at runtime.
