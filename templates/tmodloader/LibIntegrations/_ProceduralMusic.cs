// ============================================================================
// Procedural Music Library  —  by Moonlight Glint
//
// Runtime music generation. Compose and play procedural music tracks
// driven by parameters (intensity, biome, time of day, etc.).
//
// Integration pattern: Mod.Call
// ============================================================================
//
// USAGE:
//   1. Uncomment the block below.
//   2. Register procedural music tracks with transition rules.
//
// ============================================================================
/*
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class ProceduralMusicIntegration
{
    private static Mod _musicLib;

    public static void Load()
    {
        if (!ModLoader.TryGetMod("ProceduralMusicLibrary", out _musicLib))
            return;
    }

    /// <summary>Register a procedural music track.</summary>
    public static void RegisterTrack(string trackName, string basePath, float intensity = 0.5f)
    {
        _musicLib?.Call("RegisterTrack", trackName, basePath, intensity);
    }

    /// <summary>Set the current intensity parameter (0.0 – 1.0).</summary>
    public static void SetIntensity(string trackName, float value)
    {
        _musicLib?.Call("SetIntensity", trackName, value);
    }
}
*/
