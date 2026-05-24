{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.youtube-music;
in
{
  options.my.programs.youtube-music = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable youtube-music (YouTube Music client)";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pear-desktop or (throw ''
        pkgs.pear-desktop not found.
        Run: nix search nixpkgs pear-desktop
        Then update your flake with: nix flake update nixpkgs
      '');
      description = "Package to install (pear-desktop, formerly youtube-music)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}
