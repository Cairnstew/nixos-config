{ config, lib, pkgs, ... }:

let
  cfg = config.my.programs.spotify;
  isTui = cfg.tui.enable;
  resolvedPackage = if isTui then cfg.tui.package else cfg.package;
  yamlFormat = pkgs.formats.yaml { };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ resolvedPackage ];

    home.file.".config/spotatui/config.yml" = lib.mkIf (isTui && cfg.tui.settings != { }) {
      source = yamlFormat.generate "spotatui-config" cfg.tui.settings;
    };
  };
}
