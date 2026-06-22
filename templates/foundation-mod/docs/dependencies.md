# Dependencies

## Hard dependency

If your mod depends on features/content created in another mod, you can declare this other mod as a hard dependency of yours. Doing so will warn players if they try to use your mod without its dependencies.

To declare dependencies for your mod, add a `"Dependencies"` table in your `mod.json`. Each entry in this table requires the name of the dependency mod (`"Name"`), and its ID (`"Id"`, you can find it in the dependency's `generated_ids.lua` file).

```json
{
  "Name": "Mod Name",
  "Author": "Author of the mod",
  "Description": "Description of the mod",
  "Version": "1.0.0",
  "Dependencies": [
    {
      "Id": "81f7891c-d992-4b27-beff-617a276bab4c",
      "Name": "First dependency mod"
    },
    {
      "Id": "28eac88d-a14a-45fa-842f-710839386b77",
      "Name": "Second dependency mod"
    }
  ]
}
```

## Soft dependency

If your mod uses another mod's content but can still work without it, this other mod is considered as a soft dependency. In this case, you can test in your script if this mod is already loaded with `foundation.isModLoaded`:

```lua
-- Test if the mod I depend on is loaded
if (foundation.isModLoaded("5d2565f1-3083-4a53-8366-8f2a2e1c4690")) then
    ....
else
    ....
end
```

dependencies.txt · Last modified: 2020/07/14 13:15 by 127.0.0.1
