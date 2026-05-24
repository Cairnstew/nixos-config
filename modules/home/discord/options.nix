{ lib, pkgs, ... }:

let
  types = lib.types;
in
{
  options.my.programs.discord = {
    enable = lib.mkEnableOption "Discord desktop client";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.discord;
      defaultText = lib.literalExpression "pkgs.discord";
      description = "The Discord package to use.";
    };

    autostart = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Automatically start Discord on login.";
    };

    extraPackages = lib.mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages or plugins to include with Discord.";
    };

    theme = lib.mkOption {
      type = types.str;
      default = "dark";
      description = "Discord theme (if you have a theme loader installed).";
    };
  };
}
