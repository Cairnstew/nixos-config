# modules/home/superfile/config.nix
{ config, lib, pkgs, ... }:
let
  cfg = config.my.programs.superfile;
  toml = pkgs.formats.toml { };
  settings = import ./merge.nix { inherit lib cfg; };
in
{
  config = lib.mkIf cfg.enable {
    # Both files are read-only store symlinks. That is safe: superfile's
    # `writeConfigFile` (src/cmd/main.go) only writes when the target is absent,
    # so it never tries to rewrite ours. `superfile --fix-config-file` WOULD
    # write, and fails against a store symlink — extend `settings` instead.
    xdg.configFile =
      {
        "superfile/config.toml".source = toml.generate "superfile-config.toml" settings;
      }
      // lib.mapAttrs'
        (
          name: value:
            lib.nameValuePair "superfile/theme/${name}.toml" {
              source = toml.generate "superfile-theme-${name}.toml" value;
            }
        )
        cfg.themes;
  };
}
