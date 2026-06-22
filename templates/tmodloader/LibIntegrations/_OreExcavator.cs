// ============================================================================
// Ore Excavator  —  by CrazyContraption
// https://steamcommunity.com/workshop/filedetails/?id=3178462942
//
// Veinminer / excavation API. Allows custom item types to trigger
// vein-mining behavior on specific tile types.
//
// Integration pattern: Mod.Call only
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//   2. Register tile-item pairs that should support veinmining.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class OreExcavatorIntegration
{
    private static Mod _oreExcavator;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("OreExcavator", out _oreExcavator))
            return;
    }

    /// <summary>Register a tile type as vein-minable with a specific item.</summary>
    public static void RegisterVeinMinable(int tileType, int itemType)
    {
        _oreExcavator?.Call("AddTile", tileType, itemType);
    }

    /// <summary>Register a tile type as vein-minable with any pickaxe.</summary>
    public static void RegisterVeinMinable(int tileType)
    {
        _oreExcavator?.Call("AddTile", tileType);
    }

    /// <summary>Exclude a tile from vein mining.</summary>
    public static void ExcludeTile(int tileType)
    {
        _oreExcavator?.Call("RemoveTile", tileType);
    }
}
*/
