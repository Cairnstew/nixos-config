# Custom Classes

You can define new types with the `mod:registerClass` function. This function allows you to create new data types, or extend existing core classes.

When you define a new type, you can assign it functions and properties. Properties are editable, usable in your type's behavior, and that can be saved in a savegame. Those properties must have a name and a type. They can also have a default value, flags, and access functions (getter and setter).

---

## Extendable Classes

Some core types are flagged as **Extendable** in the documentation. This means an extendable type can be used as parent type when creating a custom type. In addition to new functions, you can override some base functions existing in the parent type, flagged as **Virtual function**. When overriding a virtual function, define a new function for your custom type with the same type and parameters. You can call the parent function using the keyword `super`.

```lua
function myCustomTypeInfo:someVirtualFunction(param1, param2)
    self.super:someVirtualFunction(param1, param2)
    ... -- custom additional behavior
end
```

---

## Custom Components

For custom types extending `COMPONENT`, you can override some base functions that are automatically called for all components:

- `**create**()`: when the component is created
- `**init**()`: when the component is initialized in the game
- `**update**()`: at each frame
- `**onEnabled**()`: when the component is enabled
- `**onDisabled**()`: when the component is disabled
- `**onFinalize**(_isClearingLevel_)`: when the component is destroyed, only if it has been initialized
- `**onDestroy**(_isClearingLevel_)`: when the component is destroyed, after `onFinalize`

---

## Guides on Custom Classes

- [Creating a Custom DATA Object](/foundation/modding/custom-data)
- [Creating a Custom ASSET Object](/foundation/modding/custom-asset)
- [Creating a Custom BUILDING_FUNCTION](/foundation/modding/custom-building-function)
- [Creating a Custom MANDATE](/foundation/modding/custom-mandate)

custom-classes.txt · Last modified: 2022/03/29 20:36 by 127.0.0.1
