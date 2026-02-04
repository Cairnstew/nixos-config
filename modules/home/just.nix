{ config, pkgs, lib, ... }:
let
  cfg = config.my.programs.just;
in
{
  options.my.programs.just = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable just command runner";
    };

    enableShortAlias = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 'j' alias for 'just'";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.just;
      description = "The just package to install";
    };

    additionalAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional shell aliases related to just";
      example = lib.literalExpression ''
        {
          jl = "just --list";
          jr = "just --choose";
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
    home.shellAliases = 
      (lib.optionalAttrs cfg.enableShortAlias { j = "just"; })
      // cfg.additionalAliases;
  };
}