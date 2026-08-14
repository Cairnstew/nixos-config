# Shared helper: build-time patch of a single member inside a mod jar.
#
# Modpacks occasionally ship a jar whose embedded metadata is wrong (e.g. a
# dependency `versionRange` that pins a version that does not exist for the
# pack's MC version). Instead of removing the mod, we patch the jar's
# META-INF/neoforge.mods.toml at Nix build time and ship the patched jar to
# BOTH the Prism client instance (modules/flake-parts/packwiz.nix) and the
# NixOS server (modules/nixos/minecraft-server/config.nix).
#
# This is deliberately a jar *member* replacement, not a full unzip/rezip:
# zip replaces the named member in place and copies every other member's
# bytes verbatim, so only the patched member is rewritten. The member's mtime
# is pinned to the epoch so rebuilds are byte-identical.
#
# Usage: patchJar { name, src, patchScript }
#   name         — output jar name (e.g. "dtstill-life-1.0.3-patched")
#   src          — the pinned upstream jar (a packwiz2nix fetchurl store path)
#   patchScript  — a Python script that edits the member file given as argv[1];
#                  must fail loudly if the expected content is missing so an
#                  upstream metadata change is caught, not silently skipped.
#
# The member is always META-INF/neoforge.mods.toml (NeoForge 1.21.x). To patch
# a different member, extend the `member` argument (default: the above).
{ lib, unzip, zip, coreutils, python3 }:
{ name, src, patchScript, member ? "META-INF/neoforge.mods.toml" }:
lib.runCommand name {
  nativeBuildInputs = [ unzip zip coreutils python3 ];
} ''
  set -euo pipefail
  export TZ=UTC
  cp '${src}' work.jar
  mkdir -p "$(dirname '${member}')"
  ${unzip}/bin/unzip -p work.jar '${member}' > '${member}'
  ${python3}/bin/python3 '${patchScript}' '${member}'
  touch -d @0 '${member}'
  ${zip}/bin/zip -X -q work.jar '${member}'
  cp work.jar "$out"
''
