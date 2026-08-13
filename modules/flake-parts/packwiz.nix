# =============================================================================
# packwiz.nix — Minecraft modpack tooling at the flake level
# =============================================================================
# Purpose: Expose the packwiz CLI and per-modpack checksum generators for the
#          packwiz2nix workflow. Modpacks live in
#          modules/nixos/minecraft-server/modpacks/<name>/ and are authored with
#          the packwiz CLI; packwiz2nix converts them into Nix fixed-output
#          derivations consumed by my.services.minecraftServer.
#
# Outputs (perSystem):
#   - packages.packwiz                    → the packwiz CLI
#   - apps."packwiz-checksums-<modpack>"  → writes <modpack>/checksums.json
#
# Usage:
#   cd modules/nixos/minecraft-server/modpacks/testModpack
#   nix run .#packwiz -- init            # create the pack
#   nix run .#packwiz -- modrinth add <mod> ...
#   nix run .#packwiz-checksums-testModpack  # regenerate checksums.json
#
# The checksum app downloads and hashes every mod at RUNTIME (when `nix run`
# runs it) rather than at eval or build time: packwiz2nix's mkChecksums uses
# builtins.fetchurl without a pinned hash (pure evaluation forbids it) and the
# Nix build sandbox has no network. This keeps `nix flake check` green while
# still producing a committed, reproducible checksums.json.
# =============================================================================

{ inputs, lib, ... }:
let
  inherit (inputs) packwiz2nix;
  p2n = packwiz2nix.lib;

  # Directory holding packwiz modpacks (one subdir per modpack). Read at eval
  # time so a new modpack directory automatically gets a checksums app.
  modpacksDir = "${inputs.self}/modules/nixos/minecraft-server/modpacks";
  modpackNames =
    if builtins.pathExists modpacksDir then
      lib.attrNames (builtins.readDir modpacksDir)
    else
      [ ];

  checksumsScript = ./packwiz-checksums.py;

  # App that writes <modpack>/checksums.json into the CURRENT WORKING DIRECTORY
  # (run from the modpack dir, matching upstream packwiz2nix behavior).
  # The download+hash happens at RUNTIME (when the app is run), not during
  # eval or build: packwiz2nix's mkChecksums uses builtins.fetchurl (pure-eval
  # forbidden) and build-time fetching would hit the Nix build sandbox (no
  # network). A runtime script keeps `nix flake check` green and lets the user
  # regenerate checksums freely.
  mkChecksumsApp = pkgs: name:
    let
      modsDir = "${modpacksDir}/${name}/mods";
      script = pkgs.writeShellScriptBin "packwiz-checksums-${name}" ''
        ${pkgs.python3}/bin/python3 ${checksumsScript} ${modsDir} > checksums.json
        echo "wrote checksums.json — commit it and rebuild the server"
      '';
    in
    {
      type = "app";
      program = script.outPath + "/bin/packwiz-checksums-${name}";
    };
in
{
  perSystem = { pkgs, ... }: {
    packages = {
      # packwiz CLI — run from a modpack dir: `nix run .#packwiz -- <cmd>`
      # Built from our nixpkgs (`pkgs.packwiz`), NOT from inputs.packwiz: the
      # upstream flake's `nix/vendor-hash` is empty, so its package fails to
      # build ("found empty hash, assuming sha256-AAA…"). nixpkgs' packwiz is
      # the same commit and maintained. The flake input is kept for upstream
      # parity / future fixes.
      inherit (pkgs) packwiz;
    };

    apps = lib.listToAttrs (map
      (name: lib.nameValuePair "packwiz-checksums-${name}" (mkChecksumsApp pkgs name))
      modpackNames);
  };
}
