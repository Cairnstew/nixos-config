// ============================================================================
// Terraria Ambience API  —  by RighteousRyan
//
// Soundscape / ambience system. Register custom ambient sounds that
// play based on biome, time, depth, and other conditions.
//
// Integration pattern: Mod.Call
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//   2. Register ambience tracks for your custom biomes.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class AmbienceAPIIntegration
{
    private static Mod _ambience;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("TerrariaAmbienceAPI", out _ambience))
            return;
    }

    /// <summary>Register an ambient sound for a specific biome.</summary>
    public static void RegisterBiomeAmbience(string biomeKey, string soundPath, float weight = 1f)
    {
        _ambience?.Call("RegisterBiomeSound", biomeKey, soundPath, weight);
    }

    /// <summary>Create a custom ambience condition.</summary>
    public static void RegisterCondition(string conditionKey, System.Func<bool> check)
    {
        _ambience?.Call("RegisterCondition", conditionKey, check);
    }
}
*/
