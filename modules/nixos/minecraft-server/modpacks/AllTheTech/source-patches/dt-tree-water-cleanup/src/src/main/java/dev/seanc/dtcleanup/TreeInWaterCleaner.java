package dev.seanc.dtcleanup;

import java.util.ArrayDeque;
import java.util.HashSet;
import java.util.Set;
import net.minecraft.core.BlockPos;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.tags.TagKey;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.chunk.ChunkAccess;
import net.minecraft.world.level.chunk.ProtoChunk;
import net.minecraft.world.level.material.Fluids;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Removes Dynamic Trees whose trunks are standing in water carved AFTER tree
 * placement (Streams Reflowing's RiverCarverFeature runs in the features stage;
 * its tree-clearing only recognises vanilla logs, and its ConfiguredFeature
 * veto does not cover DT's placement path). Runs at the tail of
 * {@code ChunkGenerator.applyBiomeDecoration} and {@code ChunkGenerator.doFill}
 * — both strictly after the carve.
 *
 * A tree is felled iff:
 *   * its rooty-soil base sits at least {@link #MIN_FLOOD_DEPTH} below the
 *     chunk's lake surface (max water-top over the chunk's columns), AND
 *   * water actually touches the trunk at base level (any of the 4 horizontal
 *     neighbours, or the cell above the rooty soil), AND
 *   * the biome is not {@code #minecraft:is_swamp} (swamp oaks may be rooted
 *     in shallow water via DT's {@code swampOaksInWater}).
 * The whole connected DT component is removed: cells at/below the lake surface
 * become water (a uniform lake bed), cells above the surface become air.
 *
 * DT blocks are detected by class (species and addons extend the same base
 * classes); if the classes are missing the mod becomes a no-op.
 */
public final class TreeInWaterCleaner {

    private static final Logger LOGGER = LoggerFactory.getLogger("dt-tree-water-cleanup");

    /** Water must be at least this far above a tree's base to fell it. */
    private static final int MIN_FLOOD_DEPTH = 2;

    private static Class<?> CLS_BRANCH;
    private static Class<?> CLS_FOLIAGE;
    private static Class<?> CLS_ROOTY;
    private static boolean DT_PRESENT;

    private static final TagKey<net.minecraft.world.level.biome.Biome> TAG_SWAMP = TagKey.create(
            net.minecraft.core.registries.Registries.BIOME,
            ResourceLocation.withDefaultNamespace("is_swamp"));

    /** Chunks already processed (idempotence across the two hook sites). */
    private static final Set<Long> PROCESSED = new HashSet<>();

    static {
        try {
            CLS_BRANCH = Class.forName("com.dtteam.dynamictrees.block.branch.BranchBlock");
        } catch (Throwable ignored) { }
        try {
            CLS_FOLIAGE = Class.forName("com.dtteam.dynamictrees.block.leaves.DynamicLeavesBlock");
        } catch (Throwable ignored) { }
        try {
            CLS_ROOTY = Class.forName("com.dtteam.dynamictrees.block.soil.SoilBlock");
        } catch (Throwable ignored) { }
        DT_PRESENT = CLS_BRANCH != null && CLS_ROOTY != null;
        if (DT_PRESENT) {
            LOGGER.info("Dynamic Trees detected — water cleanup active");
        } else {
            LOGGER.warn("Dynamic Trees not detected — tree water cleanup disabled");
        }
    }

    private TreeInWaterCleaner() { }

    public static void cleanupChunk(WorldGenLevel level, ChunkAccess chunk) {
        if (!DT_PRESENT || !(chunk instanceof ProtoChunk proto)) {
            return;
        }
        long key = chunk.getPos().toLong();
        synchronized (PROCESSED) {
            if (!PROCESSED.add(key)) {
                return; // already handled by the earlier hook
            }
            if (PROCESSED.size() > 8192) {
                PROCESSED.clear();
            }
        }

        int minY = chunk.getMinBuildHeight();
        int maxY = chunk.getMaxBuildHeight();

        // Column water surfaces. A column's waterTop is the highest water cell;
        // a column whose lake column is occupied by a trunk reads none, so the
        // lake surface is taken as the MAX across the whole chunk (a lake is
        // flat). "No water anywhere" → nothing to do.
        int[][] waterTop = new int[16][16];
        int lakeSurface = minY - 1;
        for (int x = 0; x < 16; x++) {
            for (int z = 0; z < 16; z++) {
                int top = minY - 1;
                for (int y = maxY - 1; y >= minY; y--) {
                    if (chunk.getBlockState(new BlockPos(x, y, z)).getBlock() == Blocks.WATER) {
                        top = y;
                        break;
                    }
                }
                waterTop[x][z] = top;
                if (top > lakeSurface) {
                    lakeSurface = top;
                }
            }
        }
        if (lakeSurface < minY) {
            return; // no water anywhere in this chunk
        }

        // Scan every column top-down. Descend through air/water and through DT
        // blocks (a trunk may breach the surface); stop at solid ground. Record
        // DT rooty-soil bases.
        BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos();
        for (int x = 0; x < 16; x++) {
            for (int z = 0; z < 16; z++) {
                for (int y = maxY - 1; y >= minY; y--) {
                    pos.set(x, y, z);
                    BlockState state = chunk.getBlockState(pos);
                    if (isAirOrWater(state)) {
                        continue;
                    }
                    if (!isDtBlock(state)) {
                        break; // solid non-DT ground
                    }
                    if (isRooty(state)) {
                        if (lakeSurface - y >= MIN_FLOOD_DEPTH
                                && waterTouchesBase(level, proto, pos)
                                && !isSwamp(level, pos)) {
                            felledTree(level, proto, pos, lakeSurface);
                        }
                        break; // one tree per column
                    }
                    // Regular DT block (branch/foliage): keep descending.
                }
            }
        }
    }

    /** Is the trunk actually in a body of water at base level? */
    private static boolean waterTouchesBase(WorldGenLevel level, ProtoChunk chunk, BlockPos root) {
        BlockPos.MutableBlockPos p = new BlockPos.MutableBlockPos();
        p.set(root.getX(), root.getY() + 1, root.getZ());
        if (chunk.getBlockState(p).getFluidState().is(Fluids.WATER)) {
            return true;
        }
        for (int dx = -1; dx <= 1; dx++) {
            for (int dz = -1; dz <= 1; dz++) {
                if (dx == 0 && dz == 0) continue;
                p.set(root.getX() + dx, root.getY() + 1, root.getZ() + dz);
                if (chunk.getBlockState(p).getFluidState().is(Fluids.WATER)) {
                    return true;
                }
            }
        }
        return false;
    }

    /** BFS over the connected DT component rooted at {@code root}. */
    private static void felledTree(WorldGenLevel level, ProtoChunk chunk, BlockPos root, int lakeSurface) {
        BlockPos.MutableBlockPos cursor = new BlockPos.MutableBlockPos();
        ArrayDeque<BlockPos> queue = new ArrayDeque<>();
        Set<Long> seen = new HashSet<>();
        queue.add(root.immutable());
        seen.add(root.asLong());
        int touched = 0;
        int minY = chunk.getMinBuildHeight();
        int maxY = chunk.getMaxBuildHeight();
        int minX = chunk.getPos().getMinBlockX();
        int maxX = chunk.getPos().getMaxBlockX();
        int minZ = chunk.getPos().getMinBlockZ();
        int maxZ = chunk.getPos().getMaxBlockZ();

        while (!queue.isEmpty()) {
            BlockPos p = queue.poll();
            if (!isDtBlock(chunk.getBlockState(p))) {
                continue;
            }
            touched++;
            chunk.setBlockState(p,
                    p.getY() <= lakeSurface ? Blocks.WATER.defaultBlockState() : Blocks.AIR.defaultBlockState(),
                    false);

            for (int dx = -1; dx <= 1; dx++) {
                for (int dy = -1; dy <= 1; dy++) {
                    for (int dz = -1; dz <= 1; dz++) {
                        if (dx == 0 && dy == 0 && dz == 0) continue;
                        int nx = p.getX() + dx;
                        int ny = p.getY() + dy;
                        int nz = p.getZ() + dz;
                        if (nx < minX || nx > maxX || nz < minZ || nz > maxZ || ny < minY || ny >= maxY) {
                            continue;
                        }
                        long nl = new BlockPos(nx, ny, nz).asLong();
                        if (seen.add(nl)) {
                            cursor.set(nx, ny, nz);
                            if (isDtBlock(chunk.getBlockState(cursor))) {
                                queue.add(cursor.immutable());
                            }
                        }
                    }
                }
            }
            if (touched > 20000) {
                LOGGER.warn("Aborting oversized cleanup at {} ({} blocks)", root, touched);
                break;
            }
        }
        if (touched > 0) {
            LOGGER.debug("Removed {} DT blocks ({}) flooded by lake surface y={}", touched, root, lakeSurface);
        }
    }

    private static boolean isDtBlock(BlockState state) {
        Block b = state.getBlock();
        if (CLS_BRANCH != null && CLS_BRANCH.isInstance(b)) return true;
        if (CLS_FOLIAGE != null && CLS_FOLIAGE.isInstance(b)) return true;
        if (CLS_ROOTY != null && CLS_ROOTY.isInstance(b)) return true;
        return false;
    }

    private static boolean isRooty(BlockState state) {
        return CLS_ROOTY != null && CLS_ROOTY.isInstance(state.getBlock());
    }

    private static boolean isAirOrWater(BlockState state) {
        if (state.isAir()) return true;
        return state.getFluidState().is(Fluids.WATER);
    }

    private static boolean isSwamp(WorldGenLevel level, BlockPos pos) {
        return level.getBiome(pos).is(TAG_SWAMP);
    }
}