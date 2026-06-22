// ============================================================================
// Particle Library  —  by snowy
//
// Custom particle effect framework. Define particle types and spawn
// them with full control over behavior, color, and lifetime.
//
// Integration pattern: direct reference + Mod.Call
// ============================================================================
//
// USAGE:
//   1. Add a reference to ParticleLibrary in your .csproj.
//   2. Uncomment the block below.
//   3. Create particle classes extending ParticleLibrary.Particle.
//
// ============================================================================
/*
using Microsoft.Xna.Framework;
using Terraria.ModLoader;

namespace YourMod.LibIntegrations;

public static class ParticleLibraryIntegration
{
    public static void Load()
    {
        if (!ModLoader.HasMod("ParticleLibrary"))
            return;

        // Particles are auto-registered by the library when they inherit
        // ParticleLibrary.Particle. Manual registration:
        // ParticleLibrary.ParticleManager.RegisterParticle<MyParticle>();
    }

    /// <summary>Spawn a burst of particles at a position.</summary>
    public static void SpawnBurst(Vector2 position, int particleType, int count, Color color)
    {
        // var particle = new MyParticle { Position = position, Color = color };
        // ParticleLibrary.ParticleManager.SpawnParticle(particle);
    }
}

// Example particle:
// public class MyParticle : ParticleLibrary.Particle
// {
//     public override void SetDefaults()
//     {
//         width = 8; height = 8;
//         timeLeft = 60;
//         oldPositions = 3;
//     }
//     public override void AI()
//     {
//         velocity.Y += 0.1f;
//         rotation += 0.05f;
//     }
// }
*/
