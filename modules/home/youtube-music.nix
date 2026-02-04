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
      # Try youtube-music first, fallback to pear-desktop, else error
      default = pkgs.youtube-music or pkgs.pear-desktop or (throw ''
        Neither pkgs.pear-desktop nor pkgs.youtube-music found.
        Run: nix search nixpkgs pear-desktop
        Then update your flake with: nix flake update nixpkgs
      '');
      description = "Package to install (pear-desktop or youtube-music)";
    };
  };
  
  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };
}