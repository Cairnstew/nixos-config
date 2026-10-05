# config.nix — home-manager wiring for my.programs.thunderstore
#
# Each enabled pack is installed on `home-manager switch` by an activation hook
# that calls the pack's own installer (shipped inside the pack derivation). The
# installer discovers the Steam game directory at RUN time from Steam's own
# configuration — every library in the standard roots plus every `path` entry in
# `steamapps/libraryfolders.vdf`, with the appid resolved through
# `appmanifest_<appid>.acf` — so nothing in this file needs to know where your
# games live. `packs.<name>.gameDir` overrides that when you want to pin it.
#
# A pack whose game is not installed is reported and skipped: it never fails a
# switch, because "I haven't bought the game yet" is not a config error.
{ config, lib, pkgs, flake, ... }:

let
  inherit (flake.inputs) self;
  inherit (lib) optionals;
  cfg = config.my.programs.thunderstore;

  packsDir = "${self}/modules/home/thunderstore/packs";
  packNames =
    if builtins.pathExists packsDir then
      lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir packsDir))
    else
      [ ];

  enabledNames = lib.filter (name: (cfg.packs.${name}.enable or false)) packNames;

  # Unknown pack names are a typo, not a no-op — fail with the list of real ones.
  unknownNames = lib.filter (name: !(lib.hasAttr name cfg.packs)) (
    lib.attrNames cfg.packs
  );

  buildPack = name:
    import ./lib/pack.nix {
      inherit pkgs lib;
      packDir = "${packsDir}/${name}";
      inherit name;
    };

  enabled = map (name: { inherit name; opts = cfg.packs.${name}; pack = buildPack name; }) enabledNames;

  flagsFor = opts:
    lib.unique (
      (if opts.dryRun then [ "--dry-run" ] else [ ])
      ++ (if cfg.pruneOnActivate then [ ] else [ "--no-prune" ])
      ++ [ "--state-file" cfg.stateFileName ]
      ++ optionals (opts.appId != null) [ "--appid" opts.appId ]
      ++ opts.extraFlags
    );

  # Pack metadata for `home.activation` messages, without forcing a build.
  describe = pack: "${pack.name} (${pack.pack.routing.game}, ${pack.pack.routing.loader})";
in
{
  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = unknownNames == [ ];
        message = ''
          my.programs.thunderstore.packs declares unknown pack(s):
          ${lib.concatStringsSep ", " unknownNames}
          Known packs: ${lib.concatStringsSep ", " packNames}
        '';
      }
    ];

    # `thunderstore-install-<name>` for every enabled pack, so a pack can be
    # reinstalled without a rebuild.
    home.packages = map (pack: pack.pack.installScript) enabled;

    home.activation.thunderstoreMods =
      lib.mkIf (enabled != [ ]) (
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # ── ThunderStore packs ────────────────────────────────────────────
          # Mods are written straight into the Steam game directory (BepInEx and
          # friends need to sit next to the game binary). Every file we write is
          # recorded in the game dir, so a later switch prunes exactly what it
          # owns and nothing else.
          ${lib.concatStringsSep "\n" (
            map
              (pack: ''
                echo "thunderstore: ${describe pack}"
                # NOTE: $? inside the else branch is the installer's own status;
                # `if ! cmd` would report the negation's status instead.
                if ${pack.pack.installScript} ${lib.concatMapStringsSep " " (s: "''${s}") (flagsFor pack.opts)}; then
                  :
                else
                  status=$?
                  if [ "$status" -eq 5 ] || [ "$status" -eq 6 ]; then
                    echo "thunderstore: ${pack.name}: game directory not found - skipping (install the game via Steam, or set my.programs.thunderstore.packs.${pack.name}.gameDir)"
                  else
                    echo "thunderstore: ${pack.name}: installer failed with status $status" >&2
                  fi
                fi
              '')
              enabled
          )}
        ''
      );
  };
}
