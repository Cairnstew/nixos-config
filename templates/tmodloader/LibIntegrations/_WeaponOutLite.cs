// ============================================================================
// WeaponOut Lite  —  by FK99
// https://steamcommunity.com/workshop/filedetails/?id=3154320841
//
// Displays held items on the player character's model. Extends the visual
// presentation of weapons, tools, and accessories.
//
// Integration pattern: Mod.Call only (no direct reference needed)
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//   2. Call ShowHeldItem for items that should appear on the character.
//
// ============================================================================
/*
using Terraria;
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class WeaponOutLiteIntegration
{
    private static Mod _weaponOut;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("WeaponOutLite", out _weaponOut))
            return;
    }

    /// <summary>Force a specific item to show on the player.</summary>
    public static void ShowHeldItem(Player player, int itemType, int duration = 2)
    {
        _weaponOut?.Call("ShowHeldItem", player, itemType, duration);
    }

    /// <summary>Hide the currently displayed item.</summary>
    public static void HideHeldItem(Player player)
    {
        _weaponOut?.Call("HideHeldItem", player);
    }

    /// <summary>Check if an item is currently being displayed.</summary>
    public static bool IsItemVisible(Player player)
    {
        return _weaponOut?.Call("IsItemVisible", player) as bool? ?? false;
    }
}
*/
