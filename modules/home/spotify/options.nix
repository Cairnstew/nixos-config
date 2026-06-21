{ lib, pkgs, ... }:

let
  inherit (lib) types;
in
{
  options.my.programs.spotify = {
    enable = lib.mkEnableOption "Spotify desktop client";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.spotify;
      defaultText = lib.literalExpression "pkgs.spotify";
      description = "The Spotify package to use.";
    };

    tui = {
      enable = lib.mkEnableOption "spotatui TUI client";

      package = lib.mkOption {
        type = types.package;
        default = pkgs.spotatui;
        defaultText = lib.literalExpression "pkgs.spotatui";
        description = "The Spotify TUI package to use (default: spotatui, a community fork of spotify-tui).";
      };

      settings = lib.mkOption {
        type = types.attrs;
        default = { };
        example = {
          behavior = {
            enable_discord_rpc = false;
          };
        };
        description = ''
          Settings to write to ~/.config/spotatui/config.yml.
          See https://github.com/LargeModGames/spotatui/wiki/Configuration
          for the full config reference.
        '';
      };
    };
  };
}
