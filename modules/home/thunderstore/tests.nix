# tests.nix — L0 assertions for my.programs.thunderstore
#
# The routing engine itself is covered by a real end-to-end derivation
# (`nix build .#thunderstore-router-test`, defined in lib/router-test.nix): it
# builds fixtures, routes them, and asserts the destination layout. Keeping it
# out of `assertions` means a routing regression never blocks a switch, while
# `nix flake check`-style builds still catch it.
{ config, lib, ... }:

let
  cfg = config.my.programs.thunderstore;
  inherit (lib) mkIf;

  loaders = import ./lib/loaders.nix { inherit lib; };
in
{
  config = mkIf cfg.enable {
    assertions = [
      # A pinned gameDir must be absolute: the installer copies relative to it,
      # so a relative path would resolve against whatever cwd the switch ran in.
      {
        assertion = lib.all (name: let d = cfg.packs.${name}.gameDir; in d == null || lib.hasPrefix "/" d) (
          lib.attrNames cfg.packs
        );
        message = ''
          my.programs.thunderstore.packs.<name>.gameDir must be an absolute path
          (leave it null to auto-discover the Steam game directory).
        '';
      }

      # The state file is written into the game directory; a path separator would
      # make the installer write somewhere else entirely.
      {
        assertion = cfg.stateFileName != "" && !lib.hasPrefix "/" cfg.stateFileName;
        message = ''
          my.programs.thunderstore.stateFileName must be a bare file name
          (e.g. ".thunderstore-state.json"), not a path. Got: ${cfg.stateFileName}
        '';
      }

      # dryRun + --prune-only is a contradiction that would silently do nothing.
      {
        assertion = lib.all
          (
            name: !(cfg.packs.${name}.dryRun && lib.hasElem "--prune-only" cfg.packs.${name}.extraFlags)
          )
          (lib.attrNames cfg.packs);
        message = "my.programs.thunderstore.packs.<name>: dryRun cannot be combined with --prune-only";
      }

      # Every loader in the ecosystem's enum must be modelled, or a pack for that
      # game would silently install nothing. The list is the ecosystem schema's
      # ModmanPackageLoaderValues (thunderstore-io/ecosystem-schema games/src/models.ts).
      {
        assertion = lib.all (loader: lib.hasAttr loader loaders.byLoader) [
          "bepinex"
          "melonloader"
          "northstar"
          "godotml"
          "shimloader"
          "lovely"
          "return-of-modding"
          "gdweave"
          "recursive-melonloader"
          "bepisloader"
          "umm"
          "rivet"
          "none"
        ];
        message = ''
          modules/home/thunderstore/lib/loaders.nix is missing a loader from the
          Thunderstore ecosystem enum. Add it before using a game that needs it.
        '';
      }

      # Both loader families must stay consistent with the ecosystem's own split.
      {
        assertion = lib.all (loader: loaders.byLoader.${loader}.family == "installRules") loaders.installRuleDriven;
        message = "lib/loaders.nix: installRuleDriven loaders must declare family = \"installRules\"";
      }
    ];
  };
}
