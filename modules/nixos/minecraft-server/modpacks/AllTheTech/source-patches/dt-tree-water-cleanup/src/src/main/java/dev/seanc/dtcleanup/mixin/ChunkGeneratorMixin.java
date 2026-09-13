package dev.seanc.dtcleanup.mixin;

import dev.seanc.dtcleanup.TreeInWaterCleaner;
import net.minecraft.world.level.StructureManager;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.chunk.ChunkAccess;
import net.minecraft.world.level.chunk.ChunkGenerator;
import org.spongepowered.asm.mixin.Mixin;
import org.spongepowered.asm.mixin.injection.At;
import org.spongepowered.asm.mixin.injection.Inject;
import org.spongepowered.asm.mixin.injection.callback.CallbackInfo;

/**
 * Hooks the tail of the features stage on the server / integrated server side.
 *
 * Streams Reflowing carves its channels as a feature (RiverCarverFeature,
 * {@code ChunkGenerator.applyBiomeDecoration}), so the TAIL of
 * {@code applyBiomeDecoration} is strictly after the carve. (1.21.1's
 * {@code applyBiomeDecoration} takes {@code (WorldGenLevel, ChunkAccess,
 * StructureManager)} — earlier guesses at the signature were caught by the
 * mixin's descriptor check during iterative development.)
 */
@Mixin(ChunkGenerator.class)
public class ChunkGeneratorMixin {

    @Inject(method = "applyBiomeDecoration", at = @At("TAIL"))
    private void dtcleanup$afterFeatures(WorldGenLevel level, ChunkAccess chunk,
            StructureManager structureManager, CallbackInfo ci) {
        TreeInWaterCleaner.cleanupChunk(level, chunk);
    }
}