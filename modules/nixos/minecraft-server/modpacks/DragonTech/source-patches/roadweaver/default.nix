# RoadWeaver — source-level patches:
#
# 1. elevated-water.patch — fix roads paved through elevated water.
#
#    Upstream bug (https://github.com/shiroha-233/RoadWeaver/issues/68): water
#    detection was sea-level-relative in the road-placement fallback paths
#    (PathSpanExtractor.isBridgeWater, PathPostProcessor.detectBridgeMask) and in
#    the accurate terrain fields' waterDepth(). Water bodies above sea level
#    (mountain streams, modded lakes) got waterDepth = 0 → never counted as bridge
#    water → the road was paved straight through the water.
#
#    The accurate sampler already had the correct height-based test
#    (oceanFloor < worldSurface, see AccurateTerrainRegionSampler line 195); this
#    patch makes every other water check use the same height-based rule so a water
#    column is recognized regardless of elevation or biome tag.
#
# 2. remove-opencl-shadow.patch — stop bundling lwjgl-opencl into the jar.
#
#    RoadWeaver's neoforge build `include`d lwjgl-opencl (fusing the
#    org.lwjgl.opencl package into the main jar). That exports a split package:
#    c2me-ocl (server GPU worldgen) bundles lwjgl-opencl-3.3.3 as a module too,
#    and Epic Fight reads org.lwjgl.opencl — NeoForge then fails module
#    resolution. The binding is provided at runtime by c2me-ocl (server) or
#    Minecraft's own LWJGL (client); if neither is present RoadWeaver's OpenCL
#    pathing already falls back to CPU. This patch keeps the dependency as
#    compileOnly and removes it from the shadow jar + runtime layer.
#
# The jar is built from source via the shared build-mod-source.nix helper
# (fixed-output derivation — Gradle needs network at build time). Registered in
# patches.nix as "mods/roadweaver.jar", consumed by both the client flake-part
# and the server.
{ buildModSource
, fetchFromGitHub
}:
buildModSource {
  name = "roadweaver-2.3.1-elevated-water-patched.jar";
  src = fetchFromGitHub {
    owner = "shiroha-233";
    repo = "RoadWeaver";
    rev = "331d4ded998b55f90f9c283b30e2e38223016f3f"; # 2.3.1-1.21.1
    hash = "sha256-MErKMaNzYbCq32fHonxOZDJD304ytN1VpDjzsPsMJo4=";
  };
  patches = [
    ./elevated-water.patch
    ./remove-opencl-shadow.patch
  ];
  # outputHash filled in below: the sha256 of the built playable jar, computed
  # on first build (`nix build --impure .#... --print-out-paths` → "got:" hash).
  outputHash = "sha256-WAWDj7LjwE3buFT2FLrm4G0SGJBVUkjRHqne4nzWn/c=";
}
