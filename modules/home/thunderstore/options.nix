# options.nix — my.programs.thunderstore
{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types literalExpression;

  gameDirType = types.either types.str (types.nullOr types.str);
in
{
  options.my.programs.thunderstore = {
    enable = mkEnableOption ''
      ThunderStore mod manager: hash-pinned packs of ThunderStore mods, installed
      into the Steam game directory that is discovered from your Steam config
      (libraryfolders.vdf + appmanifest_<appid>.acf).
    '';

    packs = mkOption {
      type = types.attrsOf (
        types.submodule (
          { ... }: {
            options = {
              enable = mkEnableOption "install this pack on home-manager switch";

              appId = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "1966720";
                description = ''
                  Override the Steam appid used for discovery. Leave null (the
                  default) to use the appid the ThunderStore ecosystem declares for
                  the game — that is the authoritative one. Set it only when you
                  want to install into a different (e.g. non-Steam) copy, e.g. to
                  mirror `my.programs.steam.games.<name>.appId`.
                '';
              };

              gameDir = mkOption {
                type = gameDirType;
                default = null;
                example = "/mnt/games/steamapps/common/Lethal Company";
                description = ''
                  Override the Steam game directory. Leave null (the default) to
                  discover it from Steam's own configuration at install time:
                  every library in {env,`"$XDG_DATA_HOME/Steam"`,`~/.steam/steam`,
                  `~/.steam/root`,`~/.local/share/Steam`,`~/Steam`} plus every
                  `path` entry in each library's `steamapps/libraryfolders.vdf`,
                  resolving the appid through `appmanifest_<appid>.acf`.
                '';
              };

              installOnActivate = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Install on `home-manager switch`. When false the pack is only
                  installed by `nix run .#thunderstore-install-<name>`.
                '';
              };

              dryRun = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Only report what an activation would write and prune; never
                  touch the game directory.
                '';
              };

              extraFlags = mkOption {
                type = types.listOf types.str;
                default = [ ];
                example = [ "--require-exe" ];
                description = ''
                  Extra flags passed to lib/install.sh
                  (--force, --prune-only, --require-exe, --steam-root, --no-state).
                '';
              };
            };
          }
        )
      );
      default = { };
      example = literalExpression ''
        {
          lethal-company = {
            enable = true;
            extraFlags = [ "--require-exe" ];
          };
        }
      '';
      description = ''
        Packs declared in `modules/home/thunderstore/packs/<name>/`, keyed by
        pack directory name. A pack directory is inert until it is enabled here.
      '';
    };

    pruneOnActivate = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Remove files a previous install wrote that the current pack no longer
        contains. Files you have edited are reported, never deleted silently.
      '';
    };

    stateFileName = mkOption {
      type = types.str;
      default = ".thunderstore-state.json";
      defaultText = ".thunderstore-state.json";
      description = ''
        Name of the ownership record written into the game directory. It is what
        makes pruning safe; delete it to stop tracking (pass --no-state to
        ignore it).
      '';
    };
  };
}
