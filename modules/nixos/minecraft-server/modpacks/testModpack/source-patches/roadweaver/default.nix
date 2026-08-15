# RoadWeaver — source-level patch: fix roads paved through elevated water.
#
# Upstream bug (https://github.com/shiroha-233/RoadWeaver/issues/68): water
# detection was sea-level-relative in the road-placement fallback paths
# (PathSpanExtractor.isBridgeWater, PathPostProcessor.detectBridgeMask) and in
# the accurate terrain fields' waterDepth(). Water bodies above sea level
# (mountain streams, modded lakes) got waterDepth = 0 → never counted as bridge
# water → the road was paved straight through the water.
#
# The accurate sampler already had the correct height-based test
# (oceanFloor < worldSurface, see AccurateTerrainRegionSampler line 195); this
# patch makes every other water check use the same height-based rule so a water
# column is recognized regardless of elevation or biome tag.
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
  patches = [ ./elevated-water.patch ];
  # outputHash filled in below: the sha256 of the built playable jar, computed
  # on first build (`nix build --impure .#... --print-out-paths` → "got:" hash).
  outputHash = "sha256-aMDD98KrCgzmOrhse0wRRBleN/MsCHaSIauqNFfFbtc=";
}
