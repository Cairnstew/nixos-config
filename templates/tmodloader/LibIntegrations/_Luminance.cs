// ============================================================================
// Luminance  —  by Lucille
// https://steamcommunity.com/workshop/filedetails/?id=3178462942
//
// General-purpose utility library: extension methods, helper types,
// common patterns used by many content mods.
//
// Integration pattern: direct reference + Mod.Call
// ============================================================================
//
// USAGE:
//   1. Add a reference to Luminance in your .csproj.
//   2. Uncomment the block below.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class LuminanceIntegration
{
    public static void Load()
    {
        if (!ModLoader.HasMod("Luminance"))
            return;

        // Luminance provides utility helpers accessible via Mod.Call:
        // var result = ModLoader.GetMod("Luminance").Call("SomeUtility", arg);

        // Common usage: register a debug overlay
        // ModLoader.GetMod("Luminance").Call("RegisterDebugOverlay", "YourMod", () => "Debug info");

        // Or use Luminance's built-in drawing helpers
        // Luminance.Drawing.DrawingUtilities.Something();
    }
}
*/
