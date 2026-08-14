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
#   - packages."minecraft-modpack-<name>" → built client instance content for a modpack
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
  inherit (lib) concatStringsSep;
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

  # Build a modpack's client content for a Prism Launcher instance.
  #
  # Output layout (installed into <dataDir>/instances/<name>/ by the home
  # module's minecraft-instance-<name> service):
  #   .minecraft/mods/           every mod jar (fixed-output, from checksums.json)
  #   .minecraft/config/         pack internal content (default player configs)
  #   .minecraft/<kubejs/scripts/datapacks/defaultconfigs>/
  #   meta.json                  { name, minecraft, loaderUid, loaderVersion }
  #                              (from pack.toml; drives instance.cfg/mmc-pack.json)
  #
  # Same checksums.json the server uses — one pack, both sides.
  mkClientInstance = pkgs: name:
    let
      pack = "${modpacksDir}/${name}";
      checksums = "${pack}/checksums.json";
      packToml = builtins.fromTOML (builtins.readFile "${pack}/pack.toml");
      mc = packToml.versions.minecraft;

      # Loader uid:version → Prism component uid. Only one is set per pack.
      loaderUid =
        if packToml.versions ? neoforge then "net.neoforged"
        else if packToml.versions ? fabric then "net.fabricmc.fabric-loader"
        else if packToml.versions ? forge then "net.minecraftforge"
        else if packToml.versions ? quilt then "org.quiltmc.quilt-loader"
        else lib.throw "minecraft-modpack-${name}: no supported loader in pack.toml";
      loaderVersion =
        packToml.versions.neoforge or packToml.versions.fabric or packToml.versions.forge
        or packToml.versions.quilt;

      modLinks =
        if builtins.pathExists checksums then
          p2n.mkModLinks (p2n.mkPackwizPackages pkgs checksums)
        else
          lib.warn "minecraft-modpack-${name}: no checksums.json — client will have no mods. Run .#packwiz-checksums-${name}." { };

      # .minecraft/<dir> symlinks (mirrors packwizStartPre on the server side).
      internalDirs = [ "config" "kubejs" "scripts" "datapacks" "defaultconfigs" ];
      internalLinks = concatStringsSep "\n" (builtins.map
        (d: ''
          if [ -d '${pack}/${d}' ]; then
            ln -s '${pack}/${d}' "$out/.minecraft/${d}"
          fi
        '')
        internalDirs);

      # mods/<fixup>.jar → store path, one symlink per mod.
      modLinksScript = concatStringsSep "\n" (lib.mapAttrsToList
        (target: src: ''
          mkdir -p "$(dirname "$out/.minecraft/${target}")"
          ln -s '${src}' "$out/.minecraft/${target}"
        '')
        modLinks);

      meta = pkgs.writeText "meta.json" (builtins.toJSON {
        inherit name mc loaderUid loaderVersion;
        packName = packToml.name or name;
      });
    in
    pkgs.runCommand "minecraft-modpack-${name}-client" { } ''
      mkdir -p $out/.minecraft
      ${modLinksScript}
      ${internalLinks}
      cp ${meta} $out/meta.json
    '';
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
    } // lib.listToAttrs (map
      (name: lib.nameValuePair "minecraft-modpack-${name}" (mkClientInstance pkgs name))
      modpackNames);

    apps = lib.listToAttrs (map
      (name: lib.nameValuePair "packwiz-checksums-${name}" (mkChecksumsApp pkgs name))
      modpackNames);
  };
}
