{ config, lib, pkgs, ... }:

let
  cfg = config.homeManagerModules.uv2nix-template;
in

{

  options.homeManagerModules.uv2nix-template = {
    enable = lib.mkEnableOption "uv2nix-template user packages";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.uv2nix-template;
      defaultText = lib.literalExpression "pkgs.uv2nix-template";
      description = "Package to add to the user session";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];
  };

}
