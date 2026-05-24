{ lib, pkgs, ... }:

let
  types = lib.types;
in
{
  options.my.programs.obsidian = {
    enable = lib.mkEnableOption "Obsidian with custom configuration";

    package = lib.mkOption {
      type = types.package;
      default = pkgs.obsidian;
      defaultText = lib.literalExpression "pkgs.obsidian";
      description = "The Obsidian package to use.";
    };

    defaultDirectory = lib.mkOption {
      type = types.str;
      default = "Documents/Obsidian_Vault";
      description = "Default vault directory relative to HOME";
    };

    repo = {
      enable = lib.mkOption {
        type = types.bool;
        default = false;
        description = "Clone the Obsidian vault from a git repo on first setup";
      };

      url = lib.mkOption {
        type = types.str;
        default = "";
        description = "GitHub repo URL (e.g. https://github.com/user/vault)";
      };

      tokenFile = lib.mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to agenix-managed file containing a GitHub access token";
      };
    };
  };
}
