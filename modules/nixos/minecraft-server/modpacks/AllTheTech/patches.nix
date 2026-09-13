# AllTheTech — build-time jar patches.
#
# Each entry overrides one mod symlink produced by packwiz2nix's mkModLinks
# (key = "mods/<checksums.json key with .pw.toml → .jar>"). Two mechanisms:
#
#   * patchJar      — replace a member in an already-built jar
#                     (patch-jar.nix; e.g. a dependency versionRange in a TEXT
#                     metadata member, or a BINARY bytecode fix via `member` =
#                     a .class path + a Python script that rewrites the bytes).
#   * buildModSource — build the WHOLE mod from source with a source-level
#                     patch (build-mod-source.nix; e.g. a bug in compiled
#                     Java logic that no metadata/config change can fix).
#
# The pack's .pw.toml / index.toml / checksums.json are left byte-identical —
# the pack stays a pure list of upstream mods, and the patch re-applies on
# update.
#
# Imported by BOTH consumers so client (packwiz.nix mkClientInstance) and
# server (minecraft-server/config.nix packwizSymlinks) ship identical jars:
#   import "${pack}/patches.nix" { inherit pkgs mods patchJar buildModSource; }
#
# `patchJar` / `buildModSource` are passed in by the consumer (NOT imported via
# ../patch-jar.nix or ../build-mod-source.nix): the server's packwiz path is a
# store-copied standalone dir, so a relative import would resolve to
# /nix/store/... and fail. The consumers reference the repo helpers via
# inputs.self instead.
{ pkgs, mods, patchJar, buildModSource }:
{
  # Dynamic Trees - Still Life (1.0.3) pins mr_still_life to "[1,)" but Still
  # Life has no 1.0+ release for 1.21.1 (latest is 0.1.1). Widen to "[0.1,)".
  "mods/dynamic-trees-still-life.jar" = patchJar {
    name = "dtstill-life-1.0.3-patched";
    src = mods."dynamic-trees-still-life.pw.toml";
    patchScript = ./patches/dynamic-trees-still-life.py;
  };

  # GAB's Styles Pack for Minecolonies (0.4.0) — <init> calls
  # NeoForge.EVENT_BUS.register(this) which crashes mod loading with
  # "has no @SubscribeEvent methods, but register was called anyway" because the
  # class has no @SubscribeEvent-annotated methods. Its common-setup is already
  # wired via modEventBus.addListener, so we NOP out the bogus register block.
  # This is a BINARY .class patch (member override), not a text metadata edit.
  "mods/gabs-styles-pack-for-minecolonies.jar" = patchJar {
    name = "gabstylespack-0.4.0-patched";
    src = mods."gabs-styles-pack-for-minecolonies.pw.toml";
    member = "com/gablabit/gabstylespack/GabStylesPack.class";
    patchScript = ./patches/gabstylespack.py;
  };

  # Reliquified Artifacts (1.0.8) pins its Artifacts dependency to the exact
  # "[13.2.3]" (the release it was tested against), but the pack ships
  # Artifacts 13.2.5 (fixes a Quark crash and Lootr mimic textures). Widen to
  # "[13.2.3,)" so the newest fix release loads.
  "mods/reliquified-artifacts.jar" = patchJar {
    name = "reliquified-artifacts-1.0.8-patched";
    src = mods."reliquified-artifacts.pw.toml";
    patchScript = ./patches/reliquified-artifacts.py;
  };
}

