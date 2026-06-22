// ============================================================================
// LogSpiral's Library  —  by LogSpiral
//
// Utility library used by Furniture Solution, Property Panel, and other
// LogSpiral mods. Provides common helpers.
//
// Integration pattern: Mod.Call
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class LogSpiralLibraryIntegration
{
    private static Mod _lib;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("LogSpiralLibrary", out _lib))
            return;
    }

    /// <summary>Register a custom property panel entry.</summary>
    public static void RegisterPropertyPanel(string modName, string category, string key, object value)
    {
        _lib?.Call("RegisterProperty", modName, category, key, value);
    }
}
*/
