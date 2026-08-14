# testModpack — build-time jar patches.
#
# Each entry overrides one mod symlink produced by packwiz2nix's mkModLinks
# (key = "mods/<checksums.json key with .pw.toml → .jar>") with a patched jar
# built by patch-jar.nix from the SAME pinned upstream fetch. The pack's
# .pw.toml / index.toml / checksums.json are left byte-identical — the pack
# stays a pure list of upstream mods, and the patch re-applies on update.
#
# Imported by BOTH consumers so client (packwiz.nix mkClientInstance) and
# server (minecraft-server/config.nix packwizSymlinks) ship identical jars:
#   import "${pack}/patches.nix" { inherit pkgs lib mods; }
{ pkgs, lib, mods }:
let
  patchJar = import ../patch-jar.nix { inherit (pkgs) lib unzip zip coreutils python3; };
in
{
  # Dynamic Trees - Still Life (1.0.3) pins mr_still_life to "[1,)" but Still
  # Life has no 1.0+ release for 1.21.1 (latest is 0.1.1). Widen to "[0.1,)".
  "mods/dynamic-trees-still-life.jar" = patchJar {
    name = "dtstill-life-1.0.3-patched";
    src = mods."dynamic-trees-still-life.pw.toml";
    patchScript = ./patches/dynamic-trees-still-life.py;
  };
}
