// ============================================================================
// InnoVault  —  by HoCha113
//
// General-purpose utility library providing common helpers, drawing
// utilities, and event hooks.
//
// Integration pattern: Mod.Call
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//   2. Use provided helpers for drawing, math, and common patterns.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class InnoVaultIntegration
{
    private static Mod _innoVault;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("InnoVault", out _innoVault))
            return;
    }

    /// <summary>Register a custom UI layer.</summary>
    public static void RegisterUILayer(string layerName, float insertIndex = -1)
    {
        _innoVault?.Call("AddUILayer", layerName, insertIndex);
    }

    /// <summary>Draw a bordered rectangle (convenience helper).</summary>
    public static void DrawBorderedRect(object spriteBatch, object rect, object borderColor, object fillColor)
    {
        _innoVault?.Call("DrawBorderedRect", spriteBatch, rect, borderColor, fillColor);
    }
}
*/
