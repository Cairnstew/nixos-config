// ============================================================================
// Subworld Library  —  by John Snail
// https://steamcommunity.com/workshop/filedetails/?id=3244816416
//
// Enables custom subworlds: separate world instances for boss arenas,
// pocket dimensions, dungeons, etc.
//
// Integration pattern: direct reference + Mod.Call
// ============================================================================
//
// USAGE:
//   1. Add a reference to SubworldLibrary in your .csproj:
//      <Reference Include="SubworldLibrary" />
//   2. Uncomment the block below.
//   3. Create subworld classes inheriting from SubworldLibrary.Subworld.
//
// ============================================================================
/*
using System.Collections.Generic;
using Terraria;
using Terraria.ModLoader;
using Terraria.WorldBuilding;
using SubworldLibrary;

namespace YourMod.LibIntegrations;

public static class SubworldLibraryIntegration
{
    public static void Load()
    {
        if (!ModLoader.HasMod("SubworldLibrary"))
            return;

        // Register subworlds — called automatically by SL for classes
        // that inherit Subworld, but you can also register manually:
        // SubworldSystem.RegisterSubworld<MySubworld>();
    }

    public static void EnterMySubworld()
    {
        // SubworldSystem.Enter<MySubworld>();
    }
}

// Example subworld — a simple flat arena.
// public class MySubworld : Subworld
// {
//     public override int Width => 800;
//     public override int Height => 600;
//     public override bool NoPlayerSpawn => false;
//
//     public override List<GenPass> Tasks => new()
//     {
//         new PassLegacy("Build Arena", (progress, _) =>
//         {
//             // WorldGen code here
//         })
//     };
// }
*/
