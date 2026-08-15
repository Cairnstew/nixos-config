# Shared helper: build a mod JAR from source at Nix build time.
#
# The existing patch-jar.nix replaces a *text metadata member* inside an
# already-built jar (META-INF/neoforge.mods.toml). Some bugs live in compiled
# Java logic (e.g. RoadWeaver's water detection), which no config file or
# metadata member can fix. For those, build the whole mod from source with a
# source-level patch, and ship the patched jar exactly like any other mod.
#
# This is a fixed-output derivation (FOD): the Gradle/NeoForge toolchain needs
# network at build time (Maven repos, the MC toolchain), which the Nix sandbox
# normally blocks. FODs are allowed network because their output is pinned by
# `outputHash`, so the build result is still trusted and reproducible.
#
# Usage: buildModSource { name, src, patches, buildCmd, outputHash }
#   name        — output jar name (e.g. "roadweaver-2.3.1-water-patched.jar")
#   src         — the mod's source (a fetchFromGitHub / fetchgit derivation)
#   patches     — list of source-level patch files (git-format unified diffs
#                 applied with `patch -p1`, paths relative to the repo root)
#   buildCmd    — shell command run in the unpacked source that produces the
#                 final playable jar (default: `./gradlew :neoforge:build`,
#                 using the mod's own wrapper version). MUST copy the result
#                 jar to $out.
#   outputHash  — sha256 of the built jar (outputHashMode = "flat"). Compute
#                 with `nix build --impure .#... --print-out-paths` once and
#                 paste the "got:" hash from the mismatch error.
#
# Consumers import this via inputs.self (like patch-jar.nix) so both the client
# flake-part (packwiz.nix) and the server (config.nix) get the same jar:
#   buildModSource = import "${flake.inputs.self}/modules/nixos/minecraft-server/modpacks/build-mod-source.nix" { inherit pkgs; };
{ pkgs, ... }:
{ name
, src
, patches ? [ ]
, buildCmd ? null
, outputHash
}:
let
  jdk = pkgs.jdk21;
  # Use the mod's own Gradle wrapper (./gradlew): the pinned wrapper version is
  # the one the mod was built/tested against (e.g. RoadWeaver pins 8.8, but
  # nixpkgs' gradle is 8.14.x which its Loom plugin rejects). The wrapper
  # downloads its distribution on first run — network is allowed inside this
  # fixed-output derivation.
  defaultBuildCmd = ''
    chmod +x ./gradlew
    ./gradlew --no-daemon --stacktrace :neoforge:build
    jar=$(ls neoforge/build/libs/*.jar 2>/dev/null | grep -v -E 'sources|dev-shadow|dev\.jar' | head -1)
    if [ -z "$jar" ]; then
      echo "build-mod-source: ${name}: no playable jar found under neoforge/build/libs/" >&2
      exit 1
    fi
    cp "$jar" "$out"
  '';
  buildCmd' = if buildCmd == null then defaultBuildCmd else buildCmd;
in
pkgs.stdenv.mkDerivation {
  inherit name src patches;

  outputHashMode = "flat";
  inherit outputHash;

  nativeBuildInputs = [ jdk ];

  # Gradle needs a writable HOME; the Nix build dir is on tmpfs.
  buildPhase = ''
    export HOME=$TMPDIR
    export JAVA_HOME=${jdk}
    export PATH=${jdk}/bin:$PATH
    ${buildCmd'}
  '';

  installPhase = ''
    if [ ! -f "$out" ]; then
      echo "build-mod-source: ${name} produced no jar at \$out" >&2
      exit 1
    fi
  '';
}
