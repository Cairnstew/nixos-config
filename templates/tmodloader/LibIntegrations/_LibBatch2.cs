// ============================================================================
// Pegasus Lib  —  by Moonlight Glint
//
// General-purpose utility library. Provides common helpers used by
// Moonlight Glint's other mods.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class PegasusLibIntegration
{
    private static Mod _pegasus;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("PegasusLib", out _pegasus))
            return;
    }

    public static T Utility<T>(string method, params object[] args)
    {
        return (T)(_pegasus?.Call(method, args) ?? default(T));
    }
}
*/

// ============================================================================
// Alternatives Library  —  by Moonlight Glint
//
// Provides alternative content variants (alt textures, alt recipes, etc.)
// Useful for mods that want to offer multiple visual or gameplay options.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class AlternativesLibIntegration
{
    private static Mod _alt;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("AlternativesLibrary", out _alt))
            return;
    }

    public static void RegisterAlternative(int originalItemType, int altItemType, string label)
    {
        _alt?.Call("RegisterAlternative", originalItemType, altItemType, label);
    }
}
*/

// ============================================================================
// Spiky's Lib  —  by Spiky
//
// General utility library with math helpers, drawing extensions, and
// common data structures.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class SpikyLibIntegration
{
    private static Mod _spiky;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("SpikysLib", out _spiky))
            return;
    }
}
*/

// ============================================================================
// Fae's Library  —  by elytrafae
//
// Utility library with drawing helpers, math extensions, and common
// patterns used in elytrafae's mods.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class FaeLibraryIntegration
{
    private static Mod _fae;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("FaeLib", out _fae))
            return;
    }
}
*/

// ============================================================================
// WAYLIB  —  by ENNWAY
//
// General utility and helper library.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class WAYLIBIntegration
{
    private static Mod _waylib;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("WAYLIB", out _waylib))
            return;
    }
}
*/
