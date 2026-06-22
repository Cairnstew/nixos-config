using Terraria.ModLoader;

namespace YourMod.Common.Systems;

/// <summary>
/// Central dispatch for optional library mod integrations.
///
/// Each integration lives in its own file under LibIntegrations/ and is
/// commented out by default. To enable one, uncomment the corresponding
/// Load() call below AND the integration file content.
///
/// Libraries are detected at runtime via ModLoader.HasMod() so the mod
/// works with or without them — no hard dependencies.
/// </summary>
public class LibraryIntegrationSystem : ModSystem
{
    public override void PostSetupContent()
    {
        // ── Tier 1 — Foundational ──────────────────────────────────
        //
        // SubworldLibraryIntegration.Load();     // Subworld Library
        // LuminanceIntegration.Load();           // Luminance
        // WeaponOutLiteIntegration.Load();       // WeaponOut Lite
        // StructureHelperIntegration.Load();     // Structure Helper
        // OreExcavatorIntegration.Load();        // Ore Excavator
        // InnoVaultIntegration.Load();           // InnoVault
        // SerousCommonLibIntegration.Load();     // SerousCommonLib
        // LogSpiralLibraryIntegration.Load();    // LogSpiral's Library
        // ParticleLibraryIntegration.Load();     // Particle Library
        // AmbienceAPIIntegration.Load();         // Terraria Ambience API
        // ImpactLibraryIntegration.Load();       // Impact Library
        // ProceduralMusicIntegration.Load();     // Procedural Music Lib

        // ── Tier 2 — Specialized ───────────────────────────────────
        //
        // DialoguePanelIntegration.Load();       // Dialogue Panel Rework
        // ShopExpanderIntegration.Load();        // Shop Expander
        // ModLiquidIntegration.Load();           // ModLiquid Library
        // PegasusLibIntegration.Load();          // Pegasus Lib
        // AlternativesLibIntegration.Load();     // Alternatives Library
        // SpikyLibIntegration.Load();            // Spiky's Lib
        // FaeLibraryIntegration.Load();          // Fae's Library
        // WAYLIBIntegration.Load();              // WAYLIB
        // TPackBuilderIntegration.Load();        // tPackBuilder
        // GlowmaskHelperIntegration.Load();      // Glowmask Helper
        // VanityCursorAPIIntegration.Load();     // Vanity + Dyeable Cursors

        // ── Tier 3 — Niche ─────────────────────────────────────────
        //
        // CompatibilityCheckerIntegration.Load(); // Compatibility Checker
        // BetterHairWindowIntegration.Load();    // Better Hair Window
        // ModSideIconIntegration.Load();         // Mod Side Icon
    }
}
