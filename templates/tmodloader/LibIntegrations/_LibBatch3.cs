// ============================================================================
// tPackBuilder  —  by Purple Crayon Muncher
//
// Asset packing framework. Combines multiple textures/sprites into
// packed atlases for improved load times and organization.
//
// Integration pattern: direct reference
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class TPackBuilderIntegration
{
    public static void Load()
    {
        if (!ModLoader.HasMod("tPackBuilder"))
            return;

        // tPackBuilder provides attributes and tools for packing assets.
        // Decorate your texture fields with [Pack] attributes and call
        // the packing methods during Load().
    }
}
*/

// ============================================================================
// Glowmask Helper  —  by mimig298
//
// Renders glowmask textures on items and NPCs. Provides a simple API
// for attaching glow effects to any sprite.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class GlowmaskHelperIntegration
{
    private static Mod _glow;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("GlowmaskHelper", out _glow))
            return;
    }

    /// <summary>Register a glowmask for an item type.</summary>
    public static void RegisterItemGlow(int itemType, string glowTexturePath)
    {
        _glow?.Call("RegisterItemGlow", itemType, glowTexturePath);
    }

    /// <summary>Register a glowmask for an NPC type.</summary>
    public static void RegisterNPCGlow(int npcType, string glowTexturePath)
    {
        _glow?.Call("RegisterNPCGlow", npcType, glowTexturePath);
    }
}
*/

// ============================================================================
// Vanity + Dyeable Cursors API  —  by tomat
//
// Custom cursor rendering API. Allows mods to replace the mouse cursor
// with custom sprites, including dye support.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Microsoft.Xna.Framework;
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class VanityCursorAPIIntegration
{
    private static Mod _cursorApi;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("VanityDyeableCursors", out _cursorApi))
            return;
    }

    public static void RegisterCursor(string cursorName, string texturePath, Point hotSpot)
    {
        _cursorApi?.Call("RegisterCursor", cursorName, texturePath, hotSpot.X, hotSpot.Y);
    }

    public static void SetActiveCursor(string cursorName)
    {
        _cursorApi?.Call("SetActiveCursor", cursorName);
    }
}
*/

// ============================================================================
// Compatibility Checker  —  by JamzOJamz
//
// Detects and reports mod incompatibilities. Registers known conflicts
// or compatibility shims.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class CompatibilityCheckerIntegration
{
    private static Mod _compat;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("CompatibilityChecker", out _compat))
            return;
    }

    public static void RegisterCompatShim(string otherMod, System.Action shim)
    {
        _compat?.Call("RegisterCompatShim", otherMod, shim);
    }
}
*/

// ============================================================================
// Better Hair Window  —  by Rhoenicx
//
// Enhanced hair style/color selection UI. Integrates custom hair
// styles and dyes.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class BetterHairWindowIntegration
{
    private static Mod _hair;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("BetterHairWindow", out _hair))
            return;
    }

    public static void RegisterHairStyle(string styleName, string texturePath)
    {
        _hair?.Call("RegisterHairStyle", styleName, texturePath);
    }
}
*/

// ============================================================================
// Mod Side Icon  —  by Erky
//
// API for drawing custom icons on the mod side of the world map.
//
// Integration pattern: Mod.Call
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class ModSideIconIntegration
{
    private static Mod _sideIcon;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("ModSideIcon", out _sideIcon))
            return;
    }

    public static void RegisterIcon(string iconName, string texturePath, System.Func<bool> visibilityCheck)
    {
        _sideIcon?.Call("RegisterIcon", iconName, texturePath, visibilityCheck);
    }
}
*/
