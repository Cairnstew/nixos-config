package dev.seanc.dtcleanup;

import net.neoforged.fml.common.Mod;

/**
 * DT Tree Water Cleanup — removes Dynamic Trees left standing in bodies of
 * water that Streams Reflowing carves after feature placement.
 *
 * Streams places its RiverCarverFeature during the features stage (it only
 * defers the chunk STEP until its region data is ready) and its tree-clearing
 * logic only recognises vanilla logs/leaves, so Dynamic Trees (custom blocks,
 * and a placement path that bypasses Streams' {@code ConfiguredFeature} veto)
 * survive the carve "sunken under varying degrees of water". See
 * {@link dev.seanc.dtcleanup.TreeInWaterCleaner} for the cleanup itself.
 */
@Mod(DTTreeWaterCleanup.MODID)
public final class DTTreeWaterCleanup {

    public static final String MODID = "dt_tree_water_cleanup";

    public DTTreeWaterCleanup() {
        // Mixins auto-register via dt_tree_water_cleanup.mixins.json.
    }
}