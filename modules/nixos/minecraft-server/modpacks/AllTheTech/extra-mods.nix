# AllTheTech — extra LOCAL mods that are not in checksums.json (built from our
# own source at Nix build time via buildModSource).
#
# Merged into the mod link set by BOTH consumers (modules/flake-parts/packwiz.nix
# mkClientInstance and modules/nixos/minecraft-server/config.nix packwizSymlinks)
# so the client and the dedicated server ship identical jars. Keys follow the
# mkModLinks convention: "mods/<name>.jar" → a store jar derivation.
#
# This is the seam for mods the packwiz pack cannot reference by URL (we own the
# source, there is nowhere to host the jar). patches.nix only overrides keys of
# mods ALREADY in checksums.json — extras are genuinely new jars.
{ pkgs
, buildModSource
, ...
}:
{
  # dt-tree-water-cleanup — fells Dynamic Trees left standing in water that
  # Streams Reflowing carves after feature placement (Streams' tree-clearing
  # only recognises vanilla logs; DT blocks survive the carve). Our own mod,
  # source under source-patches/dt-tree-water-cleanup/src.
  "mods/dt-tree-water-cleanup.jar" = import ./source-patches/dt-tree-water-cleanup {
    inherit buildModSource;
    inherit (pkgs) curl unzip cacert;
  };

  # Ponder 1.0.82 (extracted verbatim from create.jar's jarjar copy) shipped as
  # an installed mod. When Productive Farming's jar ships Ponder 1.0.61 JIJ'd,
  # NeoForge's JarJarSelector picks that lower copy over create's 1.0.82 (its
  # version string "1.0.82+mc1.21.1" defeats the comparator), so Create 6.0.10
  # hard-fails with "create requires ponder 1.0.82 or above". An installed
  # (non-jarjar) Ponder always wins over jar-in-jar copies, so this keeps the
  # whole productive stack (Productive Farms / Trees / Bees all JIJ versions of
  # Ponder) from downgrading Create's. Ponder has no standalone release channel
  # (it ships inside Create), so we carry the jar here rather than URL-add it.
  "mods/ponder-neoforge-1.0.82+mc1.21.1.jar" = pkgs.runCommand "ponder-neoforge-1.0.82+mc1.21.1.jar" { } ''
    cp '${./local-jars/ponder-neoforge-1.0.82+mc1.21.1.jar}' "$out"
  '';
}
